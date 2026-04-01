// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SimpleVault.sol";

/**
 * @title SimpleVaultTest
 * @notice These tests all PASS. Coverage looks great. But slither-mutate will reveal the truth.
 *
 */
contract SimpleVaultTest is Test {
    SimpleVault vault;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        vault = new SimpleVault();
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
}