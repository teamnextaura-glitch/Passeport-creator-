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
///         - Récusation : un juré tiré peut se retirer sans pénalité pendant les 24 premières
///           heures du commit ; il est remplacé par un nouveau tirage, un juré à la fois.
///         - Plafond : un juré est tiré au plus 5 fois par fenêtre de 7 jours.
///         - Re-tirage : sans quorum, les absents sont slashés et un nouveau jury est tiré,
///           au plus 2 fois ; ensuite la candidature est close sans décision.
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
    uint64 public constant RECUSAL_WINDOW = 24 hours;
    uint64 public constant REAPPLY_COOLDOWN = 30 days;
    uint64 public constant DRAW_TIMEOUT = 24 hours;
    uint64 public constant LOAD_WINDOW = 7 days;
    uint8 public constant MAX_LOAD = 5;
    uint8 public constant MAX_REDRAWS = 2;
    uint256 public constant BURN_BPS = 1_000; // 10 %
    uint256 internal constant MAX_DRAW_ATTEMPTS = 60;
    uint32 internal constant CALLBACK_GAS = 2_500_000;

    enum Phase { None, Drawing, Voting, Closed }
    enum RequestKind { None, Initial, Replacement, Redraw }

    struct Application {
        address candidate;
        bytes32 handleHash; // keccak256(plateforme, pseudo) : unicité du compte
        string proofCid;    // empreinte du dossier hors-chaîne
        uint64 openedAt;    // début du tirage en cours
        uint64 commitEnd;
        uint64 revealEnd;
        Phase phase;
        uint8 level;        // 0 = rejet ou pas de décision
        uint8 redraws;      // re-tirages déjà effectués
        bool replacing;     // un remplacement de juré est en attente du VRF
        address[] jurors;
    }

    struct Request {
        uint256 applicationId;
        RequestKind kind;
    }

    ICertToken public immutable token;
    ICertSBT public immutable sbt;
    address public immutable treasury;
    uint256 public immutable subId;
    bytes32 public immutable keyHash;

    uint256 public applicationCount;
    mapping(uint256 => Application) private _applications;
    mapping(uint256 => Request) private _requests; // requestId VRF => objet de la requête
    mapping(uint256 => mapping(address => bool)) public isJuror;
    mapping(uint256 => mapping(address => bool)) public excluded; // récusés et jurys précédents
    mapping(uint256 => mapping(address => bytes32)) public commitOf;
    mapping(uint256 => mapping(address => uint8)) public scorePlusOne; // 0 = non révélé
    mapping(address => uint256) public activeApplicationOf;
    mapping(address => uint64) public nextApplyAt;
    mapping(bytes32 => address) public handleOwner;
    mapping(address => mapping(address => bool)) public hasJudged; // candidat => juré

    // Pool d'évaluateurs, charge et budget de récompenses
    mapping(address => uint256) public freeBalance;
    mapping(address => bool) public inPool;
    mapping(address => bool) private _ticketed;
    mapping(address => uint64) public loadWindowStart;
    mapping(address => uint8) public loadCount;
    address[] private _tickets;
    uint256 public rewardBudget; // alimenté par la DAO via fund()

    error NotEligible();
    error WrongPhase();
    error TooEarly();
    error TooLate();
    error BadScore();
    error BadReveal();
    error Insufficient();
    error ReplacementPending();

    event Funded(address indexed from, uint256 amount);
    event PoolJoined(address indexed juror, uint256 tickets);
    event PoolLeft(address indexed juror);
    event Applied(uint256 indexed id, address indexed candidate, bytes32 handleHash, string proofCid);
    event RandomnessRequested(uint256 indexed requestId, uint256 indexed id, RequestKind kind);
    event JuryDrawn(uint256 indexed id, address[] jurors, uint64 commitEnd, uint64 revealEnd);
    event Recused(uint256 indexed id, address indexed juror);
    event JurorReplaced(uint256 indexed id, address indexed juror);
    event Redrawn(uint256 indexed id, uint8 round);
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

    /// @notice Nombre de dossiers attribués au juré dans sa fenêtre de 7 jours en cours.
    function currentLoad(address juror) public view returns (uint8) {
        if (block.timestamp >= uint256(loadWindowStart[juror]) + LOAD_WINDOW) return 0;
        return loadCount[juror];
    }

    function _addLoad(address juror) private {
        if (loadCount[juror] == 0 || block.timestamp >= uint256(loadWindowStart[juror]) + LOAD_WINDOW) {
            loadWindowStart[juror] = uint64(block.timestamp);
            loadCount[juror] = 1;
        } else {
            ++loadCount[juror];
        }
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

        emit Applied(id, msg.sender, handleHash, proofCid);
        _requestRandom(id, RequestKind.Initial);
    }

    function _requestRandom(uint256 id, RequestKind kind) private returns (uint256 requestId) {
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: subId,
                requestConfirmations: 3,
                callbackGasLimit: CALLBACK_GAS,
                numWords: 1,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
        _requests[requestId] = Request(id, kind);
        emit RandomnessRequested(requestId, id, kind);
    }

    /// @dev Rappel VRF : ne doit jamais revert. Chaque requête est reliée à son objet.
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        Request memory r = _requests[requestId];
        delete _requests[requestId];
        if (r.kind == RequestKind.None) return;
        uint256 id = r.applicationId;
        Application storage a = _applications[id];

        if (r.kind == RequestKind.Replacement) {
            if (a.phase != Phase.Voting || !a.replacing) return; // finalisée ou annulée entre-temps
            a.replacing = false;
            _fillJury(id, a, randomWords[0]);
            if (a.jurors.length < JURY_SIZE) {
                _cancel(id, a); // personne pour remplacer : annulation, cautions rendues
                return;
            }
            emit JurorReplaced(id, a.jurors[a.jurors.length - 1]);
            return;
        }

        // Tirage initial ou re-tirage : jury complet
        if (a.phase != Phase.Drawing) return;
        _fillJury(id, a, randomWords[0]);
        if (a.jurors.length < JURY_SIZE) {
            _cancel(id, a);
            return;
        }
        a.commitEnd = uint64(block.timestamp) + COMMIT_PERIOD;
        a.revealEnd = a.commitEnd + REVEAL_PERIOD;
        a.phase = Phase.Voting;
        emit JuryDrawn(id, a.jurors, a.commitEnd, a.revealEnd);
    }

    /// @dev Complète le jury jusqu'à JURY_SIZE, en sautant les jurés inéligibles.
    function _fillJury(uint256 id, Application storage a, uint256 seed) private {
        uint256 n = _tickets.length;
        for (uint256 i; i < MAX_DRAW_ATTEMPTS && a.jurors.length < JURY_SIZE && n > 0; ++i) {
            address cand = _tickets[uint256(keccak256(abi.encode(seed, i))) % n];
            if (!_eligible(id, a.candidate, cand)) continue;
            isJuror[id][cand] = true;
            freeBalance[cand] -= JUDGE_STAKE;
            _addLoad(cand);
            a.jurors.push(cand);
        }
    }

    function _eligible(uint256 id, address candidate, address cand) private view returns (bool) {
        if (!inPool[cand] || cand == candidate || isJuror[id][cand] || excluded[id][cand]) return false;
        if (hasJudged[candidate][cand] || freeBalance[cand] < JUDGE_STAKE) return false;
        if (currentLoad(cand) >= MAX_LOAD) return false;
        return sbt.isActiveHolder(cand);
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
        a.replacing = false;
        activeApplicationOf[a.candidate] = 0;
        emit ApplicationCancelled(id);
    }

    // ---------- Récusation ----------

    /// @notice Un juré tiré se retire sans pénalité dans les 24 premières heures du commit.
    ///         Sa caution lui est rendue ; un remplaçant est tiré. Un remplacement à la fois.
    function recuse(uint256 id) external nonReentrant {
        Application storage a = _applications[id];
        if (a.phase != Phase.Voting || !isJuror[id][msg.sender]) revert WrongPhase();
        if (block.timestamp >= uint256(a.commitEnd) - COMMIT_PERIOD + RECUSAL_WINDOW) revert TooLate();
        if (a.replacing) revert ReplacementPending();

        uint256 last = a.jurors.length - 1;
        for (uint256 i; i <= last; ++i) {
            if (a.jurors[i] == msg.sender) {
                a.jurors[i] = a.jurors[last];
                a.jurors.pop();
                break;
            }
        }
        isJuror[id][msg.sender] = false;
        excluded[id][msg.sender] = true;
        delete commitOf[id][msg.sender];
        freeBalance[msg.sender] += JUDGE_STAKE;
        if (loadCount[msg.sender] > 0) --loadCount[msg.sender];
        a.replacing = true;

        emit Recused(id, msg.sender);
        _requestRandom(id, RequestKind.Replacement);
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
        if (a.phase != Phase.Voting || !isJuror[id][msg.sender]) revert WrongPhase();
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
        a.replacing = false; // un remplacement encore en attente est abandonné

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

        // 3. Sans quorum : re-tirage, ou clôture sans décision
        if (revealed < QUORUM) {
            if (a.redraws < MAX_REDRAWS) {
                _redraw(id, a);
                return;
            }
            a.phase = Phase.Closed;
            activeApplicationOf[a.candidate] = 0; // le candidat peut redéposer immédiatement
            emit Finalized(id, false, 0, 0);
            return;
        }

        a.phase = Phase.Closed;
        activeApplicationOf[a.candidate] = 0;

        // médiane basse : en cas de nombre pair, le doute ne profite pas au candidat
        uint8 median = scores[(revealed - 1) / 2];
        a.level = median;

        // 4. Récompense des jurés à un niveau ou moins de la médiane
        for (uint256 i; i < len; ++i) {
            uint8 s = scorePlusOne[id][a.jurors[i]];
            if (s == 0) continue;
            uint8 score = s - 1;
            uint8 gap = score > median ? score - median : median - score;
            if (gap <= 1) _payFromBudget(a.jurors[i], EVALUATION_REWARD);
        }

        // 5. Mint ou rejet
        uint256 tokenId;
        if (median >= 1 && sbt.tokenOf(a.candidate) == 0) {
            handleOwner[a.handleHash] = a.candidate;
            tokenId = sbt.mint(a.candidate, median, a.jurors, a.proofCid);
            _payFromBudget(a.candidate, WELCOME_GRANT);
        } else {
            nextApplyAt[a.candidate] = uint64(block.timestamp) + REAPPLY_COOLDOWN;
        }
        emit Finalized(id, true, a.level, tokenId);
    }

    /// @dev Écarte le jury sortant de cette candidature et demande un nouveau tirage.
    function _redraw(uint256 id, Application storage a) private {
        ++a.redraws;
        for (uint256 i; i < a.jurors.length; ++i) {
            address j = a.jurors[i];
            isJuror[id][j] = false;
            excluded[id][j] = true;
        }
        delete a.jurors;
        a.phase = Phase.Drawing;
        a.openedAt = uint64(block.timestamp);
        a.commitEnd = 0;
        a.revealEnd = 0;
        emit Redrawn(id, a.redraws);
        _requestRandom(id, RequestKind.Redraw);
    }

    // ---------- Lecture ----------

    function getApplication(uint256 id) external view returns (Application memory) {
        return _applications[id];
    }

    function requestOf(uint256 requestId) external view returns (Request memory) {
        return _requests[requestId];
    }

    function ticketCount() external view returns (uint256) {
        return _tickets.length;
    }
}
