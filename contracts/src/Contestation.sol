// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IPCT is IERC20 {
    function burn(uint256 amount) external;
}

interface ISBT {
    function ownerOf(uint256 tokenId) external view returns (address);
    function tokenOf(address who) external view returns (uint256);
    function isActive(uint256 tokenId) external view returns (bool);
    function isActiveHolder(address who) external view returns (bool);
    function levelOf(uint256 tokenId) external view returns (uint8);
    function wasEvaluator(uint256 tokenId, address who) external view returns (bool);
    function contest(uint256 tokenId) external;
    function resolveContest(uint256 tokenId, uint8 outcome) external; // 0 rejet, 1 rétrogradé, 2 révoqué
}

/// @title Contestation des Passeports : staking, jury VRF, commit-reveal, slashing
/// @notice Aucun rôle humain. Le propriétaire VRF (Timelock) ne peut que changer de coordinateur.
contract Contestation is VRFConsumerBaseV2Plus, ReentrancyGuard {
    using SafeERC20 for IPCT;

    // ---------- Paramètres ----------
    uint256 public constant CHALLENGE_STAKE = 500e18;
    uint256 public constant JUDGE_STAKE = 200e18;
    uint256 public constant JURY_SIZE = 5;
    uint256 public constant QUORUM = 3;
    uint64 public constant COMMIT_PERIOD = 48 hours;
    uint64 public constant REVEAL_PERIOD = 24 hours;
    uint64 public constant CHALLENGER_COOLDOWN = 7 days;
    uint64 public constant PASSPORT_SHIELD = 30 days;
    uint64 public constant DRAW_TIMEOUT = 24 hours;
    uint256 public constant BURN_BPS = 1_000; // 10 %
    uint256 internal constant MAX_DRAW_ATTEMPTS = 40;
    uint32 internal constant CALLBACK_GAS = 2_000_000;

    uint8 internal constant V_REJECT = 1;
    uint8 internal constant V_DOWNGRADE = 2;
    uint8 internal constant V_REVOKE = 3;

    enum Phase { None, Drawing, Voting, Resolved, Cancelled }

    struct Contest {
        address challenger;
        uint256 tokenId;
        string evidenceCid;
        uint64 openedAt;
        uint64 commitEnd;
        uint64 revealEnd;
        Phase phase;
        address[] jurors;
    }

    IPCT public immutable token;
    ISBT public immutable sbt;
    address public immutable treasury; // Safe DAO : reçoit les reliquats
    uint256 public immutable subId;
    bytes32 public immutable keyHash;

    uint256 public contestCount;
    mapping(uint256 => Contest) private _contests;
    mapping(uint256 => uint256) private _requestToContest;
    mapping(uint256 => mapping(address => bool)) public isJuror;
    mapping(uint256 => mapping(address => bytes32)) public commitOf;
    mapping(uint256 => mapping(address => uint8)) public voteOf;
    mapping(uint256 => uint256) public activeContestOf; // tokenId => contestId
    mapping(uint256 => uint64) public shieldUntil;       // tokenId => date
    mapping(address => uint64) public nextContestAt;

    // Pool de juges
    mapping(address => uint256) public freeBalance; // retirable
    mapping(address => bool) public inPool;
    mapping(address => bool) private _ticketed;
    address[] private _tickets; // une entrée par niveau de Passeport

    error NotEligible();
    error WrongPhase();
    error TooEarly();
    error TooLate();
    error BadVote();
    error BadReveal();
    error Insufficient();

    event PoolJoined(address indexed judge, uint256 tickets);
    event PoolLeft(address indexed judge);
    event ContestOpened(uint256 indexed id, uint256 indexed tokenId, address indexed challenger, string evidenceCid);
    event JuryDrawn(uint256 indexed id, address[] jurors, uint64 commitEnd, uint64 revealEnd);
    event VoteCommitted(uint256 indexed id, address indexed juror);
    event VoteRevealed(uint256 indexed id, address indexed juror, uint8 vote);
    event ContestResolved(uint256 indexed id, uint8 outcome, bool quorumReached, uint256 burned);
    event ContestCancelled(uint256 indexed id);

    constructor(address coordinator, uint256 subId_, bytes32 keyHash_, IPCT token_, ISBT sbt_, address treasury_)
        VRFConsumerBaseV2Plus(coordinator)
    {
        subId = subId_;
        keyHash = keyHash_;
        token = token_;
        sbt = sbt_;
        treasury = treasury_;
    }

    // ---------- Pool de juges ----------

    /// @notice Dépose une caution et entre dans le tirage. Réservé aux Passeports actifs.
    function joinPool(uint256 amount) external nonReentrant {
        if (!sbt.isActiveHolder(msg.sender)) revert NotEligible();
        if (amount > 0) {
            token.safeTransferFrom(msg.sender, address(this), amount);
            freeBalance[msg.sender] += amount;
        }
        if (freeBalance[msg.sender] < JUDGE_STAKE) revert Insufficient();
        inPool[msg.sender] = true;
        if (!_ticketed[msg.sender]) {
            _ticketed[msg.sender] = true;
            uint256 n = sbt.levelOf(sbt.tokenOf(msg.sender));
            for (uint256 i; i < n; ++i) _tickets.push(msg.sender);
            emit PoolJoined(msg.sender, n);
        }
    }

    function leavePool() external {
        inPool[msg.sender] = false;
        emit PoolLeft(msg.sender);
    }

    /// @notice Retire le solde non bloqué (cautions rendues, récompenses, stakes remboursés).
    function withdraw(uint256 amount) external nonReentrant {
        if (freeBalance[msg.sender] < amount) revert Insufficient();
        freeBalance[msg.sender] -= amount;
        token.safeTransfer(msg.sender, amount);
    }

    // ---------- Ouverture ----------

    function openContest(uint256 tokenId, string calldata evidenceCid) external nonReentrant returns (uint256 id) {
        if (!sbt.isActive(tokenId)) revert NotEligible();
        if (sbt.ownerOf(tokenId) == msg.sender) revert NotEligible();
        if (block.timestamp < nextContestAt[msg.sender]) revert TooEarly();
        if (block.timestamp < shieldUntil[tokenId]) revert TooEarly();

        token.safeTransferFrom(msg.sender, address(this), CHALLENGE_STAKE);
        nextContestAt[msg.sender] = uint64(block.timestamp) + CHALLENGER_COOLDOWN;

        id = ++contestCount;
        Contest storage c = _contests[id];
        c.challenger = msg.sender;
        c.tokenId = tokenId;
        c.evidenceCid = evidenceCid;
        c.openedAt = uint64(block.timestamp);
        c.phase = Phase.Drawing;
        activeContestOf[tokenId] = id;
        sbt.contest(tokenId); // revert si déjà contesté

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: subId,
                requestConfirmations: 3,
                callbackGasLimit: CALLBACK_GAS,
                numWords: 1,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
        _requestToContest[requestId] = id;
        emit ContestOpened(id, tokenId, msg.sender, evidenceCid);
    }

    /// @dev Rappel VRF : ne doit jamais revert.
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        uint256 id = _requestToContest[requestId];
        Contest storage c = _contests[id];
        if (c.phase != Phase.Drawing) return;

        address creator = sbt.ownerOf(c.tokenId);
        uint256 n = _tickets.length;
        for (uint256 i; i < MAX_DRAW_ATTEMPTS && c.jurors.length < JURY_SIZE && n > 0; ++i) {
            address cand = _tickets[uint256(keccak256(abi.encode(randomWords[0], i))) % n];
            if (
                !inPool[cand] || cand == c.challenger || cand == creator || isJuror[id][cand]
                    || freeBalance[cand] < JUDGE_STAKE || !sbt.isActiveHolder(cand)
                    || sbt.wasEvaluator(c.tokenId, cand)
            ) continue;
            isJuror[id][cand] = true;
            freeBalance[cand] -= JUDGE_STAKE; // caution bloquée
            c.jurors.push(cand);
        }
        if (c.jurors.length < JURY_SIZE) {
            _cancel(id, c);
            return;
        }
        c.commitEnd = uint64(block.timestamp) + COMMIT_PERIOD;
        c.revealEnd = c.commitEnd + REVEAL_PERIOD;
        c.phase = Phase.Voting;
        emit JuryDrawn(id, c.jurors, c.commitEnd, c.revealEnd);
    }

    /// @notice Débloque une contestation si le VRF n'a pas répondu en 24 h.
    function cancelStuck(uint256 id) external nonReentrant {
        Contest storage c = _contests[id];
        if (c.phase != Phase.Drawing) revert WrongPhase();
        if (block.timestamp < c.openedAt + DRAW_TIMEOUT) revert TooEarly();
        _cancel(id, c);
    }

    function _cancel(uint256 id, Contest storage c) private {
        for (uint256 i; i < c.jurors.length; ++i) freeBalance[c.jurors[i]] += JUDGE_STAKE;
        freeBalance[c.challenger] += CHALLENGE_STAKE;
        nextContestAt[c.challenger] = 0;
        c.phase = Phase.Cancelled;
        activeContestOf[c.tokenId] = 0;
        sbt.resolveContest(c.tokenId, 0);
        emit ContestCancelled(id);
    }

    // ---------- Vote ----------

    /// @param commitment keccak256(abi.encode(id, juge, vote, sel))
    function commitVote(uint256 id, bytes32 commitment) external {
        Contest storage c = _contests[id];
        if (c.phase != Phase.Voting || !isJuror[id][msg.sender]) revert WrongPhase();
        if (block.timestamp >= c.commitEnd) revert TooLate();
        if (commitOf[id][msg.sender] != bytes32(0)) revert BadVote();
        commitOf[id][msg.sender] = commitment;
        emit VoteCommitted(id, msg.sender);
    }

    function revealVote(uint256 id, uint8 vote, bytes32 salt) external {
        Contest storage c = _contests[id];
        if (c.phase != Phase.Voting) revert WrongPhase();
        if (block.timestamp < c.commitEnd) revert TooEarly();
        if (block.timestamp >= c.revealEnd) revert TooLate();
        if (vote < V_REJECT || vote > V_REVOKE || voteOf[id][msg.sender] != 0) revert BadVote();
        if (keccak256(abi.encode(id, msg.sender, vote, salt)) != commitOf[id][msg.sender]) revert BadReveal();
        voteOf[id][msg.sender] = vote;
        emit VoteRevealed(id, msg.sender, vote);
    }

    // ---------- Résolution ----------

    /// @notice Appelable par n'importe qui après la fin du reveal.
    function resolve(uint256 id) external nonReentrant {
        Contest storage c = _contests[id];
        if (c.phase != Phase.Voting) revert WrongPhase();
        if (block.timestamp < c.revealEnd) revert TooEarly();
        c.phase = Phase.Resolved;
        activeContestOf[c.tokenId] = 0;

        uint256 len = c.jurors.length;
        uint256 nReject;
        uint256 nDown;
        uint256 nRevoke;
        for (uint256 i; i < len; ++i) {
            uint8 v = voteOf[id][c.jurors[i]];
            if (v == V_REJECT) ++nReject;
            else if (v == V_DOWNGRADE) ++nDown;
            else if (v == V_REVOKE) ++nRevoke;
        }
        uint256 revealed = nReject + nDown + nRevoke;
        bool quorum = revealed >= QUORUM;
        bool upheld = quorum && (nDown + nRevoke) > nReject;

        // 1. Cautions : rendues aux gagnants, versées au pot pour les autres
        uint256 pot;
        uint256 winners;
        bool[] memory win = new bool[](len);
        for (uint256 i; i < len; ++i) {
            uint8 v = voteOf[id][c.jurors[i]];
            // sans quorum : tout juge ayant révélé est "gagnant"
            win[i] = v != 0 && (!quorum || ((v != V_REJECT) == upheld));
            if (win[i]) {
                freeBalance[c.jurors[i]] += JUDGE_STAKE;
                ++winners;
            } else {
                pot += JUDGE_STAKE;
            }
        }

        // 2. Stake du contestataire
        uint8 outcome; // 0 rejet
        if (upheld) {
            outcome = nRevoke > nDown ? 2 : 1;
            freeBalance[c.challenger] += CHALLENGE_STAKE;
        } else if (quorum) {
            pot += CHALLENGE_STAKE;
            shieldUntil[c.tokenId] = uint64(block.timestamp) + PASSPORT_SHIELD;
        } else {
            freeBalance[c.challenger] += CHALLENGE_STAKE; // pas de décision : remboursé
        }

        // 3. Pot : 10 % brûlés, 90 % redistribués
        uint256 burned = (pot * BURN_BPS) / 10_000;
        if (burned > 0) token.burn(burned);
        uint256 rest = pot - burned;
        if (upheld) {
            uint256 half = rest / 2;
            freeBalance[c.challenger] += half;
            rest -= half;
        }
        if (winners > 0) {
            uint256 share = rest / winners;
            for (uint256 i; i < len; ++i) if (win[i]) freeBalance[c.jurors[i]] += share;
            rest -= share * winners;
        }
        if (rest > 0) freeBalance[treasury] += rest; // arrondis, ou pot sans gagnant

        sbt.resolveContest(c.tokenId, outcome);
        emit ContestResolved(id, outcome, quorum, burned);
    }

    // ---------- Lecture ----------

    function getContest(uint256 id) external view returns (Contest memory) {
        return _contests[id];
    }

    function ticketCount() external view returns (uint256) {
        return _tickets.length;
    }
}
