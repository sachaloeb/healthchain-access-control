// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import "./DataSharing.sol";

/// @dev Very simple mock of ConsentManager so we can toggle "hasValidConsent"
contract MockConsentManager is IConsentManager {
    bool public allow;

    function setAllow(bool _allow) external {
        allow = _allow;
    }

    function hasValidConsent(
        address,
        address,
        uint256,
        uint256
    ) external view override returns (bool) {
        return allow;
    }
}

contract DataSharingTest is Test {
    DataSharing public dataSharing;
    MockConsentManager public mockConsent;

    address patient = address(0x1);
    address requester = address(0x2);

    // Local copy of events so we can use expectEmit
    event DataRecordRegistered(
        address indexed patient,
        uint256 indexed dataTypeId,
        bytes32 indexed recordHash,
        string storageURI,
        uint256 timestamp
    );

    event AccessGranted(
        address indexed patient,
        address indexed requester,
        uint256 indexed dataTypeId,
        string storageURI,
        uint256 timestamp
    );

    event AccessDenied(
        address indexed patient,
        address indexed requester,
        uint256 indexed dataTypeId,
        string reason,
        uint256 timestamp
    );

    function setUp() public {
        mockConsent = new MockConsentManager();
        dataSharing = new DataSharing(address(mockConsent));
    }

    function _registerOneRecord()
        internal
        returns (uint256 dataTypeId, bytes32 recordHash, string memory uri)
    {
        dataTypeId = 1;
        recordHash = keccak256(abi.encodePacked("record-1"));
        uri = "ipfs://example-hash";

        vm.prank(patient);
        dataSharing.registerDataRecord(patient, dataTypeId, recordHash, uri);
    }

    /// -----------------------------------------------------------------------
    /// registerDataRecord tests
    /// -----------------------------------------------------------------------

    function test_registerDataRecord_StoresRecordAndEmitsEvent() public {
        uint256 dataTypeId = 1;
        bytes32 recordHash = keccak256(abi.encodePacked("record-1"));
        string memory uri = "ipfs://example-hash";

        // Expect the event from DataSharing
        vm.expectEmit(true, true, true, true, address(dataSharing));
        emit DataRecordRegistered(
            patient,
            dataTypeId,
            recordHash,
            uri,
            block.timestamp
        );

        vm.prank(patient);
        dataSharing.registerDataRecord(patient, dataTypeId, recordHash, uri);

        // Check latest record matches what we stored
        DataSharing.DataRecord memory rec =
            dataSharing.getLatestRecord(patient, dataTypeId);

        assertEq(rec.recordHash, recordHash, "record hash mismatch");
        assertEq(rec.storageURI, uri, "storage URI mismatch");
        assertEq(rec.createdAt, block.timestamp, "timestamp mismatch");

        uint256 count = dataSharing.getRecordCount(patient, dataTypeId);
        assertEq(count, 1, "record count should be 1");
    }

    function test_registerDataRecord_RevertsIfCallerNotPatient() public {
        uint256 dataTypeId = 1;
        bytes32 recordHash = keccak256(abi.encodePacked("record-1"));
        string memory uri = "ipfs://example-hash";

        vm.prank(requester); // not the patient
        vm.expectRevert(bytes("Only patient can register"));
        dataSharing.registerDataRecord(patient, dataTypeId, recordHash, uri);
    }

    function test_getLatestRecord_RevertsIfNoRecords() public {
        vm.expectRevert(bytes("No records for this data type"));
        dataSharing.getLatestRecord(patient, 1);
    }

    /// -----------------------------------------------------------------------
    /// accessData tests (consent + audit logging)
    /// -----------------------------------------------------------------------

    function test_accessData_RevertsAndLogsDenied_WhenNoConsent() public {
        // First, store a record so data exists
        (uint256 dataTypeId,,) = _registerOneRecord();

        // Mock says "no consent"
        mockConsent.setAllow(false);

        vm.prank(requester);

        // Expect AccessDenied event
        vm.expectEmit(true, true, true, true, address(dataSharing));
        emit AccessDenied(
            patient,
            requester,
            dataTypeId,
            "No valid consent",
            block.timestamp
        );

        // And expect the call itself to revert
        vm.expectRevert(bytes("No valid consent"));
        dataSharing.accessData(patient, dataTypeId);
    }

    function test_accessData_ReturnsURIAndLogsGranted_WhenConsent() public {
        (uint256 dataTypeId,, string memory uri) = _registerOneRecord();

        // Mock says "consent is valid"
        mockConsent.setAllow(true);

        vm.prank(requester);

        // Expect AccessGranted event
        vm.expectEmit(true, true, true, true, address(dataSharing));
        emit AccessGranted(
            patient,
            requester,
            dataTypeId,
            uri,
            block.timestamp
        );

        string memory returnedUri = dataSharing.accessData(patient, dataTypeId);

        assertEq(returnedUri, uri, "returned URI must match stored URI");
    }
}
