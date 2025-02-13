// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IRng } from "pt-v5-draw-manager/interfaces/IRng.sol";
import { DrawManager } from "pt-v5-draw-manager/DrawManager.sol";

/**
 * @title RngBlockhash
 * @notice A simple contract for generating random numbers using blockhashes
 * @dev This contract is intended to be used as a reference implementation for the IRng interface
 */
contract RngBlockhash is IRng {

  /**
   * @notice Emitted when a new request for a random number has been submitted
   * @param requestId The indexed ID of the request used to get the results of the RNG service
   * @param sender The indexed address of the sender of the request
   */
  event RandomNumberRequested(uint32 indexed requestId, address indexed sender);

  /**
   * @notice Emitted when an existing request for a random number has been completed
   * @param requestId The indexed ID of the request used to get the results of the RNG service
   * @param randomNumber The random number produced by the 3rd-party service
   */
  event RandomNumberCompleted(uint32 indexed requestId, uint256 randomNumber);


  /// @dev A counter for the number of requests made used for request ids
  uint32 internal requestCount;

  /// @dev A list of random numbers from past requests mapped by request id
  mapping(uint32 => uint256) internal randomNumbers;

  /// @dev A list of random number completion timestamps mapped by request id
  mapping(uint32 => uint64) internal requestCompletedAt;

  /// @dev A list of blocks to be locked at based on past requests mapped by request id
  mapping(uint32 => uint32) internal requestLockBlock;

  /// @notice Gets the last request id used by the RNG service
  /// @return requestId The last request id used in the last request
  function getLastRequestId() external view returns (uint32 requestId) {
    return requestCount;
  }

  /// @notice Sends a request for a random number to the 3rd-party service
  /// @dev Some services will complete the request immediately, others may have a time-delay
  /// @dev Some services require payment in the form of a token, such as $LINK for Chainlink VRF
  /// @return requestId The ID of the request used to get the results of the RNG service
  /// @return lockBlock The block number at which the RNG service will start generating time-delayed randomness.  The calling contract
  /// should "lock" all activity until the result is available via the `requestId`
  function requestRandomNumber()
    public
    payable
    virtual
    returns (uint32 requestId, uint32 lockBlock)
  {
    requestId = _getNextRequestId();
    lockBlock = uint32(block.number);

    requestLockBlock[requestId] = lockBlock;

    emit RandomNumberRequested(requestId, msg.sender);
  }

  /// @notice Checks if the request for randomness from the 3rd-party service has completed
  /// @dev For time-delayed requests, this function is used to check/confirm completion
  /// @param requestId The ID of the request used to get the results of the RNG service
  /// @return isCompleted True if the request has completed and a random number is available, false otherwise
  function isRequestComplete(uint32 requestId)
    external
    view
    virtual
    override
    returns (bool isCompleted)
  {
    return _isRequestComplete(requestId);
  }

  /// @inheritdoc IRng
  function isRequestFailed(uint32) external pure returns (bool) {
    return false;
  }

  /// @notice Gets the random number produced by the 3rd-party service
  /// @param requestId The ID of the request used to get the results of the RNG service
  /// @return randomNum The random number
  function randomNumber(uint32 requestId) external virtual override returns (uint256 randomNum) {
    require(_isRequestComplete(requestId), "RNGBlockhash/request-incomplete");

    if (randomNumbers[requestId] == 0) {
      _storeResult(requestId, _getSeed());
    }

    return randomNumbers[requestId];
  }

  function requestedAtBlock(uint32 rngRequestId) external virtual override returns (uint256) {
    return requestLockBlock[rngRequestId];
  }

  function startDraw(DrawManager _drawManager, address _rewardRecipient) external payable returns (uint24) {
      (uint32 requestId,) = requestRandomNumber();
      return _drawManager.startDraw(_rewardRecipient, requestId);
  }

  /// @dev Checks if the request for randomness from the 3rd-party service has completed
  /// @param requestId The ID of the request used to get the results of the RNG service
  /// @return True if the request has completed and a random number is available, false otherwise
  function _isRequestComplete(uint32 requestId) internal view returns (bool) {
    return block.number > (requestLockBlock[requestId] + 1);
  }

  /// @dev Gets the next consecutive request ID to be used
  /// @return requestId The ID to be used for the next request
  function _getNextRequestId() internal returns (uint32 requestId) {
    requestCount++;
    requestId = requestCount;
  }

  /// @dev Gets a seed for a random number from the latest available blockhash
  /// @return seed The seed to be used for generating a random number
  function _getSeed() internal view virtual returns (uint256 seed) {
    return uint256(blockhash(block.number - 1));
  }

  /// @dev Stores the latest random number by request ID and logs the event
  /// @param requestId The ID of the request to store the random number
  /// @param result The random number for the request ID
  function _storeResult(uint32 requestId, uint256 result) internal {
    // Store random value
    randomNumbers[requestId] = result;
    requestCompletedAt[requestId] = uint64(block.timestamp);

    emit RandomNumberCompleted(requestId, result);
  }
}
