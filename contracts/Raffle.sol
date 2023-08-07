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
error Raffle__NotEnoughETHEntered(); // Error msg is better than storing strings

contract Raffle is VRFConsumerBaseV2 {
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
    // Events of the Contract
    event raffleEnter(address indexed player); // indexed = event indexed is easier to query (less gas)

    constructor(
        address vrfCoordinatorAddress,
        uint256 entranceFee,
        bytes32 gasLane, // equal to keyHash
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinatorAddress) { // inherits the constructor since it inherits the functions of VRFConsumerBaseV2
        i_entranceFee = entranceFee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorAddress);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETHEntered();
        }
        s_players.push(payable(msg.sender));
        emit raffleEnter(msg.sender);
    }

    function requestRandomWinner() external {
        // External function less gas
        // Request random
        // Do something
        // 2 tx;
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
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {}

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }
}
