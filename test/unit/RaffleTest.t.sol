// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Raffle} from "Raffle.sol";
import {Vm} from "forge-std/Vm.sol";

contract RaffleTest is Test {
    Raffel public raffle;
    HelperConfig public helperconfig;
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployRaffel();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;

        vm.deal(PLAYER,STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.Open);
    }

    //////////Enter Raffle

    function testRaffleRevertsWhenYouDontPayEnough() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        // Assert
        raffle.enterRaffle{value:entranceFee}();
    }
    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        vm.warp (block.timestamp + interval + 1);
        vm .roll (block.number + 1);
        raffle/performUpkeep("");

        vm.expectRevert(Raffel.Raffel_RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCheckUpkeepReturnFalseIfItHasNoBalance() public {
        vm.warp (block.timestamp + interval + 1);
        vm.roll (block.number + 1);

        //Act
        (bool upkeepNeeded,) = raffle.checkUpKeep("");

        //Assert

        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");

        //Act
        (bool upkeepNeeded,) = raffle.checkUpKeep("");

        //Assert
        assert(!upkeepNeeded);
    }

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number + 1);
        //Act / Assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee;
        numPlayers = 1;

        //Act

        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffel__UpkeepNotNeeded.selector, currentBalance,
            numPlayers, rState)
        );
        raffle.performUpkeep("");
    }

    modifier raffleEntered(){
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered {
        //Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        //Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }

    function testFulfillrandomWordCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public raffleEntered{
        vm.expectRevert(VRFConsumerBaseV2_5Mock.InvalidRequest.selector);
        VRFConsumerBaseV2_5Mock(vrfCoorfinator).fulfillRandomWords(randomRequestId,address(raffle));
    }

    function testFulfillrandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEntered{
        uint256 additionalEntrants = 3;
        uint256 startingIndex = 1;

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++){
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether);
            raffle.enterRaffle{value: entranceFee}();

            uint256 startingTimeStamp = raffle.getLastTimeStamp();

            vm.recordLogs();
            raffle.performUpkeep("");
            Vm.Log[] memory entries = vm.getRecordedLogs();
            bytes32 requestId = entries[1].topics[1];
            vrfCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId),address(raffle));

            address recentWinner = raffle.getRecentWinner();
            Raffle.RaffleState raffleState = raffle.getRaffleState();
            uint256 winnerBalance = recentWinner.balance;
            uint256 endingTimeStamp = raffle.getLastTimeStamp();
            uint256 prize = entranceFee * (additionalEntrants + 1);

            assert(recentWinner == expectedWinner);
            assert(uint256(raffleState) == 0);
            assert(winnerBalance == winnerStartingBalance + prize);
            assert(endingTimeStamp > startingTimeStamp);
        }
        
    }
}