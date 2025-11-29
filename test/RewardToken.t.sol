// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/RewardToken.sol";

contract RewardTokenTest is Test {
    RewardToken private reward;

    address internal admin = address(0xA11CE);
    address internal consentMod = address(0xC011ab1e);
    address internal bob = address(0xB0B);
    address internal alice = address(0xD0C7);
    address internal outsider = address(0xBAD);

    function setUp() public {
        vm.prank(admin);
        reward = new RewardToken();

        vm.prank(admin);
        reward.setConsentManager(consentMod);
    }

    function testOwnerIsDeployer() public {
        assertEq(reward.owner(), admin, "wrong owner");
    }

    function testSetConsentManagerOnlyOwner() public {
        address newMod = address(0xF00D);

        vm.prank(outsider);
        vm.expectRevert(bytes("Not owner"));
        reward.setConsentManager(newMod);

        vm.prank(admin);
        reward.setConsentManager(newMod);

        assertEq(reward.consentManager(), newMod, "manager not updated");
    }

    function testRewardMintedOnConsent() public {
        uint256 beforeSupply = reward.totalSupply();

        vm.prank(consentMod);
        reward.rewardForConsent(bob, 5e18);

        uint256 bal = reward.balanceOf(bob);
        uint256 afterSupply = reward.totalSupply();

        assertEq(bal, 5e18, "balance mismatch");
        assertEq(afterSupply, beforeSupply + 5e18, "supply mismatch");
        assertEq(reward.totalRewarded(bob), 5e18, "totalRewarded mismatch");
    }

    function testOnlyConsentManagerCanReward() public {
        vm.prank(outsider);
        vm.expectRevert(bytes("Not consent manager"));
        reward.rewardForConsent(bob, 1e18);
    }

    function testRewardCapIsRespected() public {
        uint256 cap = reward.maxRewardSupply();

        vm.prank(consentMod);
        reward.rewardForConsent(bob, cap - 1e18);

        vm.prank(consentMod);
        vm.expectRevert(bytes("Cap exceeded"));
        reward.rewardForConsent(bob, 2e18);
    }

    function testTransferMovesTokens() public {
        vm.prank(consentMod);
        reward.rewardForConsent(bob, 10e18);

        vm.prank(bob);
        reward.transfer(alice, 4e18);

        uint256 bobBal = reward.balanceOf(bob);
        uint256 aliceBal = reward.balanceOf(alice);

        assertEq(bobBal, 6e18, "bob balance");
        assertEq(aliceBal, 4e18, "alice balance");
    }

    function testTransferFromUsesAllowance() public {
        vm.prank(consentMod);
        reward.rewardForConsent(bob, 8e18);

        vm.prank(bob);
        reward.approve(alice, 5e18);

        vm.prank(alice);
        reward.transferFrom(bob, outsider, 5e18);

        uint256 bobBal = reward.balanceOf(bob);
        uint256 outBal = reward.balanceOf(outsider);
        uint256 remaining = reward.allowance(bob, alice);

        assertEq(bobBal, 3e18, "bob after transferFrom");
        assertEq(outBal, 5e18, "receiver after transferFrom");
        assertEq(remaining, 0, "allowance not reduced");
    }

    function testTransferFromFailsOnLowAllowance() public {
        vm.prank(consentMod);
        reward.rewardForConsent(bob, 4e18);

        vm.prank(bob);
        reward.approve(alice, 1e18);

        vm.prank(alice);
        vm.expectRevert(bytes("Allowance too low"));
        reward.transferFrom(bob, outsider, 2e18);
    }
}
