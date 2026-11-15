// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {PasseportToken} from "../src/PasseportToken.sol";
import {PasseportSBT, IPassportRegistry} from "../src/PasseportSBT.sol";
import {PassportRegistry} from "../src/PassportRegistry.sol";
import {FounderVesting} from "../src/FounderVesting.sol";
import {Contestation, IPCT, ISBT} from "../src/Contestation.sol";

contract ProtocolTest is Test {
    address constant FOUNDER = 0x723DFb2A1dd6a8f4b5Dd2a499A0B870f13A60477;
    PasseportToken token;
    PasseportSBT sbt;
    PassportRegistry registry;
    FounderVesting vesting;
    Contestation contestation;
    VRFCoordinatorV2_5Mock vrf;

    address creator = makeAddr("creator");
    address challenger = makeAddr("challenger");
    address treasury = makeAddr("treasury");
    address[] jurors;
    uint256 creatorToken;

    function setUp() public {
        vrf = new VRFCoordinatorV2_5Mock(0.1 ether, 1e9, 4e15);
        uint256 subId = vrf.createSubscription();
        vrf.fundSubscription(subId, 100 ether);

        vesting = new FounderVesting();
        address[] memory to = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        (to[0], amounts[0]) = (address(vesting), 250_000_000e18);
        (to[1], amounts[1]) = (address(this), 750_000_000e18);
        token = new PasseportToken(address(this), to, amounts);

        registry = new PassportRegistry(address(this));
        sbt = new PasseportSBT(address(this), IPassportRegistry(address(registry)));
        registry.grantRole(registry.RECORDER_ROLE(), address(sbt));
        contestation = new Contestation(address(vrf), subId, bytes32(0), IPCT(address(token)), ISBT(address(sbt)), treasury);
        vrf.addConsumer(subId, address(contestation));

        sbt.grantRole(sbt.CERTIFIER_ROLE(), address(this));
        sbt.grantRole(sbt.CONTEST_ROLE(), address(contestation));
        token.grantRole(token.TRANSFER_ROLE(), address(this));
        token.grantRole(token.TRANSFER_ROLE(), address(vesting));
        token.grantRole(token.TRANSFER_ROLE(), address(contestation));
        token.grantRole(token.BURNER_ROLE(), address(contestation));

        address[] memory none = new address[](0);
        creatorToken = sbt.mint(creator, 3, none, "sha256:dossier");

        for (uint256 i; i < 8; ++i) {
            address j = makeAddr(string.concat("juror", vm.toString(i)));
            jurors.push(j);
            sbt.mint(j, 1, none, "");
            token.transfer(j, 200e18);
            vm.startPrank(j);
            token.approve(address(contestation), 200e18);
            contestation.joinPool(200e18);
            vm.stopPrank();
        }
        token.transfer(challenger, 500e18);
        vm.prank(challenger);
        token.approve(address(contestation), 500e18);
    }

    // ---------- Passeport ----------

    function test_MintSetsPassport() public view {
        assertEq(sbt.ownerOf(creatorToken), creator);
        assertTrue(sbt.isActive(creatorToken));
        assertEq(sbt.levelOf(creatorToken), 3);
        assertEq(registry.creatorCount(), 9);
    }

    function test_TransferReverts() public {
        vm.prank(creator);
        vm.expectRevert(PasseportSBT.Soulbound.selector);
        sbt.transferFrom(creator, challenger, creatorToken);
    }

    function test_ApproveReverts() public {
        vm.prank(creator);
        vm.expectRevert(PasseportSBT.Soulbound.selector);
        sbt.approve(challenger, creatorToken);
    }

    function test_OnePassportPerAddress() public {
        address[] memory none = new address[](0);
        vm.expectRevert(PasseportSBT.AlreadyCertified.selector);
        sbt.mint(creator, 2, none, "");
    }

    // ---------- Token ----------

    function test_SupplyIsFixed() public view {
        assertEq(token.totalSupply(), 1_000_000_000e18);
    }

    function test_RestrictedTransferReverts() public {
        vm.prank(challenger);
        vm.expectRevert(PasseportToken.TransferRestricted.selector);
        token.transfer(creator, 1e18);
    }

    // ---------- Vesting ----------

    function test_VestingNothingBeforeCliff() public {
        vm.warp(block.timestamp + 364 days);
        assertEq(vesting.releasable(address(token)), 0);
    }

    function test_VestingLinearAfterCliff_AnyoneCanRelease() public {
        vm.warp(block.timestamp + 365 days + 365 days); // mois 24
        vm.prank(challenger); // un tiers déclenche la libération
        vesting.release(address(token));
        assertApproxEqAbs(token.balanceOf(FOUNDER), 83_333_333e18, 1e18);
        vm.warp(block.timestamp + 730 days); // mois 48
        vesting.release(address(token));
        assertEq(token.balanceOf(FOUNDER), 250_000_000e18);
    }

    function test_VestingBeneficiaryLocked() public {
        vm.prank(FOUNDER);
        vm.expectRevert(FounderVesting.BeneficiaryLocked.selector);
        vesting.transferOwnership(challenger);
    }

    // ---------- Contestation ----------

    function _openAndDraw() internal returns (uint256 id, address[] memory drawn) {
        vm.prank(challenger);
        id = contestation.openContest(creatorToken, "sha256:preuves");
        vrf.fulfillRandomWords(1, address(contestation)); // premier requestId du mock
        drawn = contestation.getContest(id).jurors;
        assertEq(drawn.length, 5);
    }

    function test_OpenContestMarksPassport() public {
        _openAndDraw();
        assertFalse(sbt.isActive(creatorToken));
        assertEq(registry.openContests(), 1);
    }

    function test_UpheldContest_RevokesSlashesAndBurns() public {
        (uint256 id, address[] memory drawn) = _openAndDraw();

        // juré 0 vote "rejeter" (1), les quatre autres "révoquer" (3)
        for (uint256 i; i < 5; ++i) {
            uint8 v = i == 0 ? uint8(1) : uint8(3);
            vm.prank(drawn[i]);
            contestation.commitVote(id, keccak256(abi.encode(id, drawn[i], v, bytes32(i))));
        }
        vm.warp(block.timestamp + 48 hours);
        for (uint256 i; i < 5; ++i) {
            vm.prank(drawn[i]);
            contestation.revealVote(id, i == 0 ? uint8(1) : uint8(3), bytes32(i));
        }
        vm.warp(block.timestamp + 24 hours);
        contestation.resolve(id); // appelable par n'importe qui

        // Pot = 200 (juré minoritaire). 20 brûlés, 90 au contestataire, 90 partagés entre 4 majoritaires (22,5 chacun).
        assertEq(uint8(sbt.getPassport(creatorToken).status), uint8(PasseportSBT.Status.Revoked));
        assertEq(token.totalSupply(), 1_000_000_000e18 - 20e18);
        assertEq(contestation.freeBalance(challenger), 590e18);
        assertEq(contestation.freeBalance(drawn[0]), 0);
        assertEq(contestation.freeBalance(drawn[1]), 222.5e18); // caution 200 + 22,5
        assertEq(registry.openContests(), 0);
    }

    function test_NoQuorum_RestoresPassportAndRefundsChallenger() public {
        (uint256 id,) = _openAndDraw();
        vm.warp(block.timestamp + 72 hours);
        contestation.resolve(id);
        assertTrue(sbt.isActive(creatorToken));
        assertEq(contestation.freeBalance(challenger), 500e18);
        assertEq(contestation.freeBalance(treasury), 900e18); // 5 cautions perdues, moins 10 % brûlés
    }

    function test_BadRevealReverts() public {
        (uint256 id, address[] memory drawn) = _openAndDraw();
        vm.prank(drawn[0]);
        contestation.commitVote(id, keccak256(abi.encode(id, drawn[0], uint8(1), bytes32(0))));
        vm.warp(block.timestamp + 48 hours);
        vm.prank(drawn[0]);
        vm.expectRevert(Contestation.BadReveal.selector);
        contestation.revealVote(id, 3, bytes32(0));
    }

    // ---------- Autonomie ----------

    function test_RenounceAdminIsFinal() public {
        bytes32 admin = sbt.DEFAULT_ADMIN_ROLE();
        sbt.renounceRole(admin, address(this));
        assertFalse(sbt.hasRole(admin, address(this)));
        vm.expectRevert();
        sbt.grantRole(sbt.CERTIFIER_ROLE(), challenger);
    }
}
