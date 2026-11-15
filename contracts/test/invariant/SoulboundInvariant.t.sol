// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PasseportSBT, IPassportRegistry} from "../../src/PasseportSBT.sol";
import {PassportRegistry} from "../../src/PassportRegistry.sol";

/// @dev Tente tout ce qui pourrait déplacer un Passeport, depuis le propriétaire et des tiers.
contract SoulboundHandler is Test {
    PasseportSBT public sbt;
    address[] public holders;
    uint256[] public ids;

    constructor(PasseportSBT s, address[] memory h, uint256[] memory i) {
        sbt = s;
        holders = h;
        ids = i;
    }

    function transferFrom(uint256 fromSeed, uint256 toSeed, uint256 idSeed) external {
        address from = holders[fromSeed % holders.length];
        address to = holders[toSeed % holders.length];
        vm.prank(from);
        try sbt.transferFrom(from, to, ids[idSeed % ids.length]) {} catch {}
    }

    function safeTransferFrom(uint256 fromSeed, address to, uint256 idSeed) external {
        address from = holders[fromSeed % holders.length];
        if (to == address(0)) to = address(1);
        vm.prank(from);
        try sbt.safeTransferFrom(from, to, ids[idSeed % ids.length]) {} catch {}
    }

    function approve(uint256 fromSeed, address spender, uint256 idSeed) external {
        vm.prank(holders[fromSeed % holders.length]);
        try sbt.approve(spender, ids[idSeed % ids.length]) {} catch {}
    }

    function setApprovalForAll(uint256 fromSeed, address op, bool ok) external {
        vm.prank(holders[fromSeed % holders.length]);
        try sbt.setApprovalForAll(op, ok) {} catch {}
    }

    function strangerTransfer(address stranger, uint256 idSeed) external {
        uint256 id = ids[idSeed % ids.length];
        address owner = sbt.ownerOf(id);
        vm.prank(stranger);
        try sbt.transferFrom(owner, stranger, id) {} catch {}
    }
}

contract SoulboundInvariantTest is Test {
    PasseportSBT sbt;
    SoulboundHandler handler;
    address[] holders;
    uint256[] ids;

    function setUp() public {
        PassportRegistry registry = new PassportRegistry(address(this));
        sbt = new PasseportSBT(address(this), IPassportRegistry(address(registry)));
        registry.grantRole(registry.RECORDER_ROLE(), address(sbt));
        bytes32 certifier = sbt.CERTIFIER_ROLE();
        sbt.grantRole(certifier, address(this));
        address[] memory none = new address[](0);
        for (uint256 i; i < 6; ++i) {
            address h = makeAddr(string.concat("holder", vm.toString(i)));
            holders.push(h);
            ids.push(sbt.mint(h, uint8(1 + (i % 5)), none, ""));
        }
        handler = new SoulboundHandler(sbt, holders, ids);
        targetContract(address(handler));
    }

    /// forge-config: default.invariant.runs = 64
    /// forge-config: default.invariant.depth = 64
    /// forge-config: default.invariant.fail-on-revert = false
    function invariant_OwnersNeverChange() public view {
        for (uint256 i; i < ids.length; ++i) {
            assertEq(sbt.ownerOf(ids[i]), holders[i]);
            assertEq(sbt.balanceOf(holders[i]), 1);
            assertEq(sbt.getApproved(ids[i]), address(0));
        }
    }
}
