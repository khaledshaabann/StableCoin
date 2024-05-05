// SPDX-License-Identifier MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {StableCoin} from "../src/StableCoin.sol";
import {SCEngine} from "../src/SCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeploySC is Script{

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns(StableCoin, SCEngine){
        HelperConfig config = new HelperConfig();
        (address wethUSDPriceFeed, address wbtcUSDPriceFeed, address weth, address wbtc, uint256 deployerKey) = config.activeNetworkConfig();
        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUSDPriceFeed, wbtcUSDPriceFeed];

        vm.startBroadcast(deployerKey);
        StableCoin sc = new StableCoin();
        SCEngine scEngine = new SCEngine(tokenAddresses, priceFeedAddresses, address(sc));

        sc.transferOwnership(address(scEngine));
        vm.stopBroadcast();
        return (sc, scEngine);

    }
}

