// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {PasseportToken} from "../src/PasseportToken.sol";
import {PasseportSBT, IPassportRegistry} from "../src/PasseportSBT.sol";
import {PassportRegistry} from "../src/PassportRegistry.sol";
import {Certification, ICertToken, ICertSBT} from "../src/Certification.sol";

contract CertificationTest is Test {
    PasseportToken token;
    PasseportSBT sbt;
    PassportRegistry registry;
    Certification cert;
    VRFCoordinatorV2_5Mock vrf;

    address candidate = makeAddr("candidate");
    address treasury = makeAddr("treasury");
    bytes32 handle = keccak256(abi.encode("youtube", "candidat"));

    function setUp() public {
        vrf = new VRFCoordinatorV2_5Mock(0.1 ether, 1e9, 4e15);
        uint256 subId = vrf.createSubscription();
        vrf.fundSubscription(subId, 100 ether);

        address[] memory to = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        (to[0], amounts[0]) = (address(this), 1_000_000_000e18);
        token = new PasseportToken(address(this), to, amounts);
        registry = new PassportRegistry(address(this));
        sbt = new PasseportSBT(address(this), IPassportRegistry(address(registry)));
        registry.grantRole(registry.RECORDER_ROLE(), address(sbt));

        cert = new Certification(address(vrf), subId, bytes32(0), ICertToken(address(token)), ICertSBT(address(sbt)), treasury);
        vrf.addConsumer(subId, address(cert));

        sbt.grantRole(sbt.CERTIFIER_ROLE(), address(this)); // cohorte genèse
        sbt.grantRole(sbt.CERTIFIER_ROLE(), address(cert));
        token.grantRole(token.TRANSFER_ROLE(), address(this));
        token.grantRole(token.TRANSFER_ROLE(), address(cert));
        token.grantRole(token.BURNER_ROLE(), address(cert));

        token.approve(address(cert), 100_000e18);
        cert.fund(100_000e18);

        address[] memory none = new address[](0);
        for (uint256 i; i < 8; ++i) {
            address j = makeAddr(string.concat("genesis", vm.toString(i)));
            sbt.mint(j, 1, none, "");
            token.transfer(j, 200e18);
            vm.startPrank(j);
            token.approve(address(cert), 200e18);
            cert.joinPool(200e18);
            vm.stopPrank();
        }
    }

    function _applyAndDraw() internal returns (uint256 id, address[] memory drawn) {
        vm.prank(candidate);
        id = cert.applyForPassport(handle, "sha256:dossier");
        vrf.fulfillRandomWords(1, address(cert));
        drawn = cert.getApplication(id).jurors;
        assertEq(drawn.length, 5);
    }

    function _vote(uint256 id, address[] memory drawn, uint8[5] memory scores) internal {
        for (uint256 i; i < 5; ++i) {
            vm.prank(drawn[i]);
            cert.commitScore(id, keccak256(abi.encode(id, drawn[i], scores[i], bytes32(i))));
        }
        vm.warp(block.timestamp + 72 hours);
        for (uint256 i; i < 5; ++i) {
            vm.prank(drawn[i]);
            cert.revealScore(id, scores[i], bytes32(i));
        }
        vm.warp(block.timestamp + 24 hours);
        cert.finalize(id);
    }

    function test_MedianMintsPassportAndPaysRewards() public {
        (uint256 id, address[] memory drawn) = _applyAndDraw();
        _vote(id, drawn, [uint8(3), 3, 4, 2, 5]); // médiane 3

        uint256 tokenId = sbt.tokenOf(candidate);
        assertGt(tokenId, 0);
        assertEq(sbt.levelOf(tokenId), 3);
        assertTrue(sbt.wasEvaluator(tokenId, drawn[0]));
        assertEq(cert.freeBalance(candidate), 1_000e18);  // dotation d'accueil
        assertEq(cert.freeBalance(drawn[0]), 220e18);     // caution + récompense
        assertEq(cert.freeBalance(drawn[4]), 200e18);     // note 5 : trop loin de la médiane
        assertEq(cert.handleOwner(handle), candidate);
    }

    function test_MedianZeroRejectsAndSetsCooldown() public {
        (uint256 id, address[] memory drawn) = _applyAndDraw();
        _vote(id, drawn, [uint8(0), 0, 0, 2, 1]);
        assertEq(sbt.tokenOf(candidate), 0);
        vm.prank(candidate);
        vm.expectRevert(Certification.TooEarly.selector);
        cert.applyForPassport(handle, "sha256:dossier");
    }

    function test_NoQuorum_SlashesAbsentJurors() public {
        (uint256 id,) = _applyAndDraw();
        vm.warp(block.timestamp + 96 hours);
        cert.finalize(id);
        assertEq(sbt.tokenOf(candidate), 0);
        assertEq(cert.freeBalance(treasury), 900e18); // 5 cautions, moins 10 % brûlés
        assertEq(token.totalSupply(), 1_000_000_000e18 - 100e18);
    }

    function test_HolderCannotApply() public {
        address holder = makeAddr("genesis0");
        vm.prank(holder);
        vm.expectRevert(Certification.NotEligible.selector);
        cert.applyForPassport(handle, "");
    }
}
