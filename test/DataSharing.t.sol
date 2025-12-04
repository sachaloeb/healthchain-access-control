// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import "../contracts/DataSharing.sol";


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


    function test_registerDataRecord_StoresRecordAndEmitsEvent() public {
        uint256 dataTypeId = 1;
        bytes32 recordHash = keccak256(abi.encodePacked("record-1"));
        string memory uri = "ipfs://example-hash";


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


    function test_accessData_RevertsAndLogsDenied_WhenNoConsent() public {
        (uint256 dataTypeId,,) = _registerOneRecord();

        // mock consent as "denied"
        mockConsent.setAllow(false);

        vm.prank(requester);

        vm.expectEmit(true, true, true, true, address(dataSharing));
        emit AccessDenied(
            patient,
            requester,
            dataTypeId,
            "No valid consent",
            block.timestamp
        );

        vm.expectRevert(bytes("No valid consent"));
        dataSharing.accessData(patient, dataTypeId);
    }

    function test_accessData_ReturnsURIAndLogsGranted_WhenConsent() public {
        (uint256 dataTypeId,, string memory uri) = _registerOneRecord();

        mockConsent.setAllow(true);

        vm.prank(requester);

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

    function testGas_deploy_DataSharing() public {
        uint256 gasBefore = gasleft();
        DataSharing ds = new DataSharing(address(mockConsent));
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("GAS deploy DataSharing:", gasUsed);
        // prevent optimizations from removing ds
        assert(address(ds) != address(0));
    }

    function testGas_registerDataRecord() public {
        uint256 dataTypeId = 1;
        bytes32 recordHash = keccak256(abi.encodePacked("gas-record"));
        string memory uri = "ipfs://gas-record";

        uint256 gasBefore = gasleft();
        vm.prank(patient);
        dataSharing.registerDataRecord(patient, dataTypeId, recordHash, uri);
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("GAS DataSharing.registerDataRecord:", gasUsed);
    }

    function testGas_accessData_withConsent() public {
        // store one record
        (uint256 dataTypeId,, string memory uri) = _registerOneRecord();

        // mock consent as "allowed"
        mockConsent.setAllow(true);

        uint256 gasBefore = gasleft();
        vm.prank(requester);
        string memory returnedUri = dataSharing.accessData(patient, dataTypeId);
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("GAS DataSharing.accessData (with consent):", gasUsed);
        assertEq(returnedUri, uri);
    }

    function testGas_accessData_withoutConsent() public {
        (uint256 dataTypeId,,) = _registerOneRecord();

        mockConsent.setAllow(false);

        uint256 gasBefore = gasleft();
        vm.prank(requester);
        vm.expectRevert(bytes("No valid consent"));
        dataSharing.accessData(patient, dataTypeId);
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("GAS DataSharing.accessData (no consent, revert):", gasUsed);
    }
}
