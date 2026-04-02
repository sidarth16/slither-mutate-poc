// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SimpleVaultFixed
 * @notice The corrected vault — redesigned around a proper invariant.
 *
 * FIXES:
 *   1. Invariant check moved AFTER transfer — validates actual final state
 *   2. Uses assert() not require() — invariant violations are bugs, not user errors
 *   3. totalDeposits is the source of truth — NOT address(this).balance
 *   4. receive() added — force-sent ETH becomes acceptable surplus, not a brick
 */
contract SimpleVaultFixed {
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

        // CEI: update state first
        balances[msg.sender] -= amount;
        totalDeposits -= amount;

        // Transfer ETH
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "Transfer failed");

        // Post-condition: checked AFTER transfer — validates real final state
        // Uses >= intentionally — force-sent ETH is acceptable surplus
        // totalDeposits is our truth, NOT address(this).balance
        assert(address(this).balance >= totalDeposits);

        emit Withdrawn(msg.sender, amount);
    }

    // Accept force-sent ETH gracefully
    // It becomes surplus — vault stays functional because we never rely on ==
    receive() external payable {}
}
