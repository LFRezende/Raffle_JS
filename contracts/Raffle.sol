// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

// npm install hardhat-compile / yarn global add --dev hardhat-compile
// it allows for npx hh compile (windows) and hh compile (macOs, Linux).

// Remember to yarn add --dev @chainlink/contracts for it to be recognized
// If yarn doesn't work: npm install @chainlink/contracts!

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

// To interact with the contract of the VRFCooordinator, we must grab its interface, so we can
// pass to it the address of the contract we wish to access/work with, and then we wrap it into a
// variable.
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

// Now, let's import the interface for Keepers, which will allow us to interact
// with checkUpkeep and performUpkeep
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

error Raffle__NotEnoughETHEntered(); // Error msg is better than storing strings
error Raffle__TransferFailed();
error Raffle__NotOpen();
error Raffle__UpkeepNotNeeded(
    uint256 currentBalance,
    uint256 numPlayers,
    uint256 raffleState
);

abstract contract Raffle is VRFConsumerBaseV2, KeeperCompatibleInterface {
    // ENUMS

    enum raffleState {
        OPEN,
        CALCULATING
    }
    // Global Variables

    address payable[] private s_players;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator; // private because it doesn't matter
    uint256 private immutable i_entranceFee; // Won't be changed afterwards -  immutable (saves Gas)
    bytes32 private immutable i_gasLane; // Or keyhash - the most u r willing to pay for randomNumber.
    uint64 private immutable i_subscriptionId; // Account on Chainlink VRF
    uint32 private immutable i_callbackGasLimit; // Max gas we'll afford on the fulfillRandomness function.
    // Also, it is uint32 just to match the requestRandomness input requirements of the VRFConsumerBaseV2.
    /*
        requestRandomness function requires uint32 due to  VRFConsumerBaseV2
     */
    uint16 private constant REQUEST_CONFIRMATIONS = 3; // Ammount of blockConfirmations ur willing to wait.
    uint32 private constant NUM_WORDS = 1; // Number of randomnumbers we wish to call.
    // Lottery Variables
    address private s_recentWinner;
    raffleState private s_raffleState;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;
    // Events of the Contract
    event raffleEnter(address indexed player); // indexed = event indexed is easier to query (less gas)
    event requestedRaffleWinner(uint256 indexed requestId);
    event winnerPicked(address indexed winner);

    constructor(
        address vrfCoordinatorAddress,
        uint256 entranceFee,
        bytes32 gasLane, // equal to keyHash
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        uint256 interval
    ) VRFConsumerBaseV2(vrfCoordinatorAddress) {
        // inherits the constructor since it inherits the functions of VRFConsumerBaseV2
        i_entranceFee = entranceFee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorAddress);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = raffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_interval = interval;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETHEntered();
        }
        if (s_raffleState != raffleState.OPEN) {
            revert Raffle__NotOpen();
        }
        s_players.push(payable(msg.sender));
        emit raffleEnter(msg.sender);
    }

    /**@dev
     * This function was the original requestRandomWinner, but reworked from
     * Chainlink Keepers -> IT will request the randomWinner, therefore, IT will run all
     * of these.
     */
    function performUpkeep(bytes calldata /* performData*/) external override {
        // External function less gas
        // Request random
        // Do something
        // 2 tx;
        (bool upkeepNeeded, ) = checkUpkeep("");
        s_raffleState = raffleState.CALCULATING;
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        i_vrfCoordinator.requestRandomWords(
            i_gasLane, // maximum amount of gas we are willing to pay for the random number
            i_subscriptionId, // your subscription ID, on chainlink VRF, to fund ans request
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
    }

    // Function that the VRFCNode will call, and needs to be overridden;
    // it needs 2 parameters as an input (requestId and the randomNumbers, returned in array).
    function fulfillRandomWords(
        uint256 /* In sol, you can just pass the type for not using it */,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = raffleState.OPEN;
        // Reseting the list of players
        s_players = new address payable[](0); // reset the players after the end of raffle
        s_lastTimeStamp = block.timestamp; // Reset the timestamp
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
        emit winnerPicked(recentWinner);
    }

    /**
     * @dev Function for CHainlink Keepers Node call.
     * 1. Time must pass the deadline
     * 2. At least 1 player and with some ETH
     * 3. Subscriptio with LINK
     * 4. Must be open
     */

    // Alteramos para memory pois mais pra frente passamos um "" como bytes
    function checkUpkeep(
        bytes memory /*checkData*/ // set to public because our own contract will also call it
    )
        public
        override
        returns (bool upkeepNeeded, bytes memory /*performData*/)
    {
        bool isOpen = (raffleState.OPEN == s_raffleState);
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = (s_players.length > 0);
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
    }

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getRaffleState() public view returns (raffleState) {
        return s_raffleState;
    }

    // Super interesting! Restrict it to pure! It's not reading from the chain. It's reading from the contract!
    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getLatestTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }
}
