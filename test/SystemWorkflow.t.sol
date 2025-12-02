// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import "../contracts/IdentityRegistry.sol";
import "../contracts/ConsentManager.sol";
import "../contracts/RewardToken.sol";
import "../contracts/DataSharing.sol";

contract SystemWorkflowTest is Test {
    IdentityRegistry internal identities;
    RewardToken internal reward;
    ConsentManager internal consent;
    DataSharing internal dataSharing;

    address internal admin     = address(0xA11CE);
    address internal patient   = address(0xB0B);
    address internal requester = address(0xC0C);

    function setUp() public {
        // 1) Deploy identity registry
        identities = new IdentityRegistry();

        // 2) Register patient and requester identities
        vm.prank(patient);
        identities.registerUser(IdentityRegistry.UserRole.Patient, 0);

        uint256 orgHash = uint256(keccak256(abi.encodePacked("Hospital-A")));
        vm.prank(requester);
        identities.registerUser(IdentityRegistry.UserRole.Requester, orgHash);

        // 3) Deploy RewardToken and ConsentManager with admin as owner
        vm.prank(admin);
        reward = new RewardToken();

        vm.prank(admin);
        consent = new ConsentManager();

        // Wire reward <-> consent
        vm.prank(admin);
        reward.setConsentManager(address(consent));

        vm.prank(admin);
        consent.setRewardToken(address(reward));

        // 4) Deploy DataSharing, pointing at ConsentManager
        vm.prank(admin);
        dataSharing = new DataSharing(address(consent));
    }

    // Full workflow with manual revoke.
    //         register identity -> register data -> grant consent -> access -> revoke -> access denied
    function test_fullWorkflow_manualRevoke() public {
        uint256 dataTypeId = 1;
        bytes32 recordHash = keccak256(abi.encodePacked("integration-record"));
        string memory uri = "ipfs://integration-record";

        // Sanity check: identities are set correctly
        assertEq(
            uint256(identities.getUserRole(patient)),
            uint256(IdentityRegistry.UserRole.Patient),
            "patient role mismatch"
        );
        assertEq(
            uint256(identities.getUserRole(requester)),
            uint256(IdentityRegistry.UserRole.Requester),
            "requester role mismatch"
        );

        // 1. Patient registers data record in DataSharing
        vm.prank(patient);
        dataSharing.registerDataRecord(patient, dataTypeId, recordHash, uri);

        // 2. Patient grants consent to requester
        uint64 expiresAt = uint64(block.timestamp + 7 days);
        vm.prank(patient);
        uint256 consentId = consent.grantConsent(
            requester,
            bytes32(dataTypeId),
            expiresAt,
            "integration test"
        );

        // 3. Patient receives reward tokens
        uint256 rewardBalance = reward.balanceOf(patient);
        assertGt(rewardBalance, 0, "patient should receive reward tokens");

        // 4. Requester accesses data successfully
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

    // Full workflow where consent expires automatically (no manual revoke).
    //         register identity -> register data -> grant consent (short) -> access OK -> time passes -> access denied
    function test_fullWorkflow_withExpiry() public {
        uint256 dataTypeId = 2;
        bytes32 recordHash = keccak256(abi.encodePacked("expiring-record"));
        string memory uri = "ipfs://expiring-record";

        // 1. Patient registers data record
        vm.prank(patient);
        dataSharing.registerDataRecord(patient, dataTypeId, recordHash, uri);

        // 2. Patient grants short-lived consent (e.g., 1 day)
        uint64 expiresAt = uint64(block.timestamp + 1 days);
        vm.prank(patient);
        uint256 consentId = consent.grantConsent(
            requester,
            bytes32(dataTypeId),
            expiresAt,
            "short-lived access"
        );

        // 3. Immediately after grant, access should succeed
        vm.prank(requester);
        string memory firstUri = dataSharing.accessData(patient, dataTypeId);
        assertEq(firstUri, uri, "Initial access should succeed before expiry");

        // 4. Warp time beyond expiry
        vm.warp(block.timestamp + 2 days);

        // ConsentManager.isConsentValid should now report false
        (bool stillValid, ) = consent.isConsentValid(
            patient,
            requester,
            bytes32(dataTypeId)
        );
        assertFalse(stillValid, "Consent should be treated as expired");

        // 5. DataSharing must now deny access due to expiry (no manual revoke)
        vm.prank(requester);
        vm.expectRevert(bytes("No valid consent"));
        dataSharing.accessData(patient, dataTypeId);

        // Just log the consentId for reference (no assertion needed)
        console2.log("Expiry test consentId:", consentId);

    }

    // Test scenario where requester attempts access without patient consent.
    //         register identity → register data → access denied (no consent granted)
    function test_accessDenied_noConsent() public {
        uint256 dataTypeId = 3;
        bytes32 recordHash = keccak256(abi.encodePacked("no-consent-record"));
        string memory uri = "ipfs://no-consent-record";

        // 1. Patient registers data record
        vm.prank(patient);
        dataSharing.registerDataRecord(patient, dataTypeId, recordHash, uri);

        // 2. Verify no consent exists
        (bool hasConsent, ) = consent.isConsentValid(
            patient,
            requester,
            bytes32(dataTypeId)
        );
        assertFalse(hasConsent, "No consent should exist");

        // 3. Requester attempts to access data without consent - should revert
        vm.prank(requester);
        vm.expectRevert(bytes("No valid consent"));
        dataSharing.accessData(patient, dataTypeId);

        // 4. Verify patient has no reward tokens (no consent was granted)
        uint256 rewardBalance = reward.balanceOf(patient);
        assertEq(rewardBalance, 0, "Patient should not receive rewards without granting consent");
    }

}