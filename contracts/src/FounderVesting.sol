// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {VestingWallet} from "@openzeppelin/contracts/finance/VestingWallet.sol";

/// @title Vesting fondateur : cliff 12 mois puis linéaire 36 mois, irrévocable
/// @notice release(token) est public : les tokens partent toujours vers FOUNDER.
contract FounderVesting is VestingWallet {
    address public constant FOUNDER = 0x723DFb2A1dd6a8f4b5Dd2a499A0B870f13A60477;
    uint64 public constant CLIFF = 365 days;
    uint64 public constant LINEAR = 1095 days; // 36 mois

    error BeneficiaryLocked();

    constructor() VestingWallet(FOUNDER, uint64(block.timestamp) + CLIFF, LINEAR) {}

    /// @dev Le bénéficiaire ne peut être ni changé ni abandonné.
    function transferOwnership(address) public pure override { revert BeneficiaryLocked(); }
    function renounceOwnership() public pure override { revert BeneficiaryLocked(); }
}
