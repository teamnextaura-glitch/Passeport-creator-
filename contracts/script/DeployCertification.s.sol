// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PasseportToken} from "../src/PasseportToken.sol";
import {PasseportSBT} from "../src/PasseportSBT.sol";
import {Certification, ICertToken, ICertSBT} from "../src/Certification.sol";

/// À lancer après Deploy et avant Handover : le déployeur est encore admin.
contract DeployCertification is Script {
    function run() external {
        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        PasseportToken token = PasseportToken(vm.envAddress("TOKEN"));
        PasseportSBT sbt = PasseportSBT(vm.envAddress("SBT"));

        vm.startBroadcast(pk);
        Certification cert = new Certification(
            vm.envAddress("VRF_COORDINATOR"), vm.envUint("VRF_SUB_ID"), vm.envBytes32("VRF_KEY_HASH"),
            ICertToken(address(token)), ICertSBT(address(sbt)), vm.envAddress("DAO_SAFE")
        );
        token.grantRole(token.TRANSFER_ROLE(), address(cert));
        token.grantRole(token.BURNER_ROLE(), address(cert));
        // CERTIFIER_ROLE est accordé par Handover, quand le déployeur y renonce.
        vm.stopBroadcast();

        console2.log("CERTIFICATION", address(cert));
        // Ensuite : ajouter ce contrat comme consommateur VRF, puis le Safe DAO appelle fund().
    }
}
