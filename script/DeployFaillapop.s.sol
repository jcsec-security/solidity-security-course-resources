// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {FP_CoolNFT} from "../src/FP_CoolNFT.sol";
import {FP_DAO} from "../src/FP_DAO.sol";
import {FP_PowersellerNFT} from "../src/FP_PowersellerNFT.sol";
import {FP_Shop} from "../src/FP_Shop.sol";
import {FP_Token} from "../src/FP_Token.sol";
import {FP_Vault} from "../src/FP_Vault.sol";
import {FP_Proxy} from "../src/FP_Proxy.sol";

contract DeployFaillapop is Script {

    function run() external returns(FP_Shop shop, FP_Token token, FP_CoolNFT coolNFT, FP_PowersellerNFT powersellerNFT, FP_DAO dao, FP_Vault vault, FP_Proxy proxy) {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        shop = new FP_Shop();
        token = new FP_Token();
        coolNFT = new FP_CoolNFT();
        powersellerNFT = new FP_PowersellerNFT();
        dao = new FP_DAO("password", address(coolNFT), address(token));
        vault = new FP_Vault(address(powersellerNFT), address(dao));
        proxy = new FP_Proxy(
            address(shop), 
            abi.encodeWithSignature(
                "initialize(address,address,address,address)",
                address(dao),
                address(vault), 
                address(powersellerNFT),
                address(coolNFT)
                ), 
            address(dao)
        );

        vault.setShop(address(proxy));
        dao.setShop(address(proxy));
        powersellerNFT.setShop(address(proxy));
        coolNFT.setShop(address(proxy));
        coolNFT.setDAO(address(dao));
        vm.stopBroadcast();
    }
}