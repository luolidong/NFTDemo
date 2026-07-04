// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import "./TokenBank.sol";

contract TokenBankUpkeep is AutomationCompatibleInterface {
    TokenBank public tokenBank;

    constructor(address _tokenBankAddress) {
        require(_tokenBankAddress != address(0), "TokenBank address cannot be zero");
        tokenBank = TokenBank(_tokenBankAddress);
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        uint256 balance = tokenBank.getBalance();
        uint256 threshold = tokenBank.COLLECT_THRESHOLD();
        upkeepNeeded = balance >= threshold;
        performData = abi.encode(balance);
    }

    function performUpkeep(bytes calldata /* performData */) external {
        tokenBank.collect();
    }
}