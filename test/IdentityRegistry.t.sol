// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import "../contracts/IdentityRegistry.sol";

contract IdentityRegistryTest is Test {
    IdentityRegistry internal registry;

    address internal patient   = address(0xB0B);
    address internal requester = address(0xC0C);

    function setUp() public {
        registry = new IdentityRegistry();
    }

    // ----------- Core behaviour tests -----------

    function test_registerUser_setsRoleOrgAndRegistered() public {
        uint256 orgHash = uint256(keccak256(abi.encodePacked("Hospital-A")));

        vm.prank(requester);
        registry.registerUser(IdentityRegistry.UserRole.Requester, orgHash);

        // mapping isRegistered is public
        bool isReg = registry.isRegistered(requester);
        assertTrue(isReg, "user should be marked registered");

        IdentityRegistry.UserRole role = registry.getUserRole(requester);
        assertEq(
            uint256(role),
            uint256(IdentityRegistry.UserRole.Requester),
            "role mismatch"
        );

        uint256 storedOrg = registry.getOrgHash(requester);
        assertEq(storedOrg, orgHash, "org hash mismatch");
    }

    function test_registerUser_patientCanRegisterWithZeroOrgHash() public {
        vm.prank(patient);
        registry.registerUser(IdentityRegistry.UserRole.Patient, 0);

        assertTrue(registry.isRegistered(patient), "patient should be registered");

        IdentityRegistry.UserRole role = registry.getUserRole(patient);
        assertEq(
            uint256(role),
            uint256(IdentityRegistry.UserRole.Patient),
            "patient role mismatch"
        );

        assertEq(registry.getOrgHash(patient), 0, "patient orgHash should be zero");
    }

    function test_registerUser_revertsOnInvalidRole() public {
        vm.prank(patient);
        vm.expectRevert(bytes("Invalid role"));
        registry.registerUser(IdentityRegistry.UserRole.None, 0);
    }

    function test_registerUser_revertsIfAlreadyRegistered() public {
        vm.prank(patient);
        registry.registerUser(IdentityRegistry.UserRole.Patient, 0);

        vm.prank(patient);
        vm.expectRevert(bytes("Already registered"));
        registry.registerUser(IdentityRegistry.UserRole.Patient, 0);
    }

    function test_unregisterUser_clearsRoleAndOrgHashAndFlag() public {
        vm.prank(patient);
        registry.registerUser(IdentityRegistry.UserRole.Patient, 0);

        vm.prank(patient);
        registry.unregisterUser();

        assertFalse(registry.isRegistered(patient), "should not be registered");

        IdentityRegistry.UserRole role = registry.getUserRole(patient);
        assertEq(
            uint256(role),
            uint256(IdentityRegistry.UserRole.None),
            "role should reset to None"
        );

        assertEq(registry.getOrgHash(patient), 0, "orgHash should reset to 0");
    }

    function test_unregisterUser_revertsIfNotRegistered() public {
        vm.prank(patient);
        vm.expectRevert(bytes("Not registered"));
        registry.unregisterUser();
    }

    function test_updateIdentity_storesHashedAttribute() public {
        vm.prank(patient);
        registry.registerUser(IdentityRegistry.UserRole.Patient, 0);

        uint256 keyHash = uint256(keccak256(abi.encodePacked("email")));
        uint256 valueHash = uint256(
            keccak256(abi.encodePacked("alice@example.org"))
        );

        vm.prank(patient);
        registry.updateIdentity(keyHash, valueHash);

        uint256 stored = registry.getHashedAttributes(patient, keyHash);
        assertEq(stored, valueHash, "attribute hash mismatch");
    }

    function test_updateIdentity_revertsIfNotRegistered() public {
        uint256 keyHash = uint256(keccak256(abi.encodePacked("email")));
        uint256 valueHash = uint256(
            keccak256(abi.encodePacked("alice@example.org"))
        );

        vm.prank(patient);
        vm.expectRevert(bytes("Not registered"));
        registry.updateIdentity(keyHash, valueHash);
    }

    // ----------- Gas measurement tests -----------

    function testGas_deploy_IdentityRegistry() public {
        uint256 gasBefore = gasleft();
        IdentityRegistry r = new IdentityRegistry();
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("GAS deploy IdentityRegistry:", gasUsed);
        assert(address(r) != address(0));
    }

    function testGas_registerUser_patient() public {
        uint256 gasBefore = gasleft();
        vm.prank(patient);
        registry.registerUser(IdentityRegistry.UserRole.Patient, 0);
        uint256 gasUsed = gasBefore - gasleft();

        console2.log(
            "GAS IdentityRegistry.registerUser (patient):",
            gasUsed
        );
    }

    function testGas_updateIdentity() public {
        vm.prank(patient);
        registry.registerUser(IdentityRegistry.UserRole.Patient, 0);

        uint256 keyHash = uint256(keccak256(abi.encodePacked("email")));
        uint256 valueHash = uint256(
            keccak256(abi.encodePacked("alice@example.org"))
        );

        uint256 gasBefore = gasleft();
        vm.prank(patient);
        registry.updateIdentity(keyHash, valueHash);
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("GAS IdentityRegistry.updateIdentity:", gasUsed);
    }
}