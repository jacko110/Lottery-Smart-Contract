// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {Raffle} from " src/Raffle.sol";
import {CreateSubscription} from "interactions.s.sol";

contract DeployRaffle is Script {
    function run() public {
        deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        HelperConfig,NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId = 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId,config.vrfCoordinator) = createSubscription.createSubscription(config.vrfCoordinator);

            FundSubscription fundSubscription = new FudSubscription();
            fudSubscription.fundSubscription(config.vrfCoordinator, config.subscriptionId, config.link)
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();
        return (raffle, helperConfig);
    }

}