// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {PasseportToken} from "../../src/PasseportToken.sol";
import {PasseportSBT, IPassportRegistry} from "../../src/PasseportSBT.sol";
import {PassportRegistry} from "../../src/PassportRegistry.sol";
import {Certification, ICertToken, ICertSBT} from "../../src/Certification.sol";

contract CertificationHandler is Test {
    Certification public cert;
    PasseportToken public token;
    VRFCoordinatorV2_5Mock public vrf;

    address[] public jurors;
    address[] public candidates;
    uint256[] public pendingRequests;
    uint256 public nextRequestId = 1;
    uint256 public applied;
    uint256 public finalized;
    uint256 public recused;
    mapping(uint256 => mapping(address => uint8)) public plannedScorePlusOne;

    constructor(Certification c_, PasseportToken t_, VRFCoordinatorV2_5Mock v_, address[] memory j, address[] memory cand) {
        cert = c_;
        token = t_;
        vrf = v_;
        jurors = j;
        candidates = cand;
    }

    function actors() external view returns (address[] memory all) {
        all = new address[](jurors.length + candidates.length);
        for (uint256 i; i < jurors.length; ++i) all[i] = jurors[i];
        for (uint256 i; i < candidates.length; ++i) all[jurors.length + i] = candidates[i];
    }

    function _id(uint256 seed) internal view returns (uint256) {
        uint256 n = cert.applicationCount();
        return n == 0 ? 0 : 1 + (seed % n);
    }

    function apply_(uint256 candSeed) external {
        uint256 k = candSeed % candidates.length;
        address cand = candidates[k];
        vm.prank(cand);
        try cert.applyForPassport(keccak256(abi.encode("handle", k)), "sha256:dossier") {
            pendingRequests.push(nextRequestId++);
            ++applied;
        } catch {}
    }

    function fulfill(uint256 seed) external {
        if (pendingRequests.length == 0) return;
        uint256 i = seed % pendingRequests.length;
        uint256 reqId = pendingRequests[i];
        pendingRequests[i] = pendingRequests[pendingRequests.length - 1];
        pendingRequests.pop();
        try vrf.fulfillRandomWords(reqId, address(cert)) {} catch {}
    }

    /// @dev Notes de tout le jury tiré (certains s'abstiennent selon la graine).
    function commitAll(uint256 idSeed, uint256 scoreSeed) external {
        uint256 id = _id(idSeed);
        if (id == 0) return;
        address[] memory jury = cert.getApplication(id).jurors;
        for (uint256 i; i < jury.length; ++i) {
            uint256 r = uint256(keccak256(abi.encode(scoreSeed, i))) % 7; // 6 = abstention
            if (r == 6) continue;
            uint8 sc = uint8(r);
            vm.prank(jury[i]);
            try cert.commitScore(id, keccak256(abi.encode(id, jury[i], sc, bytes32(id)))) {
                plannedScorePlusOne[id][jury[i]] = sc + 1;
            } catch {}
        }
    }

    function revealAll(uint256 idSeed) external {
        uint256 id = _id(idSeed);
        if (id == 0) return;
        address[] memory jury = cert.getApplication(id).jurors;
        for (uint256 i; i < jury.length; ++i) {
            uint8 p = plannedScorePlusOne[id][jury[i]];
            if (p == 0) continue;
            vm.prank(jury[i]);
            try cert.revealScore(id, p - 1, bytes32(id)) {} catch {}
        }
    }

    function recuse(uint256 idSeed, uint256 jurorSeed) external {
        uint256 id = _id(idSeed);
        if (id == 0) return;
        address[] memory jury = cert.getApplication(id).jurors;
        if (jury.length == 0) return;
        address j = jury[jurorSeed % jury.length];
        vm.prank(j);
        try cert.recuse(id) {
            pendingRequests.push(nextRequestId++);
            plannedScorePlusOne[id][j] = 0;
            ++recused;
        } catch {}
    }

    function finalize(uint256 idSeed) external {
        uint256 id = _id(idSeed);
        if (id == 0) return;
        Certification.Application memory before = cert.getApplication(id);
        try cert.finalize(id) {
            ++finalized;
            Certification.Application memory afterApp = cert.getApplication(id);
            // re-tirage : une nouvelle requête VRF a été émise
            if (afterApp.redraws > before.redraws) pendingRequests.push(nextRequestId++);
        } catch {}
    }

    function cancelStuck(uint256 idSeed) external {
        uint256 id = _id(idSeed);
        if (id == 0) return;
        try cert.cancelStuck(id) {} catch {}
    }

    function warp(uint256 dt) external {
        vm.warp(block.timestamp + bound(dt, 1 hours, 5 days));
    }

    function withdraw(uint256 actorSeed, uint256 amount) external {
        address[] memory all = this.actors();
        address a = all[actorSeed % all.length];
        uint256 bal = cert.freeBalance(a);
        if (bal == 0) return;
        vm.prank(a);
        try cert.withdraw(bound(amount, 1, bal)) {} catch {}
    }

    function joinPool(uint256 jurorSeed, uint256 amount) external {
        address j = jurors[jurorSeed % jurors.length];
        uint256 amt = bound(amount, 0, token.balanceOf(j));
        vm.prank(j);
        try cert.joinPool(amt) {} catch {}
    }
}

contract CertificationInvariantTest is Test {
    PasseportToken token;
    PasseportSBT sbt;
    PassportRegistry registry;
    Certification cert;
    VRFCoordinatorV2_5Mock vrf;
    CertificationHandler handler;
    address treasury = makeAddr("treasury");

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
        cert = new Certification(address(vrf), subId, bytes32(0), ICertToken(address(token)), ICertSBT(address(sbt)), treasury);
        vrf.addConsumer(subId, address(cert));

        bytes32 certifier = sbt.CERTIFIER_ROLE();
        sbt.grantRole(certifier, address(this));
        sbt.grantRole(certifier, address(cert));
        token.grantRole(token.TRANSFER_ROLE(), address(this));
        token.grantRole(token.TRANSFER_ROLE(), address(cert));
        token.grantRole(token.BURNER_ROLE(), address(cert));

        token.approve(address(cert), 20_000e18);
        cert.fund(20_000e18);

        address[] memory none = new address[](0);
        address[] memory jurors = new address[](14);
        for (uint256 i; i < 14; ++i) {
            address j = makeAddr(string.concat("genesis", vm.toString(i)));
            jurors[i] = j;
            sbt.mint(j, uint8(1 + (i % 3)), none, "");
            token.transfer(j, 2_000e18);
            vm.startPrank(j);
            token.approve(address(cert), type(uint256).max);
            cert.joinPool(600e18);
            vm.stopPrank();
        }
        address[] memory candidates = new address[](6);
        for (uint256 i; i < 6; ++i) candidates[i] = makeAddr(string.concat("candidate", vm.toString(i)));

        handler = new CertificationHandler(cert, token, vrf, jurors, candidates);
        targetContract(address(handler));
    }

    /// @dev Montre que les chemins de finalisation et de récusation sont bien atteints.
    function afterInvariant() external view {
        console2.log("candidatures / finalisations / recusations", handler.applied(), handler.finalized(), handler.recused());
    }

    /// @notice PCT détenus = soldes libres + budget de récompenses + cautions bloquées.
    /// forge-config: default.invariant.runs = 64
    /// forge-config: default.invariant.depth = 128
    /// forge-config: default.invariant.fail-on-revert = false
    function invariant_BalanceMatchesAccounting() public view {
        uint256 accounted = cert.freeBalance(treasury) + cert.rewardBudget();
        address[] memory all = handler.actors();
        for (uint256 i; i < all.length; ++i) accounted += cert.freeBalance(all[i]);

        uint256 n = cert.applicationCount();
        for (uint256 id = 1; id <= n; ++id) {
            Certification.Application memory a = cert.getApplication(id);
            if (a.phase == Certification.Phase.Drawing || a.phase == Certification.Phase.Voting) {
                accounted += a.jurors.length * cert.JUDGE_STAKE();
            }
        }
        assertEq(token.balanceOf(address(cert)), accounted, "PCT detenus != comptabilite");
    }

    /// @notice Un compte de plateforme ne porte jamais deux Passeports.
    /// forge-config: default.invariant.runs = 64
    /// forge-config: default.invariant.depth = 128
    /// forge-config: default.invariant.fail-on-revert = false
    function invariant_OnePassportPerCandidate() public view {
        address[] memory all = handler.actors();
        for (uint256 i; i < all.length; ++i) assertLe(sbt.balanceOf(all[i]), 1);
    }
}
