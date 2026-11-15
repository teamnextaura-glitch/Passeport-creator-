// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface ICertToken is IERC20 {
    function burn(uint256 amount) external;
}

interface ICertSBT {
    function tokenOf(address who) external view returns (uint256);
    function isActiveHolder(address who) external view returns (bool);
    function levelOf(uint256 tokenId) external view returns (uint8);
    function mint(address to, uint8 level, address[] calldata evaluators, string calldata proofCid)
        external
        returns (uint256);
}

/// @title Certification des créateurs : jury VRF, commit-reveal, mint au niveau médian
/// @notice Aucun rôle humain n'accorde ni ne refuse un Passeport.
/// @dev Non implémenté par rapport à la spécification : récusation d'un juré,
///      plafond hebdomadaire par juré, nouveau tirage automatique en l'absence de quorum.
contract Certification is VRFConsumerBaseV2Plus, ReentrancyGuard {
    using SafeERC20 for ICertToken;

    // ---------- Paramètres ----------
    uint256 public constant JUDGE_STAKE = 200e18;
    uint256 public constant EVALUATION_REWARD = 20e18;
    uint256 public constant WELCOME_GRANT = 1_000e18;
    uint256 public constant JURY_SIZE = 5;
    uint256 public constant QUORUM = 3;
    uint64 public constant COMMIT_PERIOD = 72 hours;
    uint64 public constant REVEAL_PERIOD = 24 hours;
    uint64 public constant REAPPLY_COOLDOWN = 30 days;
    uint64 public constant DRAW_TIMEOUT = 24 hours;
    uint256 public constant BURN_BPS = 1_000; // 10 %
    uint256 internal constant MAX_DRAW_ATTEMPTS = 40;
    uint32 internal constant CALLBACK_GAS = 2_000_000;

    enum Phase { None, Drawing, Voting, Closed }

    struct Application {
        address candidate;
        bytes32 handleHash; // keccak256(plateforme, pseudo) : unicité du compte
        string proofCid;    // empreinte du dossier hors-chaîne
        uint64 openedAt;
        uint64 commitEnd;
        uint64 revealEnd;
        Phase phase;
        uint8 level;        // 0 = rejet ou pas de décision
        address[] jurors;
    }

    ICertToken public immutable token;
    ICertSBT public immutable sbt;
    address public immutable treasury;
    uint256 public immutable subId;
    bytes32 public immutable keyHash;

    uint256 public applicationCount;
    mapping(uint256 => Application) private _applications;
    mapping(uint256 => uint256) private _requestToApplication;
    mapping(uint256 => mapping(address => bool)) public isJuror;
    mapping(uint256 => mapping(address => bytes32)) public commitOf;
    mapping(uint256 => mapping(address => uint8)) public scorePlusOne; // 0 = non révélé
    mapping(address => uint256) public activeApplicationOf;
    mapping(address => uint64) public nextApplyAt;
    mapping(bytes32 => address) public handleOwner;
    mapping(address => mapping(address => bool)) public hasJudged; // candidat => juré

    // Pool d'évaluateurs et budget de récompenses
    mapping(address => uint256) public freeBalance;
    mapping(address => bool) public inPool;
    mapping(address => bool) private _ticketed;
    address[] private _tickets;
    uint256 public rewardBudget; // alimenté par la DAO via fund()

    error NotEligible();
    error WrongPhase();
    error TooEarly();
    error TooLate();
    error BadScore();
    error BadReveal();
    error Insufficient();

    event Funded(address indexed from, uint256 amount);
    event PoolJoined(address indexed juror, uint256 tickets);
    event PoolLeft(address indexed juror);
    event Applied(uint256 indexed id, address indexed candidate, bytes32 handleHash, string proofCid);
    event JuryDrawn(uint256 indexed id, address[] jurors, uint64 commitEnd, uint64 revealEnd);
    event ScoreCommitted(uint256 indexed id, address indexed juror);
    event ScoreRevealed(uint256 indexed id, address indexed juror, uint8 score);
    event Finalized(uint256 indexed id, bool quorumReached, uint8 level, uint256 tokenId);
    event ApplicationCancelled(uint256 indexed id);

    constructor(address coordinator, uint256 subId_, bytes32 keyHash_, ICertToken token_, ICertSBT sbt_, address treasury_)
        VRFConsumerBaseV2Plus(coordinator)
    {
        subId = subId_;
        keyHash = keyHash_;
        token = token_;
        sbt = sbt_;
        treasury = treasury_;
    }

    // ---------- Budget ----------

    /// @notice Alimente les récompenses d'évaluation et les dotations d'accueil.
    function fund(uint256 amount) external nonReentrant {
        token.safeTransferFrom(msg.sender, address(this), amount);
        rewardBudget += amount;
        emit Funded(msg.sender, amount);
    }

    function _payFromBudget(address to, uint256 amount) private {
        if (rewardBudget < amount) return; // budget épuisé : on ne bloque jamais une certification
        rewardBudget -= amount;
        freeBalance[to] += amount;
    }

    // ---------- Pool d'évaluateurs ----------

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

    function withdraw(uint256 amount) external nonReentrant {
        if (freeBalance[msg.sender] < amount) revert Insufficient();
        freeBalance[msg.sender] -= amount;
        token.safeTransfer(msg.sender, amount);
    }

    // ---------- Candidature ----------

    function applyForPassport(bytes32 handleHash, string calldata proofCid) external returns (uint256 id) {
        if (sbt.tokenOf(msg.sender) != 0) revert NotEligible();
        if (activeApplicationOf[msg.sender] != 0) revert NotEligible();
        if (block.timestamp < nextApplyAt[msg.sender]) revert TooEarly();
        address owner_ = handleOwner[handleHash];
        if (owner_ != address(0) && owner_ != msg.sender) revert NotEligible(); // compte déjà certifié

        id = ++applicationCount;
        Application storage a = _applications[id];
        a.candidate = msg.sender;
        a.handleHash = handleHash;
        a.proofCid = proofCid;
        a.openedAt = uint64(block.timestamp);
        a.phase = Phase.Drawing;
        activeApplicationOf[msg.sender] = id;

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
        _requestToApplication[requestId] = id;
        emit Applied(id, msg.sender, handleHash, proofCid);
    }

    /// @dev Rappel VRF : ne doit jamais revert.
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        uint256 id = _requestToApplication[requestId];
        Application storage a = _applications[id];
        if (a.phase != Phase.Drawing) return;

        uint256 n = _tickets.length;
        for (uint256 i; i < MAX_DRAW_ATTEMPTS && a.jurors.length < JURY_SIZE && n > 0; ++i) {
            address cand = _tickets[uint256(keccak256(abi.encode(randomWords[0], i))) % n];
            if (
                !inPool[cand] || cand == a.candidate || isJuror[id][cand] || hasJudged[a.candidate][cand]
                    || freeBalance[cand] < JUDGE_STAKE || !sbt.isActiveHolder(cand)
            ) continue;
            isJuror[id][cand] = true;
            freeBalance[cand] -= JUDGE_STAKE;
            a.jurors.push(cand);
        }
        if (a.jurors.length < JURY_SIZE) {
            _cancel(id, a);
            return;
        }
        a.commitEnd = uint64(block.timestamp) + COMMIT_PERIOD;
        a.revealEnd = a.commitEnd + REVEAL_PERIOD;
        a.phase = Phase.Voting;
        emit JuryDrawn(id, a.jurors, a.commitEnd, a.revealEnd);
    }

    function cancelStuck(uint256 id) external {
        Application storage a = _applications[id];
        if (a.phase != Phase.Drawing) revert WrongPhase();
        if (block.timestamp < a.openedAt + DRAW_TIMEOUT) revert TooEarly();
        _cancel(id, a);
    }

    function _cancel(uint256 id, Application storage a) private {
        for (uint256 i; i < a.jurors.length; ++i) freeBalance[a.jurors[i]] += JUDGE_STAKE;
        a.phase = Phase.Closed;
        activeApplicationOf[a.candidate] = 0;
        emit ApplicationCancelled(id);
    }

    // ---------- Vote ----------

    /// @param commitment keccak256(abi.encode(id, juré, note, sel)), note de 0 (rejet) à 5
    function commitScore(uint256 id, bytes32 commitment) external {
        Application storage a = _applications[id];
        if (a.phase != Phase.Voting || !isJuror[id][msg.sender]) revert WrongPhase();
        if (block.timestamp >= a.commitEnd) revert TooLate();
        if (commitOf[id][msg.sender] != bytes32(0)) revert BadScore();
        commitOf[id][msg.sender] = commitment;
        emit ScoreCommitted(id, msg.sender);
    }

    function revealScore(uint256 id, uint8 score, bytes32 salt) external {
        Application storage a = _applications[id];
        if (a.phase != Phase.Voting) revert WrongPhase();
        if (block.timestamp < a.commitEnd) revert TooEarly();
        if (block.timestamp >= a.revealEnd) revert TooLate();
        if (score > 5 || scorePlusOne[id][msg.sender] != 0) revert BadScore();
        if (keccak256(abi.encode(id, msg.sender, score, salt)) != commitOf[id][msg.sender]) revert BadReveal();
        scorePlusOne[id][msg.sender] = score + 1;
        emit ScoreRevealed(id, msg.sender, score);
    }

    // ---------- Finalisation ----------

    /// @notice Appelable par n'importe qui après la fin du reveal.
    function finalize(uint256 id) external nonReentrant {
        Application storage a = _applications[id];
        if (a.phase != Phase.Voting) revert WrongPhase();
        if (block.timestamp < a.revealEnd) revert TooEarly();
        a.phase = Phase.Closed;
        activeApplicationOf[a.candidate] = 0;

        // 1. Notes révélées, triées par insertion (5 éléments au plus)
        uint256 len = a.jurors.length;
        uint8[] memory scores = new uint8[](len);
        uint256 revealed;
        uint256 pot;
        for (uint256 i; i < len; ++i) {
            address j = a.jurors[i];
            uint8 s = scorePlusOne[id][j];
            if (s == 0) {
                pot += JUDGE_STAKE; // absent : caution perdue
                continue;
            }
            freeBalance[j] += JUDGE_STAKE;
            hasJudged[a.candidate][j] = true;
            uint256 k = revealed++;
            while (k > 0 && scores[k - 1] > s - 1) {
                scores[k] = scores[k - 1];
                --k;
            }
            scores[k] = s - 1;
        }

        // 2. Cautions perdues : 10 % brûlés, le reste à la trésorerie
        if (pot > 0) {
            uint256 burned = (pot * BURN_BPS) / 10_000;
            token.burn(burned);
            freeBalance[treasury] += pot - burned;
        }

        bool quorum = revealed >= QUORUM;
        uint256 tokenId;
        if (quorum) {
            // médiane basse : en cas de nombre pair, le doute ne profite pas au candidat
            uint8 median = scores[(revealed - 1) / 2];
            a.level = median;

            // 3. Récompense des jurés à un niveau ou moins de la médiane
            for (uint256 i; i < len; ++i) {
                uint8 s = scorePlusOne[id][a.jurors[i]];
                if (s == 0) continue;
                uint8 score = s - 1;
                uint8 gap = score > median ? score - median : median - score;
                if (gap <= 1) _payFromBudget(a.jurors[i], EVALUATION_REWARD);
            }

            // 4. Mint ou rejet
            if (median >= 1 && sbt.tokenOf(a.candidate) == 0) {
                handleOwner[a.handleHash] = a.candidate;
                tokenId = sbt.mint(a.candidate, median, a.jurors, a.proofCid);
                _payFromBudget(a.candidate, WELCOME_GRANT);
            } else {
                nextApplyAt[a.candidate] = uint64(block.timestamp) + REAPPLY_COOLDOWN;
            }
        }
        // sans quorum : pas de décision, le candidat peut redéposer immédiatement
        emit Finalized(id, quorum, a.level, tokenId);
    }

    // ---------- Lecture ----------

    function getApplication(uint256 id) external view returns (Application memory) {
        return _applications[id];
    }

    function ticketCount() external view returns (uint256) {
        return _tickets.length;
    }
}
