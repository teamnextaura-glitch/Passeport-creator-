// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title PasseportToken (PCT) : token utilitaire de staking et de gouvernance
/// @notice Supply fixe. Transferts restreints tant que la DAO ne les ouvre pas.
contract PasseportToken is ERC20, ERC20Pausable, AccessControl {
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");     // contrats de staking
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");     // Timelock DAO
    bytes32 public constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE"); // vesting, staking, Safe DAO

    uint256 public constant MAX_SUPPLY = 1_000_000_000e18;
    bool public transfersRestricted = true;

    error TransferRestricted();
    error BadDistribution();

    event TransfersOpened();

    /// @param admin déployeur temporaire ; remplacé par le Timelock puis renoncé
    constructor(address admin, address[] memory recipients, uint256[] memory amounts)
        ERC20("Passeport Token", "PCT")
    {
        if (recipients.length != amounts.length) revert BadDistribution();
        uint256 total;
        for (uint256 i; i < recipients.length; ++i) {
            _mint(recipients[i], amounts[i]);
            total += amounts[i];
        }
        if (total != MAX_SUPPLY) revert BadDistribution();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @notice Brûle les tokens détenus par l'appelant (part des stakes perdus).
    function burn(uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(msg.sender, amount);
    }

    function pause() external onlyRole(PAUSER_ROLE) { _pause(); }
    function unpause() external onlyRole(PAUSER_ROLE) { _unpause(); }

    /// @notice Ouverture définitive des transferts. Décision DAO, sans retour.
    function openTransfers() external onlyRole(DEFAULT_ADMIN_ROLE) {
        transfersRestricted = false;
        emit TransfersOpened();
    }

    /// @dev Phase 1 : un transfert exige TRANSFER_ROLE d'un côté au moins.
    ///      Un détenteur ne peut donc envoyer ses tokens qu'à un contrat du protocole.
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Pausable) {
        if (
            transfersRestricted && from != address(0) && to != address(0)
                && !hasRole(TRANSFER_ROLE, from) && !hasRole(TRANSFER_ROLE, to)
        ) revert TransferRestricted();
        super._update(from, to, value);
    }
}
