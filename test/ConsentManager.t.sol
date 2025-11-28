// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/ConsentManager.sol";

contract CM_PatientConsentFlows is Test {
    ConsentManager private consentSystem;

    // Mocked actors from pretend hospital system
    address internal bobThePatient = address(0xaAa1);
    address internal drAlice = address(0xbBb2);
    address internal drMallory = address(0xbAdBabe); // Not authorized

    // Simulate various data types (some kind of hashed label)
    bytes32 internal patientXrayId = keccak256("xray_image:2023-09");
    bytes32 internal labResultId = keccak256("lab_result:CBC:2022");

    function setUp() public {
        consentSystem = new ConsentManager();
    }

    function test_basicConsentGrant_check_immediate() public {
        // Simulate patient Bob giving Dr. Alice access to X-ray for a second opinion
        vm.prank(bobThePatient);
        uint256 grantedId = consentSystem.grantConsent(
            drAlice,
            patientXrayId,
            uint64(block.timestamp + 3600), // expires in 1 hour
            "second opinion request"
        );

        // Validate the consent shows up as active and correctly linked
        (bool ok, uint256 returnedId) = consentSystem.isConsentValid(
            bobThePatient,
            drAlice,
            patientXrayId
        );

        assertTrue(ok, "Consent should be valid right after creation");
        assertEq(returnedId, grantedId, "Returned ID mismatch (grant -> query)");
    }

    function test_revoke_then_verify_revocation() public {
        // Bob grants access
        vm.prank(bobThePatient);
        uint256 cid = consentSystem.grantConsent(
            drAlice,
            labResultId,
            uint64(block.timestamp + 5000),
            "routine lab review"
        );

        // Now Bob changes his mind...
        vm.prank(bobThePatient);
        consentSystem.revokeConsent(cid);

        // Should now be invalid
        (bool stillOk, ) = consentSystem.isConsentValid(
            bobThePatient,
            drAlice,
            labResultId
        );
        assertFalse(stillOk, "Consent should be gone after revocation");
    }

    function test_invalidConsentAccessFromUnauthorizedRequester() public {
        // Consent is granted to Dr. Alice
        vm.prank(bobThePatient);
        consentSystem.grantConsent(drAlice, labResultId, 0, "emergency");

        // Dr. Mallory tries to sneak in
        (bool isValid, ) = consentSystem.isConsentValid(
            bobThePatient,
            drMallory,
            labResultId
        );
        assertFalse(isValid, "Consent should NOT be valid for unauthorized requester");
    }

    function test_expiredConsentShouldNotValidate() public {
        // Grant short-lived access (already expired)
        vm.warp(1000); // fake timestamp
        vm.prank(bobThePatient);
        consentSystem.grantConsent(drAlice, patientXrayId, 1020, "old session");

        // Move time forward beyond expiry
        vm.warp(2000);

        (bool isValid, ) = consentSystem.isConsentValid(bobThePatient, drAlice, patientXrayId);
        assertFalse(isValid, "Expired consent should not validate");
    }

    function test_duplicateConsentOverwritesNothing() public {
        // Grant two consents to same doctor for same data (unusual but possible)
        vm.prank(bobThePatient);
        uint256 first = consentSystem.grantConsent(drAlice, labResultId, 5000, "v1");

        vm.prank(bobThePatient);
        uint256 second = consentSystem.grantConsent(drAlice, labResultId, 7000, "updated");

        // System doesn't remove the old one, just adds another
        assertTrue(second > first, "Second consent should be a new ID");
    }
}