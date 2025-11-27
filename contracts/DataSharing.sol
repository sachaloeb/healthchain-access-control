// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal interface to interact with your ConsentManager contract
interface IConsentManager {
    function hasValidConsent(
        address patient,
        address requester,
        uint256 dataTypeId,
        uint256 atTime
    ) external view returns (bool);
}

/**
 * @title DataSharing
 * @notice Stores hashes + URIs for off-chain medical data and enforces access via ConsentManager.
 *
 * Design goals (from project spec):
 *  - Only hashes and references on-chain, never raw medical data.
 *  - Access is allowed only if ConsentManager reports valid consent.
 *  - Every access attempt (granted or denied) is logged as an event.
 */
contract DataSharing {
    /// @notice Single off-chain data record for a patient & data type
    struct DataRecord {
        bytes32 recordHash;   // Hash of the off-chain record
        string storageURI;    // Pointer (e.g., IPFS CID, HTTPS URL, etc.)
        uint256 createdAt;    // Timestamp when record was registered
    }

    /// @notice Consent manager used to verify access permissions
    IConsentManager public consentManager;

    /// @notice Simple owner pattern so you can update config if needed
    address public owner;

    /// @dev patient => dataTypeId => list of records
    mapping(address => mapping(uint256 => DataRecord[])) private records;

    /// @notice Emitted whenever a patient registers a new data record
    event DataRecordRegistered(
        address indexed patient,
        uint256 indexed dataTypeId,
        bytes32 indexed recordHash,
        string storageURI,
        uint256 timestamp
    );

    /// @notice Emitted when access is granted
    event AccessGranted(
        address indexed patient,
        address indexed requester,
        uint256 indexed dataTypeId,
        string storageURI,
        uint256 timestamp
    );

    /// @notice Emitted when access is denied
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

    /**
     * @notice Register a new off-chain data record.
     * @dev Patient-centric model: only the patient can register their own records.
     */
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

    /**
     * @notice View helper to get the latest record for a patient & data type.
     */
    function getLatestRecord(
        address patient,
        uint256 dataTypeId
    ) public view returns (DataRecord memory) {
        DataRecord[] storage list = records[patient][dataTypeId];
        require(list.length > 0, "No records for this data type");
        return list[list.length - 1];
    }

    /**
     * @notice Returns how many records exist for a patient & data type.
     */
    function getRecordCount(
        address patient,
        uint256 dataTypeId
    ) external view returns (uint256) {
        return records[patient][dataTypeId].length;
    }

    /**
     * @notice Request access to patient's latest record for a given data type.
     * @dev
     *  - Checks ConsentManager.hasValidConsent(patient, msg.sender, dataTypeId, now).
     *  - Emits AccessGranted or AccessDenied for the audit log.
     *  - Returns the storage URI on success (off-chain system uses it to fetch data).
     */
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

    /**
     * @notice Optional helper: update the ConsentManager address.
     *         Handy during development if you redeploy ConsentManager.
     */
    function setConsentManager(address _consentManager) external onlyOwner {
        require(_consentManager != address(0), "Invalid consent manager");
        consentManager = IConsentManager(_consentManager);
    }
}