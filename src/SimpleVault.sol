// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SimpleVault
 * @notice A simple ETH vault — looks safe, passes all tests, but has a subtle invariant bug.
 * @dev Deliberately vulnerable for educational/demo purposes (slither-mutate PoC)
 *
 * THE BUG:
 *   1. Invariant check uses address(this).balance — which can be manipulated
 *      via selfdestruct force-send, breaking the vault if == is used.
 *   2. Uses >= instead of strict equality — too loose, misses accounting drift.
 *   3. The real fix: never rely on address(this).balance; track ETH internally.
 */
contract SimpleVault {
    mapping(address => uint256) public balances;

    // ✅ FIXED: internal accounting — never relies on address(this).balance
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

        // THE SUBTLE BUG:
        // We check address(this).balance >= totalDeposits
        // Problem 1: >= is too loose — allows balance > totalDeposits (drift goes unnoticed)
        // Problem 2: address(this).balance can be force-inflated via selfdestruct
        //            If we used ==, a griefing attack bricks the vault permanently
        // Problem 3: Check is BEFORE the transfer — so it always passes anyway
        require(
            address(this).balance >= totalDeposits,
            "Invariant broken"
        );

        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "Transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    // No receive() or fallback() — but force-send via selfdestruct still works
    // That's exactly the griefing vector we discuss
}
