// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {PasseportToken} from "../src/PasseportToken.sol";
import {PasseportSBT, IPassportRegistry} from "../src/PasseportSBT.sol";
import {PassportRegistry} from "../src/PassportRegistry.sol";
import {FounderVesting} from "../src/FounderVesting.sol";
import {Contestation, IPCT, ISBT} from "../src/Contestation.sol";

/// Étape 1 : déploie tout. Le déployeur garde l'admin le temps de la cohorte genèse.
contract Deploy is Script {
    function run() external {
        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(pk);
        address daoSafe = vm.envAddress("DAO_SAFE");
        address council = vm.envAddress("COUNCIL_SAFE");

        vm.startBroadcast(pk);

        // 1. Timelock : proposeur = Safe DAO, exécuteur = tout le monde
        address[] memory proposers = new address[](1);
        proposers[0] = daoSafe;
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        TimelockController timelock = new TimelockController(48 hours, proposers, executors, deployer);
        timelock.grantRole(timelock.CANCELLER_ROLE(), council);

        // 2. Vesting fondateur (bénéficiaire codé en dur)
        FounderVesting vesting = new FounderVesting();

        // 3. Token : 250 M au vesting, 750 M au Safe DAO
        address[] memory to = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        (to[0], amounts[0]) = (address(vesting), 250_000_000e18);
        (to[1], amounts[1]) = (daoSafe, 750_000_000e18);
        PasseportToken token = new PasseportToken(deployer, to, amounts);

        // 4. Registre puis Passeport
        PassportRegistry registry = new PassportRegistry(deployer);
        PasseportSBT sbt = new PasseportSBT(deployer, IPassportRegistry(address(registry)));
        registry.grantRole(registry.RECORDER_ROLE(), address(sbt));

        // 5. Contestation
        Contestation contestation = new Contestation(
            vm.envAddress("VRF_COORDINATOR"), vm.envUint("VRF_SUB_ID"), vm.envBytes32("VRF_KEY_HASH"),
            IPCT(address(token)), ISBT(address(sbt)), daoSafe
        );

        // 6. Rôles opérationnels
        sbt.grantRole(sbt.CONTEST_ROLE(), address(contestation));
        sbt.grantRole(sbt.CERTIFIER_ROLE(), deployer); // temporaire : cohorte genèse
        token.grantRole(token.TRANSFER_ROLE(), address(vesting));
        token.grantRole(token.TRANSFER_ROLE(), address(contestation));
        token.grantRole(token.TRANSFER_ROLE(), daoSafe);
        token.grantRole(token.BURNER_ROLE(), address(contestation));
        token.grantRole(token.PAUSER_ROLE(), address(timelock));

        vm.stopBroadcast();

        console2.log("TIMELOCK", address(timelock));
        console2.log("VESTING", address(vesting));
        console2.log("TOKEN", address(token));
        console2.log("REGISTRY", address(registry));
        console2.log("SBT", address(sbt));
        console2.log("CONTESTATION", address(contestation));
        // Ensuite, à la main : ajouter Contestation comme consommateur de l'abonnement VRF.
    }
}

/// Étape 2, après la cohorte genèse : tout passe au Timelock, le déployeur n'a plus rien.
contract Handover is Script {
    function run() external {
        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(pk);
        TimelockController timelock = TimelockController(payable(vm.envAddress("TIMELOCK")));
        PasseportToken token = PasseportToken(vm.envAddress("TOKEN"));
        PasseportSBT sbt = PasseportSBT(vm.envAddress("SBT"));
        PassportRegistry registry = PassportRegistry(vm.envAddress("REGISTRY"));
        Contestation contestation = Contestation(vm.envAddress("CONTESTATION"));
        address certification = vm.envAddress("CERTIFICATION");
        bytes32 admin = 0x00; // DEFAULT_ADMIN_ROLE

        vm.startBroadcast(pk);

        sbt.grantRole(sbt.CERTIFIER_ROLE(), certification);
        sbt.renounceRole(sbt.CERTIFIER_ROLE(), deployer);

        token.grantRole(admin, address(timelock));
        sbt.grantRole(admin, address(timelock));
        registry.grantRole(admin, address(timelock));

        token.renounceRole(admin, deployer);
        sbt.renounceRole(admin, deployer);
        registry.renounceRole(admin, deployer);
        timelock.renounceRole(admin, deployer);

        // Propriété VRF en deux temps : le Timelock devra exécuter acceptOwnership() via un vote.
        contestation.transferOwnership(address(timelock));
        Contestation(certification).transferOwnership(address(timelock)); // même interface ConfirmedOwner

        vm.stopBroadcast();

        require(!token.hasRole(admin, deployer) && !sbt.hasRole(admin, deployer), "admin restant");
        require(!registry.hasRole(admin, deployer) && !timelock.hasRole(admin, deployer), "admin restant");
    }
}
