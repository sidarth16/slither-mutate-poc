// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SimpleVault
 * @notice A simple ETH vault — looks safe, passes all tests, but has a subtle invariant bug.
 */
contract SimpleVault {
    mapping(address => uint256) public balances;

    uint256 public totalDeposits;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    function deposit() external payable {
        require(msg.value > 0, "Zero deposit");

        balances[msg.sender] += msg.value;
        totalDeposits += msg.value;

        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Zero amount");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        // Update state BEFORE transfer (CEI pattern)
        balances[msg.sender] -= amount;
        totalDeposits -= amount;

        require(address(this).balance >= totalDeposits, "Invariant broken");

        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "Transfer failed");

        emit Withdrawn(msg.sender, amount);
    }
}
