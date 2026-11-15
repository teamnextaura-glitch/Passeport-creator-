// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {PasseportToken} from "../src/PasseportToken.sol";
import {PasseportSBT, IPassportRegistry} from "../src/PasseportSBT.sol";
import {PassportRegistry} from "../src/PassportRegistry.sol";
import {FounderVesting} from "../src/FounderVesting.sol";
import {Contestation, IPCT, ISBT} from "../src/Contestation.sol";

/// @notice Conservation du pot de Contestation.resolve() et formule du vesting fondateur.
contract FuzzResolveTest is Test {
    PasseportToken token;
    PasseportSBT sbt;
    PassportRegistry registry;
    Contestation c;
    VRFCoordinatorV2_5Mock vrf;
    FounderVesting vesting;

    address creator = makeAddr("creator");
    address challenger = makeAddr("challenger");
    address treasury = makeAddr("treasury");
    uint256 creatorToken;
    uint256 t0;

    function setUp() public {
        t0 = block.timestamp;
        vrf = new VRFCoordinatorV2_5Mock(0.1 ether, 1e9, 4e15);
        uint256 subId = vrf.createSubscription();
        vrf.fundSubscription(subId, 1e27);

        vesting = new FounderVesting();
        address[] memory to = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        (to[0], amounts[0]) = (address(vesting), 250_000_000e18);
        (to[1], amounts[1]) = (address(this), 750_000_000e18);
        token = new PasseportToken(address(this), to, amounts);
        registry = new PassportRegistry(address(this));
        sbt = new PasseportSBT(address(this), IPassportRegistry(address(registry)));
        registry.grantRole(registry.RECORDER_ROLE(), address(sbt));
        c = new Contestation(address(vrf), subId, bytes32(0), IPCT(address(token)), ISBT(address(sbt)), treasury);
        vrf.addConsumer(subId, address(c));

        bytes32 certifier = sbt.CERTIFIER_ROLE();
        sbt.grantRole(certifier, address(this));
        sbt.grantRole(sbt.CONTEST_ROLE(), address(c));
        token.grantRole(token.TRANSFER_ROLE(), address(this));
        token.grantRole(token.TRANSFER_ROLE(), address(c));
        token.grantRole(token.BURNER_ROLE(), address(c));

        address[] memory none = new address[](0);
        creatorToken = sbt.mint(creator, 3, none, "");
        // exactement 5 jurés à un ticket : le jury tiré est forcément ces 5 adresses
        for (uint256 i; i < 5; ++i) {
            address j = makeAddr(string.concat("juror", vm.toString(i)));
            sbt.mint(j, 1, none, "");
            token.transfer(j, 200e18);
            vm.startPrank(j);
            token.approve(address(c), 200e18);
            c.joinPool(200e18);
            vm.stopPrank();
        }
        token.transfer(challenger, 500e18);
        vm.prank(challenger);
        token.approve(address(c), 500e18);
    }

    /// @param votes 0 = absent, 1 rejeter, 2 rétrograder, 3 révoquer
    function testFuzz_ResolveConservesPot(uint8[5] memory votes) public {
        vm.prank(challenger);
        uint256 id = c.openContest(creatorToken, "sha256:preuves");
        vrf.fulfillRandomWords(1, address(c));
        address[] memory drawn = c.getContest(id).jurors;
        if (drawn.length < 5) return; // tirage incomplet : annulé, hors sujet ici

        uint256 nReject;
        uint256 nDown;
        uint256 nRevoke;
        for (uint256 i; i < 5; ++i) {
            votes[i] = votes[i] % 4;
            if (votes[i] == 0) continue;
            vm.prank(drawn[i]);
            c.commitVote(id, keccak256(abi.encode(id, drawn[i], votes[i], bytes32(i))));
            if (votes[i] == 1) ++nReject;
            else if (votes[i] == 2) ++nDown;
            else ++nRevoke;
        }
        vm.warp(t0 + 48 hours);
        for (uint256 i; i < 5; ++i) {
            if (votes[i] == 0) continue;
            vm.prank(drawn[i]);
            c.revealVote(id, votes[i], bytes32(i));
        }
        vm.warp(t0 + 72 hours);

        uint256 supplyBefore = token.totalSupply();
        uint256 heldBefore = token.balanceOf(address(c));
        c.resolve(id);

        // Pot attendu, recalculé indépendamment du contrat
        bool quorum = nReject + nDown + nRevoke >= 3;
        bool upheld = quorum && (nDown + nRevoke) > nReject;
        uint256 pot;
        for (uint256 i; i < 5; ++i) {
            bool win = votes[i] != 0 && (!quorum || ((votes[i] != 1) == upheld));
            if (!win) pot += 200e18;
        }
        if (quorum && !upheld) pot += 500e18;
        uint256 expectedBurn = pot / 10;

        uint256 burned = supplyBefore - token.totalSupply();
        assertEq(burned, expectedBurn, "part brulee");

        uint256 credited = c.freeBalance(challenger) + c.freeBalance(treasury);
        for (uint256 i; i < 5; ++i) credited += c.freeBalance(drawn[i]);
        assertEq(credited + burned, 1_500e18, "pot + cautions non conserves");
        assertEq(token.balanceOf(address(c)), heldBefore - burned, "PCT du contrat");
    }

    function testFuzz_VestingFormula(uint64 t) public view {
        uint64 start = uint64(vesting.start());
        uint64 dur = uint64(vesting.duration());
        t = uint64(bound(t, 0, uint256(start) + 10 * 365 days));
        uint256 v = vesting.vestedAmount(address(token), t);
        if (t < start) assertEq(v, 0, "avant le cliff");
        else if (t >= start + dur) assertEq(v, 250_000_000e18, "apres 48 mois");
        else assertEq(v, (250_000_000e18 * uint256(t - start)) / dur, "lineaire");
    }

    function testFuzz_VestingMonotonic(uint64 a, uint64 b) public view {
        uint256 hi = uint256(vesting.start()) + 10 * 365 days;
        a = uint64(bound(a, 0, hi));
        b = uint64(bound(b, a, hi));
        assertLe(vesting.vestedAmount(address(token), a), vesting.vestedAmount(address(token), b));
    }

    function test_CliffIsTwelveMonthsAfterDeploy() public view {
        assertEq(vesting.start(), t0 + 365 days);
        assertEq(vesting.duration(), 1095 days);
    }
}
