// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

interface IPassportRegistry {
    function record(address creator, uint256 tokenId, uint8 kind, uint8 level, string calldata cid) external;
}

/// @title Passeport Créateur : token de réputation non transférable
/// @notice Un Passeport par adresse. Ni transfert, ni approbation, ni burn.
contract PasseportSBT is ERC721, AccessControl {
    using Strings for uint256;

    bytes32 public constant CERTIFIER_ROLE = keccak256("CERTIFIER_ROLE"); // contrat Certification
    bytes32 public constant CONTEST_ROLE = keccak256("CONTEST_ROLE");     // contrat Contestation

    enum Status { None, Active, Contested, Revoked }
    enum Outcome { Dismissed, Downgraded, Revoked }
    // Types d'entrées envoyées au registre
    uint8 internal constant K_MINT = 0;
    uint8 internal constant K_LEVEL = 1;
    uint8 internal constant K_CONTESTED = 2;
    uint8 internal constant K_DISMISSED = 3;
    uint8 internal constant K_DOWNGRADED = 4;
    uint8 internal constant K_REVOKED = 5;

    struct Passport {
        uint8 level;          // 1 à 5
        Status status;
        uint64 issuedAt;
        uint64 updatedAt;
        string proofCid;      // empreinte du dossier de preuves (pas de données personnelles)
        address[] evaluators; // jury ayant certifié
    }

    error Soulbound();
    error AlreadyCertified();
    error BadLevel();
    error BadStatus();

    IPassportRegistry public immutable registry;
    uint256 public nextId = 1;
    mapping(uint256 => Passport) private _passports;
    mapping(address => uint256) public tokenOf;
    mapping(uint256 => mapping(address => bool)) public wasEvaluator;

    event PassportMinted(uint256 indexed tokenId, address indexed creator, uint8 level, string proofCid);
    event PassportLevelChanged(uint256 indexed tokenId, uint8 oldLevel, uint8 newLevel);
    event PassportStatusChanged(uint256 indexed tokenId, Status status);

    constructor(address admin, IPassportRegistry registry_) ERC721("Passeport Createur", "PASSEPORT") {
        registry = registry_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    // ---------- Écriture ----------

    /// @notice Réservé au contrat de certification.
    function mint(address to, uint8 level, address[] calldata evaluators, string calldata proofCid)
        external onlyRole(CERTIFIER_ROLE) returns (uint256 id)
    {
        if (tokenOf[to] != 0) revert AlreadyCertified();
        if (level == 0 || level > 5) revert BadLevel();
        id = nextId++;
        Passport storage p = _passports[id];
        p.level = level;
        p.status = Status.Active;
        p.issuedAt = p.updatedAt = uint64(block.timestamp);
        p.proofCid = proofCid;
        p.evaluators = evaluators;
        for (uint256 i; i < evaluators.length; ++i) wasEvaluator[id][evaluators[i]] = true;
        tokenOf[to] = id;
        _mint(to, id); // _mint et non _safeMint : aucun rappel externe
        emit PassportMinted(id, to, level, proofCid);
        registry.record(to, id, K_MINT, level, proofCid);
    }

    /// @notice Montée de niveau après une nouvelle évaluation.
    function setLevel(uint256 tokenId, uint8 newLevel) external onlyRole(CERTIFIER_ROLE) {
        Passport storage p = _passports[tokenId];
        if (p.status != Status.Active) revert BadStatus();
        if (newLevel == 0 || newLevel > 5) revert BadLevel();
        emit PassportLevelChanged(tokenId, p.level, newLevel);
        p.level = newLevel;
        p.updatedAt = uint64(block.timestamp);
        registry.record(ownerOf(tokenId), tokenId, K_LEVEL, newLevel, "");
    }

    /// @notice Ouverture d'une contestation : le Passeport reste visible mais marqué.
    function contest(uint256 tokenId) external onlyRole(CONTEST_ROLE) {
        Passport storage p = _passports[tokenId];
        if (p.status != Status.Active) revert BadStatus();
        _setStatus(tokenId, p, Status.Contested, K_CONTESTED);
    }

    /// @notice Issue de la contestation, appelée par le contrat Contestation.
    function resolveContest(uint256 tokenId, Outcome outcome) external onlyRole(CONTEST_ROLE) {
        Passport storage p = _passports[tokenId];
        if (p.status != Status.Contested) revert BadStatus();
        if (outcome == Outcome.Dismissed) {
            _setStatus(tokenId, p, Status.Active, K_DISMISSED);
        } else if (outcome == Outcome.Downgraded && p.level > 1) {
            emit PassportLevelChanged(tokenId, p.level, p.level - 1);
            p.level -= 1;
            _setStatus(tokenId, p, Status.Active, K_DOWNGRADED);
        } else {
            _setStatus(tokenId, p, Status.Revoked, K_REVOKED); // niveau 1 rétrogradé = révoqué
        }
    }

    /// @notice Révocation directe, réservée au contrat Contestation.
    function revoke(uint256 tokenId) external onlyRole(CONTEST_ROLE) {
        Passport storage p = _passports[tokenId];
        if (p.status == Status.None || p.status == Status.Revoked) revert BadStatus();
        _setStatus(tokenId, p, Status.Revoked, K_REVOKED);
    }

    function _setStatus(uint256 tokenId, Passport storage p, Status s, uint8 kind) private {
        p.status = s;
        p.updatedAt = uint64(block.timestamp);
        emit PassportStatusChanged(tokenId, s);
        registry.record(ownerOf(tokenId), tokenId, kind, p.level, "");
    }

    // ---------- Lecture ----------

    function getPassport(uint256 tokenId) external view returns (Passport memory) {
        return _passports[tokenId];
    }

    function isActive(uint256 tokenId) public view returns (bool) {
        return _passports[tokenId].status == Status.Active;
    }

    function isActiveHolder(address who) external view returns (bool) {
        uint256 id = tokenOf[who];
        return id != 0 && isActive(id);
    }

    function levelOf(uint256 tokenId) external view returns (uint8) {
        return _passports[tokenId].level;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        Passport storage p = _passports[tokenId];
        string memory json = string.concat(
            '{"name":"Passeport Createur #', tokenId.toString(),
            '","isDemo":false,"attributes":[{"trait_type":"level","value":', uint256(p.level).toString(),
            '},{"trait_type":"status","value":', uint256(uint8(p.status)).toString(),
            '},{"trait_type":"issuedAt","value":', uint256(p.issuedAt).toString(),
            '}],"proofCid":"', p.proofCid, '"}'
        );
        return string.concat("data:application/json;base64,", Base64.encode(bytes(json)));
    }

    // ---------- Soulbound ----------

    /// @dev Seul le mint (from == 0) passe. Transfert et burn sont refusés.
    function _update(address to, uint256 tokenId, address auth) internal override returns (address from) {
        from = _ownerOf(tokenId);
        if (from != address(0)) revert Soulbound();
        return super._update(to, tokenId, auth);
    }

    function approve(address, uint256) public pure override { revert Soulbound(); }
    function setApprovalForAll(address, bool) public pure override { revert Soulbound(); }

    function supportsInterface(bytes4 id) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(id);
    }
}
