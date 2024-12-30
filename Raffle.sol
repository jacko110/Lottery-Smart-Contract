//SPDX-License-Identifier:MIT
pragma solidity ^0.8.26;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts@1.2.0/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

contract Raffle is VRFConsumerBaseV2Plus {
    error SendMoreToEnterRaffle();
    error Raffle__RaffleNotOpen();
    error Raffle__TransferFailed();
    error Raffle_UpKeepNotNeeded(uint256 balance,uint256 playersLength,uint356 raffleState);
    /*Type Declarations */
    enum RaffleState {
        OPEN, // 0
        CALCULATING // 1
    }
    
    /*State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint16 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    uint256 private s_lastTimeStamp;
    RaffleState private s_raffeleState;

    address payable[] private s_players;
    

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    constructor (uint256 entranceFee, uint256 interval, address vrfCoordinator,bytes32 gasLane,uint256 subscriptionId,uint32 callbackGasLimit) VRFConsumerBaseV2Plus(){
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscriptionI = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffeleState = RaffleState.OPEN;/*RaffleState(0)*/
    }

    function enterRaffle() external payable{
        // require(msg.value >= i_entranceFee,"Not enough ETh sent!");
        // require(msg.value >= i_entranceFee,"Not enough ETh sent!");
        if (msg.value < i_entranceFee){
            revert SendMoreToEnterRaffle();
        }
        if (s_raffleState != RaffleState.OPEN){
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));

        emit RaffleEntered(msg.sender);
    }

    function checkUpkeep(bytes memory/* checkData */) public view returns (bool upkeepNeeded, bytes memory /* performData */){
        bool timeHasPassed = ((block.timestamp -s_lastTimeStamp) >= i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && ipOpen && hasBalance && hasPlayers;
        return (upkeepNeeded,"");
    }

    function performUpkeep(bytes calldata /* performData */) external {

        (bool upKeepNeeded,)= checkUpkeep("");
        if(!upkeepNeeded){
            revert Raffel__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        s_raffeleState = RaffleState.CALCULATING;
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest(
            {
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
            )
        }
        );

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);

    }

    function fulfillRandomWords(uint256 requestId,uint256[] calldata randomWords) internal override{
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffeleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if(!success){
            revert Raffle__TransferFailed();
        }

        emit WinnerPicked(s_recentWinner);
    }

    /**
     * Getter Functions
     */
    function getEntranceFee() external view returns (uint256){
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState){
        return s_raffeleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address){
        return s_players[indexOfPlayer];
    }
}