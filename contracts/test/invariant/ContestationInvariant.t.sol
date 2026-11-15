// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {PasseportToken} from "../../src/PasseportToken.sol";
import {PasseportSBT, IPassportRegistry} from "../../src/PasseportSBT.sol";
import {PassportRegistry} from "../../src/PassportRegistry.sol";
import {Contestation, IPCT, ISBT} from "../../src/Contestation.sol";

/// @dev Acteurs bornés ; tout appel qui revert est absorbé (try/catch).
contract ContestationHandler is Test {
    Contestation public c;
    PasseportToken public token;
    VRFCoordinatorV2_5Mock public vrf;

    address[] public jurors;
    address[] public challengers;
    uint256[] public targets;
    uint256[] public pendingRequests;
    uint256 public nextRequestId = 1;
    uint256 public opened;
    uint256 public resolved;
    uint256 public cancelled;

    mapping(uint256 => mapping(address => uint8)) public plannedVote;

    constructor(Contestation c_, PasseportToken t_, VRFCoordinatorV2_5Mock v_, address[] memory j, address[] memory ch, uint256[] memory tg) {
        c = c_;
        token = t_;
        vrf = v_;
        jurors = j;
        challengers = ch;
        targets = tg;
    }

    function actors() external view returns (address[] memory all) {
        all = new address[](jurors.length + challengers.length);
        for (uint256 i; i < jurors.length; ++i) all[i] = jurors[i];
        for (uint256 i; i < challengers.length; ++i) all[jurors.length + i] = challengers[i];
    }

    function open(uint256 targetSeed, uint256 challSeed) external {
        address ch = challengers[challSeed % challengers.length];
        uint256 tokenId = targets[targetSeed % targets.length];
        vm.prank(ch);
        try c.openContest(tokenId, "sha256:preuves") {
            pendingRequests.push(nextRequestId++);
            ++opened;
        } catch {}
    }

    function fulfill(uint256 seed) external {
        if (pendingRequests.length == 0) return;
        uint256 i = seed % pendingRequests.length;
        uint256 reqId = pendingRequests[i];
        pendingRequests[i] = pendingRequests[pendingRequests.length - 1];
        pendingRequests.pop();
        try vrf.fulfillRandomWords(reqId, address(c)) {} catch {}
    }

    /// @dev Vote de tout le jury tiré (certains s'abstiennent selon la graine).
    function commitAll(uint256 idSeed, uint256 voteSeed) external {
        uint256 n = c.contestCount();
        if (n == 0) return;
        uint256 id = 1 + (idSeed % n);
        address[] memory jury = c.getContest(id).jurors;
        for (uint256 i; i < jury.length; ++i) {
            uint256 r = uint256(keccak256(abi.encode(voteSeed, i))) % 4; // 0 = abstention
            if (r == 0) continue;
            uint8 v = uint8(r);
            vm.prank(jury[i]);
            try c.commitVote(id, keccak256(abi.encode(id, jury[i], v, bytes32(id)))) {
                plannedVote[id][jury[i]] = v;
            } catch {}
        }
    }

    function revealAll(uint256 idSeed) external {
        uint256 n = c.contestCount();
        if (n == 0) return;
        uint256 id = 1 + (idSeed % n);
        address[] memory jury = c.getContest(id).jurors;
        for (uint256 i; i < jury.length; ++i) {
            uint8 v = plannedVote[id][jury[i]];
            if (v == 0) continue;
            vm.prank(jury[i]);
            try c.revealVote(id, v, bytes32(id)) {} catch {}
        }
    }

    function resolve(uint256 idSeed) external {
        uint256 n = c.contestCount();
        if (n == 0) return;
        try c.resolve(1 + (idSeed % n)) {
            ++resolved;
        } catch {}
    }

    function cancelStuck(uint256 idSeed) external {
        uint256 n = c.contestCount();
        if (n == 0) return;
        try c.cancelStuck(1 + (idSeed % n)) {
            ++cancelled;
        } catch {}
    }

    function warp(uint256 dt) external {
        vm.warp(block.timestamp + bound(dt, 1 hours, 4 days));
    }

    function withdraw(uint256 actorSeed, uint256 amount) external {
        address[] memory all = this.actors();
        address a = all[actorSeed % all.length];
        uint256 bal = c.freeBalance(a);
        if (bal == 0) return;
        vm.prank(a);
        try c.withdraw(bound(amount, 1, bal)) {} catch {}
    }

    function joinPool(uint256 jurorSeed, uint256 amount) external {
        address j = jurors[jurorSeed % jurors.length];
        uint256 amt = bound(amount, 0, token.balanceOf(j));
        vm.prank(j);
        try c.joinPool(amt) {} catch {}
    }
}

contract ContestationInvariantTest is Test {
    PasseportToken token;
    PasseportSBT sbt;
    PassportRegistry registry;
    Contestation c;
    VRFCoordinatorV2_5Mock vrf;
    ContestationHandler handler;
    address treasury = makeAddr("treasury");
    uint256[] tokenIds;
    address[] owners;

    function setUp() public {
        vrf = new VRFCoordinatorV2_5Mock(0.1 ether, 1e9, 4e15);
        uint256 subId = vrf.createSubscription();
        vrf.fundSubscription(subId, 1e27);

        address[] memory to = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        (to[0], amounts[0]) = (address(this), 1_000_000_000e18);
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
        address[] memory jurors = new address[](10);
        for (uint256 i; i < 10; ++i) {
            address j = makeAddr(string.concat("juror", vm.toString(i)));
            jurors[i] = j;
            tokenIds.push(sbt.mint(j, uint8(1 + (i % 3)), none, ""));
            owners.push(j);
            token.transfer(j, 2_000e18);
            vm.startPrank(j);
            token.approve(address(c), type(uint256).max);
            c.joinPool(600e18);
            vm.stopPrank();
        }
        address[] memory challengers = new address[](3);
        for (uint256 i; i < 3; ++i) {
            address ch = makeAddr(string.concat("challenger", vm.toString(i)));
            challengers[i] = ch;
            token.transfer(ch, 10_000e18);
            vm.prank(ch);
            token.approve(address(c), type(uint256).max);
        }
        uint256[] memory targets = new uint256[](3);
        for (uint256 i; i < 3; ++i) {
            address cr = makeAddr(string.concat("creator", vm.toString(i)));
            targets[i] = sbt.mint(cr, 3, none, "");
            tokenIds.push(targets[i]);
            owners.push(cr);
        }

        handler = new ContestationHandler(c, token, vrf, jurors, challengers, targets);
        targetContract(address(handler));
    }

    /// @dev Montre que les chemins de résolution sont bien atteints.
    function afterInvariant() external view {
        console2.log("contestations ouvertes / resolues / annulees", handler.opened(), handler.resolved(), handler.cancelled());
    }

    /// @notice Les PCT détenus par Contestation = soldes libres + cautions et mises bloquées.
    /// forge-config: default.invariant.runs = 64
    /// forge-config: default.invariant.depth = 128
    /// forge-config: default.invariant.fail-on-revert = false
    function invariant_BalanceMatchesAccounting() public view {
        uint256 accounted = c.freeBalance(treasury);
        address[] memory all = handler.actors();
        for (uint256 i; i < all.length; ++i) accounted += c.freeBalance(all[i]);

        uint256 n = c.contestCount();
        for (uint256 id = 1; id <= n; ++id) {
            Contestation.Contest memory k = c.getContest(id);
            if (k.phase == Contestation.Phase.Drawing || k.phase == Contestation.Phase.Voting) {
                accounted += c.CHALLENGE_STAKE() + k.jurors.length * c.JUDGE_STAKE();
            }
        }
        assertEq(token.balanceOf(address(c)), accounted, "PCT detenus != comptabilite");
    }

    /// @notice Supply : seule la part brûlée la fait baisser, jamais au-dessus du plafond.
    /// forge-config: default.invariant.runs = 64
    /// forge-config: default.invariant.depth = 128
    /// forge-config: default.invariant.fail-on-revert = false
    function invariant_SupplyNeverAboveCap() public view {
        assertLe(token.totalSupply(), token.MAX_SUPPLY());
    }

    /// @notice Soulbound : aucun Passeport ne change de propriétaire, même révoqué.
    /// forge-config: default.invariant.runs = 64
    /// forge-config: default.invariant.depth = 128
    /// forge-config: default.invariant.fail-on-revert = false
    function invariant_PassportsNeverMove() public view {
        for (uint256 i; i < tokenIds.length; ++i) assertEq(sbt.ownerOf(tokenIds[i]), owners[i]);
    }
}
