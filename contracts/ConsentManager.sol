// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Minimal interface to talk to RewardToken
interface IRewardToken {
    function rewardForConsent(address user, uint256 amount) external;
}


// Handles patient-to-requester consents for accessing specific data
contract ConsentManager {
    enum ConsentStatus {
        None,
        Active,
        Revoked
    }

    struct Consent {
        address subject; // Owner of the data
        address requester; // Who's trying to access (doctor, researcher, blabla)
        bytes32 dataId; // What data is trying to be accessed
        uint64 createdAt; // When was this consent granted
        uint64 expiresAt; // When it expires (0 = doesn't expire)
        ConsentStatus status; 
        string purpose; // for UI (not implemented)
    }

    // reward token wiring

    // owner can configure reward token address
    address public owner;
    IRewardToken public rewardToken;

    // how many tokens a patient gets per granted consent
    uint256 public constant REWARD_PER_CONSENT = 10 * 1e18;

    // Incremented with each new consent
    uint256 public nextConsentId;

    mapping(uint256 => Consent) public consents;
    mapping(address => uint256[]) public consentsBySubject;
    mapping(address => uint256[]) public consentsByRequester;

    event ConsentGranted(
        uint256 indexed consentId,
        address indexed subject,
        address indexed requester,
        bytes32 dataId,
        uint64 expiresAt,
        string purpose
    );

    event ConsentRevoked(
        uint256 indexed consentId,
        address indexed subject
    );

    event AccessLogged(
        uint256 indexed consentId,
        address indexed subject,
        address indexed requester,
        bytes32 dataId,
        uint64 timestamp
    );

    event RewardTokenAddressSet(address indexed token);

    modifier onlySubject(uint256 consentId) {
        require(consents[consentId].subject == msg.sender, "Not consent subject");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // set the reward token contract used to mint rewards
    function setRewardToken(address _rewardToken) external onlyOwner {
        rewardToken = IRewardToken(_rewardToken);
        emit RewardTokenAddressSet(_rewardToken);
    }

    function grantConsent(
        address requester,
        bytes32 dataId,
        uint64 expiresAt,
        string calldata purpose
    ) external returns (uint256 consentId) {
        require(requester != address(0), "Invalid requester");
        require(dataId != bytes32(0), "Missing data ID");

        consentId = nextConsentId;
        nextConsentId += 1;

        Consent storage c = consents[consentId];
        c.subject = msg.sender;
        c.requester = requester;
        c.dataId = dataId;
        c.createdAt = uint64(block.timestamp);
        c.expiresAt = expiresAt;
        c.status = ConsentStatus.Active;
        c.purpose = purpose;

        consentsBySubject[msg.sender].push(consentId);
        consentsByRequester[requester].push(consentId);

        emit ConsentGranted(
            consentId,
            msg.sender,
            requester,
            dataId,
            expiresAt,
            purpose
        );

        // reward logic: if rewardToken is configured, mint tokens for the patient
        if (address(rewardToken) != address(0)) {
            rewardToken.rewardForConsent(msg.sender, REWARD_PER_CONSENT);
        }
    }

    function revokeConsent(uint256 consentId) external onlySubject(consentId) {
        Consent storage c = consents[consentId];
        require(c.status == ConsentStatus.Active, "Already revoked or not active");

        c.status = ConsentStatus.Revoked;

        emit ConsentRevoked(consentId, c.subject);
    }

    function isConsentValid(
        address subject,
        address requester,
        bytes32 dataId
    ) public view returns (bool valid, uint256 consentId) {
        // Simple linear scan over this subject's consents.
        uint256[] storage subjectConsents = consentsBySubject[subject];

        for (uint256 i = 0; i < subjectConsents.length; i++) {
            uint256 id = subjectConsents[i];
            Consent storage c = consents[id];

            if (
                c.subject == subject &&
                c.requester == requester &&
                c.dataId == dataId &&
                c.status == ConsentStatus.Active &&
                !_isExpired(c.expiresAt)
            ) {
                return (true, id);
            }
        }

        return (false, 0); // no match found
    }

    function isConsentIdValid(uint256 consentId) public view returns (bool) {
        Consent storage c = consents[consentId];
        return (
            c.status == ConsentStatus.Active &&
            !_isExpired(c.expiresAt)
        );
    }

    function _isExpired(uint64 expiresAt) internal view returns (bool) {
        if (expiresAt == 0) return false; // 0 means no expiry time 
        return block.timestamp > expiresAt;
    }

    function logAccess(uint256 consentId) external {
        Consent storage c = consents[consentId];

        require(c.status == ConsentStatus.Active, "Consent not active");
        require(!_isExpired(c.expiresAt), "Consent expired");
        require(msg.sender == c.requester, "Only requester can log access");

        emit AccessLogged(
            consentId,
            c.subject,
            c.requester,
            c.dataId,
            uint64(block.timestamp)
        );
    }

    function getConsentsOfSubject(address subject) external view returns (uint256[] memory) {
        return consentsBySubject[subject];
    }

    function getConsentsOfRequester(address requester) external view returns (uint256[] memory) {
        return consentsByRequester[requester];
    }

    // Compatibility layer (used by DataSharing)
    function hasValidConsent(
        address patient,
        address requester,
        uint256 dataTypeId,
        uint256 atTime
    ) external view returns (bool) {
        bytes32 dataId = bytes32(dataTypeId);

        (bool valid, uint256 id) = isConsentValid(patient, requester, dataId);
        if (!valid) return false;

        Consent storage c = consents[id];
        if (c.expiresAt != 0 && atTime > c.expiresAt) {
            return false;
        }

        return true;
    }
}
