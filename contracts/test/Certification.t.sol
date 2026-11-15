// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {PasseportToken} from "../src/PasseportToken.sol";
import {PasseportSBT, IPassportRegistry} from "../src/PasseportSBT.sol";
import {PassportRegistry} from "../src/PassportRegistry.sol";
import {Certification, ICertToken, ICertSBT} from "../src/Certification.sol";

/// Déploiement commun : un pool de jurés genèse de taille variable.
abstract contract CertificationBase is Test {
    PasseportToken token;
    PasseportSBT sbt;
    PassportRegistry registry;
    Certification cert;
    VRFCoordinatorV2_5Mock vrf;

    address candidate = makeAddr("candidate");
    address treasury = makeAddr("treasury");
    bytes32 handle = keccak256(abi.encode("youtube", "candidat"));
    uint256 nextRequest = 1; // le mock numérote les requêtes à partir de 1

    function poolSize() internal pure virtual returns (uint256);

    function stakePerJuror() internal pure virtual returns (uint256) {
        return 200e18;
    }

    function setUp() public {
        vrf = new VRFCoordinatorV2_5Mock(0.1 ether, 1e9, 4e15);
        uint256 subId = vrf.createSubscription();
        vrf.fundSubscription(subId, 1_000 ether);

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
        uint256 stake = stakePerJuror();
        for (uint256 i; i < poolSize(); ++i) {
            address j = makeAddr(string.concat("genesis", vm.toString(i)));
            sbt.mint(j, 1, none, "");
            token.transfer(j, stake);
            vm.startPrank(j);
            token.approve(address(cert), stake);
            cert.joinPool(stake);
            vm.stopPrank();
        }
    }

    function _fulfill() internal {
        vrf.fulfillRandomWords(nextRequest++, address(cert));
    }

    function _apply(address who, bytes32 h) internal returns (uint256 id) {
        vm.prank(who);
        id = cert.applyForPassport(h, "sha256:dossier");
        _fulfill();
    }

    function _jurors(uint256 id) internal view returns (address[] memory) {
        return cert.getApplication(id).jurors;
    }

    function _phase(uint256 id) internal view returns (uint8) {
        return uint8(cert.getApplication(id).phase);
    }

    function _vote(uint256 id, address[] memory drawn, uint8[5] memory scores) internal {
        for (uint256 i; i < 5; ++i) {
            vm.prank(drawn[i]);
            cert.commitScore(id, keccak256(abi.encode(id, drawn[i], scores[i], bytes32(i))));
        }
        vm.warp(cert.getApplication(id).commitEnd);
        for (uint256 i; i < 5; ++i) {
            vm.prank(drawn[i]);
            cert.revealScore(id, scores[i], bytes32(i));
        }
        vm.warp(cert.getApplication(id).revealEnd);
        cert.finalize(id);
    }

    /// Personne ne vote : fin du reveal puis finalize.
    function _noShow(uint256 id) internal {
        vm.warp(cert.getApplication(id).revealEnd);
        cert.finalize(id);
    }

    function _contains(address[] memory xs, address x) internal pure returns (bool) {
        for (uint256 i; i < xs.length; ++i) if (xs[i] == x) return true;
        return false;
    }
}

/// Pool large (16 jurés) : vote, récusation, re-tirage.
contract CertificationTest is CertificationBase {
    function poolSize() internal pure override returns (uint256) {
        return 16;
    }

    // ---------- Vote ----------

    function test_MedianMintsPassportAndPaysRewards() public {
        uint256 id = _apply(candidate, handle);
        address[] memory drawn = _jurors(id);
        assertEq(drawn.length, 5);
        _vote(id, drawn, [uint8(3), 3, 4, 2, 5]); // médiane 3

        uint256 tokenId = sbt.tokenOf(candidate);
        assertGt(tokenId, 0);
        assertEq(sbt.levelOf(tokenId), 3);
        assertTrue(sbt.wasEvaluator(tokenId, drawn[0]));
        assertEq(cert.freeBalance(candidate), 1_000e18); // dotation d'accueil
        assertEq(cert.freeBalance(drawn[0]), 220e18);    // caution + récompense
        assertEq(cert.freeBalance(drawn[4]), 200e18);    // note 5 : trop loin de la médiane
        assertEq(cert.handleOwner(handle), candidate);
    }

    function test_MedianZeroRejectsAndSetsCooldown() public {
        uint256 id = _apply(candidate, handle);
        _vote(id, _jurors(id), [uint8(0), 0, 0, 2, 1]);
        assertEq(sbt.tokenOf(candidate), 0);
        vm.prank(candidate);
        vm.expectRevert(Certification.TooEarly.selector);
        cert.applyForPassport(handle, "sha256:dossier");
    }

    function test_HolderCannotApply() public {
        address holder = makeAddr("genesis0");
        vm.prank(holder);
        vm.expectRevert(Certification.NotEligible.selector);
        cert.applyForPassport(handle, "");
    }

    // ---------- Récusation ----------

    function test_Recuse_RefundsAndReplaces_ThenMints() public {
        uint256 id = _apply(candidate, handle);
        address[] memory first = _jurors(id);
        address quitter = first[0];

        vm.prank(quitter);
        cert.recuse(id);
        assertEq(cert.freeBalance(quitter), 200e18); // caution rendue, sans pénalité
        assertEq(_jurors(id).length, 4);
        assertTrue(cert.getApplication(id).replacing);
        assertTrue(cert.excluded(id, quitter));

        _fulfill(); // requête de remplacement
        address[] memory jury = _jurors(id);
        assertEq(jury.length, 5);
        assertFalse(_contains(jury, quitter));
        assertFalse(cert.getApplication(id).replacing);

        _vote(id, jury, [uint8(4), 4, 4, 4, 4]);
        assertEq(sbt.levelOf(sbt.tokenOf(candidate)), 4);
        assertFalse(sbt.wasEvaluator(sbt.tokenOf(candidate), quitter));
    }

    function test_Recuse_AfterWindowReverts() public {
        uint256 id = _apply(candidate, handle);
        address juror = _jurors(id)[0];
        vm.warp(block.timestamp + 24 hours);
        vm.prank(juror);
        vm.expectRevert(Certification.TooLate.selector);
        cert.recuse(id);
    }

    function test_Recuse_OneReplacementAtATime() public {
        uint256 id = _apply(candidate, handle);
        address[] memory jury = _jurors(id);
        vm.prank(jury[0]);
        cert.recuse(id);
        vm.prank(jury[1]);
        vm.expectRevert(Certification.ReplacementPending.selector);
        cert.recuse(id);
    }

    // ---------- Re-tirage ----------

    function test_NoQuorum_SlashesAbsentsAndRedraws() public {
        uint256 id = _apply(candidate, handle);
        _noShow(id);
        assertEq(cert.freeBalance(treasury), 900e18); // 5 cautions, moins 10 % brûlés
        assertEq(token.totalSupply(), 1_000_000_000e18 - 100e18);
        assertEq(_phase(id), uint8(Certification.Phase.Drawing));
        assertEq(cert.getApplication(id).redraws, 1);
        assertEq(cert.activeApplicationOf(candidate), id); // la candidature reste ouverte
    }

    function test_Redraw_SecondJuryIsNewAndMints() public {
        uint256 id = _apply(candidate, handle);
        address[] memory first = _jurors(id);
        _noShow(id);

        _fulfill(); // re-tirage
        address[] memory second = _jurors(id);
        assertEq(second.length, 5);
        for (uint256 i; i < 5; ++i) assertFalse(_contains(first, second[i]));

        _vote(id, second, [uint8(3), 3, 3, 3, 3]);
        assertEq(sbt.levelOf(sbt.tokenOf(candidate)), 3);
    }

    function test_Redraw_ExhaustedClosesWithoutDecision() public {
        uint256 id = _apply(candidate, handle);
        _noShow(id);   // re-tirage 1
        _fulfill();
        _noShow(id);   // re-tirage 2
        _fulfill();
        _noShow(id);   // plus de re-tirage : clôture

        assertEq(_phase(id), uint8(Certification.Phase.Closed));
        assertEq(cert.getApplication(id).redraws, 2);
        assertEq(sbt.tokenOf(candidate), 0);
        assertEq(cert.activeApplicationOf(candidate), 0);
        assertEq(cert.freeBalance(treasury), 2_700e18); // 15 cautions perdues, moins 10 %

        vm.prank(candidate); // pas de délai : aucune décision n'a été prise
        cert.applyForPassport(handle, "sha256:dossier");
    }
}

/// Pool minimal (5 jurés, caution large) : plafond de charge.
contract CertificationLoadCapTest is CertificationBase {
    function poolSize() internal pure override returns (uint256) {
        return 5;
    }

    function stakePerJuror() internal pure override returns (uint256) {
        return 1_200e18; // assez pour 6 dossiers : seul le plafond limite
    }

    function test_LoadCap_SkipsJurorsAtCap_ThenResetsAfterWindow() public {
        for (uint256 k; k < 5; ++k) {
            address c = makeAddr(string.concat("cand", vm.toString(k)));
            uint256 id = _apply(c, keccak256(abi.encode("youtube", k)));
            assertEq(_jurors(id).length, 5);
        }
        address juror = makeAddr("genesis0");
        assertEq(cert.currentLoad(juror), 5);

        // 6e dossier : tous les jurés sont au plafond, le tirage échoue et la candidature est annulée
        address late = makeAddr("cand5");
        bytes32 lateHandle = keccak256(abi.encode("youtube", uint256(5)));
        uint256 blocked = _apply(late, lateHandle);
        assertEq(_phase(blocked), uint8(Certification.Phase.Closed));
        assertEq(_jurors(blocked).length, 0);
        assertEq(cert.activeApplicationOf(late), 0);

        // 7 jours plus tard, la fenêtre repart à zéro
        vm.warp(block.timestamp + 7 days);
        assertEq(cert.currentLoad(juror), 0);
        uint256 retry = _apply(late, lateHandle);
        assertEq(_jurors(retry).length, 5);
    }
}
