// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SimpleVaultFixed.sol";

/**
 * @title SimpleVaultFixedTest
 * @notice Same test structure as SimpleVaultTest — updated for SimpleVaultFixed.
 *
 * WHAT THESE TESTS COVER:
 *   ✅ Happy path deposit
 *   ✅ Happy path withdraw
 *   ✅ Overdraw protection
 *   ✅ Zero deposit / withdraw protection
 *   ✅ Multiple users
 *
 * NEW TESTS ADDED (killing the survivors slither-mutate found):
 *   ✅ totalDeposits asserted after every withdrawal
 *   ✅ Double deposit — accumulation not overwrite
 *   ✅ Transfer failure reverts
 *   ✅ Events verified with vm.expectEmit
 *   ✅ Force-send via selfdestruct does not break vault
 *   ✅ Invariant holds after every withdrawal
 */
contract SimpleVaultFixedTest is Test {
    SimpleVaultFixed vault;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        vault = new SimpleVaultFixed();
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    // ─────────────────────────────────────────────
    // Basic deposit tests
    // ─────────────────────────────────────────────

    function test_deposit_updatesBalance() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}();

        assertEq(vault.balances(alice), 1 ether);
        assertEq(vault.totalDeposits(), 1 ether);
    }

    function test_deposit_multipleUsers() public {
        vm.prank(alice);
        vault.deposit{value: 2 ether}();

        vm.prank(bob);
        vault.deposit{value: 3 ether}();

        assertEq(vault.totalDeposits(), 5 ether);
    }

    function test_cannotDepositZero() public {
        vm.prank(alice);
        vm.expectRevert("Zero deposit");
        vault.deposit{value: 0}();
    }

    // ─────────────────────────────────────────────
    // Basic withdraw tests
    // ─────────────────────────────────────────────

    function test_withdraw_updatesBalance() public {
        vm.prank(alice);
        vault.deposit{value: 2 ether}();

        vm.prank(alice);
        vault.withdraw(1 ether);

        assertEq(vault.balances(alice), 1 ether);
    }

    function test_cannotOverdraw() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}();

        vm.prank(alice);
        vm.expectRevert("Insufficient balance");
        vault.withdraw(2 ether);
    }

    function test_cannotWithdrawZero() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}();

        vm.prank(alice);
        vm.expectRevert("Zero amount");
        vault.withdraw(0);
    }

    function test_fullWithdraw() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}();

        vm.prank(alice);
        vault.withdraw(1 ether);

        assertEq(vault.balances(alice), 0);
        assertEq(vault.totalDeposits(), 0);
    }

    // ─────────────────────────────────────────────
    // New tests — killing the survivors
    // ─────────────────────────────────────────────

    /**
     * KILLS: ASOR/AOR — totalDeposits %= amount, ^=, <<=, >>= etc.
     *
     * Original tests never checked totalDeposits after a withdrawal.
     * Any wrong operator on that line produces a wrong value here.
     */
    function test_totalDepositsAfterWithdraw() public {
        vm.prank(alice);
        vault.deposit{value: 3 ether}();

        vm.prank(bob);
        vault.deposit{value: 2 ether}();

        assertEq(vault.totalDeposits(), 5 ether);

        vm.prank(alice);
        vault.withdraw(1 ether);

        assertEq(vault.totalDeposits(), 4 ether, "totalDeposits must decrease by exact amount");

        vm.prank(bob);
        vault.withdraw(2 ether);

        assertEq(vault.totalDeposits(), 2 ether, "totalDeposits must track all withdrawals");
    }

    /**
     * KILLS: ASOR — balances[msg.sender] = msg.value (assignment not accumulation)
     *
     * Original tests deposited only once per user.
     * If += becomes =, the second deposit overwrites the first.
     */
    function test_doubleDepositAccumulates() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}();

        vm.prank(alice);
        vault.deposit{value: 1 ether}();

        assertEq(vault.balances(alice), 2 ether, "Must accumulate, not overwrite");
        assertEq(vault.totalDeposits(), 2 ether, "totalDeposits must reflect both deposits");
    }

    /**
     * KILLS: CR — require(ok, "Transfer failed") commented out
     *
     * Deploys a contract that rejects ETH, deposits on its behalf,
     * then attempts a withdrawal. Without require(ok), the withdrawal
     * silently succeeds even though no ETH was actually sent.
     */
    function test_transferFailureReverts() public {
        RejectETH rejecter = new RejectETH();
        vm.deal(address(rejecter), 1 ether);

        vm.prank(address(rejecter));
        vault.deposit{value: 1 ether}();

        vm.prank(address(rejecter));
        vm.expectRevert("Transfer failed");
        vault.withdraw(1 ether);
    }

    /**
     * KILLS: CR — emit Deposited commented out
     *
     * Without vm.expectEmit, removing the emit is completely invisible.
     */
    function test_depositEmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit SimpleVaultFixed.Deposited(alice, 1 ether);

        vm.prank(alice);
        vault.deposit{value: 1 ether}();
    }

    /**
     * KILLS: CR — emit Withdrawn commented out
     */
    function test_withdrawEmitsEvent() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}();

        vm.expectEmit(true, false, false, true);
        emit SimpleVaultFixed.Withdrawn(alice, 1 ether);

        vm.prank(alice);
        vault.withdraw(1 ether);
    }

    /**
     * KILLS: force-send griefing vector
     *
     * Anyone can force-send ETH via selfdestruct — bypasses receive().
     * SimpleVaultFixed uses >= in the invariant so surplus is fine.
     * totalDeposits must be unchanged. Alice must still withdraw normally.
     */
    function test_forceSendDoesNotBreakVault() public {
        vm.prank(alice);
        vault.deposit{value: 2 ether}();

        // Force-send 1 ETH via selfdestruct
        ForceSender fs = new ForceSender();
        vm.deal(address(fs), 1 ether);
        fs.attack(payable(address(vault)));

        // totalDeposits must be unchanged — it is our source of truth
        assertEq(vault.totalDeposits(), 2 ether, "totalDeposits must not change from force-send");
        assertEq(address(vault).balance, 3 ether, "vault holds 1 ETH surplus");

        // Alice can still withdraw her 2 ether normally
        vm.prank(alice);
        vault.withdraw(2 ether);

        assertEq(vault.balances(alice), 0);
        assertEq(vault.totalDeposits(), 0);
    }

    /**
     * KILLS: structural bug — invariant checked before transfer
     *
     * In SimpleVault the check ran before the transfer — always passed trivially.
     * Here we verify the vault is solvent AFTER every withdrawal completes.
     */
    function test_invariantHoldsAfterWithdraw() public {
        vm.prank(alice);
        vault.deposit{value: 5 ether}();

        vm.prank(bob);
        vault.deposit{value: 3 ether}();

        vm.prank(alice);
        vault.withdraw(2 ether);

        assertGe(
            address(vault).balance,
            vault.totalDeposits(),
            "Vault must hold enough ETH to cover all deposits after withdrawal"
        );

        vm.prank(bob);
        vault.withdraw(3 ether);

        assertGe(
            address(vault).balance,
            vault.totalDeposits(),
            "Vault must hold enough ETH to cover all deposits after withdrawal"
        );
    }
}

// ─────────────────────────────────────────────
// Helper contracts
// ─────────────────────────────────────────────

/// @dev Rejects ETH — used to simulate a failed transfer
contract RejectETH {
    // No receive() — any ETH transfer to this contract will fail

    }

/// @dev Force-sends ETH via selfdestruct — bypasses receive()/fallback()
contract ForceSender {
    function attack(address payable target) external {
        selfdestruct(target);
    }
}
