// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;


interface IConsentManager {
    function hasValidConsent(
        address patient,
        address requester,
        uint256 dataTypeId,
        uint256 atTime
    ) external view returns (bool);
}


contract DataSharing {
    struct DataRecord {
        bytes32 recordHash;
        string storageURI;
        uint256 createdAt;
    }


    IConsentManager public consentManager;


    address public owner;


    mapping(address => mapping(uint256 => DataRecord[])) private records;


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

    modifier onlyOwner() {
        require(msg.sender == owner, "Not contract owner");
        _;
    }

    constructor(address _consentManager) {
        require(_consentManager != address(0), "Invalid consent manager");
        consentManager = IConsentManager(_consentManager);
        owner = msg.sender;
    }



    function registerDataRecord(
        address patient,
        uint256 dataTypeId,
        bytes32 recordHash,
        string calldata storageURI
    ) external {
        require(msg.sender == patient, "Only patient can register");
        require(dataTypeId != 0, "Invalid dataTypeId");
        require(recordHash != bytes32(0), "Empty record hash");
        require(bytes(storageURI).length > 0, "Empty storage URI");

        DataRecord memory rec = DataRecord({
            recordHash: recordHash,
            storageURI: storageURI,
            createdAt: block.timestamp
        });

        records[patient][dataTypeId].push(rec);

        emit DataRecordRegistered(
            patient,
            dataTypeId,
            recordHash,
            storageURI,
            block.timestamp
        );
    }


    function getLatestRecord(
        address patient,
        uint256 dataTypeId
    ) public view returns (DataRecord memory) {
        DataRecord[] storage list = records[patient][dataTypeId];
        require(list.length > 0, "No records for this data type");
        return list[list.length - 1];
    }


    function getRecordCount(
        address patient,
        uint256 dataTypeId
    ) external view returns (uint256) {
        return records[patient][dataTypeId].length;
    }


    function accessData(
        address patient,
        uint256 dataTypeId
    ) external returns (string memory storageURI) {
        bool ok = consentManager.hasValidConsent(
            patient,
            msg.sender,
            dataTypeId,
            block.timestamp
        );

        if (!ok) {
            emit AccessDenied(
                patient,
                msg.sender,
                dataTypeId,
                "No valid consent",
                block.timestamp
            );
            revert("No valid consent");
        }

        DataRecord memory latest = getLatestRecord(patient, dataTypeId);

        emit AccessGranted(
            patient,
            msg.sender,
            dataTypeId,
            latest.storageURI,
            block.timestamp
        );

        return latest.storageURI;
    }


    function setConsentManager(address _consentManager) external onlyOwner {
        require(_consentManager != address(0), "Invalid consent manager");
        consentManager = IConsentManager(_consentManager);
    }
}