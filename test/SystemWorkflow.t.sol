// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import "../contracts/ConsentManager.sol";
import "../contracts/RewardToken.sol";
import "../contracts/DataSharing.sol";

contract SystemWorkflowTest is Test {
    RewardToken internal reward;
    ConsentManager internal consent;
    DataSharing internal dataSharing;

    address internal admin     = address(0xA11CE);
    address internal patient   = address(0xB0B);
    address internal requester = address(0xC0C);

    function setUp() public {
        // Deploy RewardToken and ConsentManager as admin
        vm.prank(admin);
        reward = new RewardToken();

        vm.prank(admin);
        consent = new ConsentManager();

        // Wire RewardToken <-> ConsentManager
        vm.prank(admin);
        reward.setConsentManager(address(consent));

        vm.prank(admin);
        consent.setRewardToken(address(reward));

        // Deploy DataSharing pointing at real ConsentManager
        vm.prank(admin);
        dataSharing = new DataSharing(address(consent));
    }

    /// @notice End-to-end flow: register → grant → access → revoke → denied
    function test_fullPatientWorkflow() public {
        uint256 dataTypeId = 1;
        bytes32 recordHash = keccak256(abi.encodePacked("integration-record"));
        string memory uri = "ipfs://integration-record";

        // 1. Patient registers data record in DataSharing
        vm.prank(patient);
        dataSharing.registerDataRecord(patient, dataTypeId, recordHash, uri);

        // 2. Patient grants consent to requester in ConsentManager
        uint64 expiresAt = uint64(block.timestamp + 7 days);
        vm.prank(patient);
        uint256 consentId = consent.grantConsent(
            requester,
            bytes32(dataTypeId),
            expiresAt,
            "integration test"
        );

        // 3. Patient should receive reward tokens for consenting
        uint256 rewardBalance = reward.balanceOf(patient);
        assertGt(rewardBalance, 0, "Patient should receive reward tokens");

        // 4. Requester accesses data successfully via DataSharing
        vm.prank(requester);
        string memory returnedUri = dataSharing.accessData(patient, dataTypeId);
        assertEq(returnedUri, uri, "Returned URI should match stored record");

        // 5. Patient revokes consent
        vm.prank(patient);
        consent.revokeConsent(consentId);

        // 6. Further access attempts must revert with "No valid consent"
        vm.prank(requester);
        vm.expectRevert(bytes("No valid consent"));
        dataSharing.accessData(patient, dataTypeId);
    }
}