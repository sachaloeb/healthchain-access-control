// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

//Registers users and their roles and stores hashed attributes.
contract IdentityRegistry {
    enum UserRole {
        None,
        Patient,
        Requester
    }

    struct Identity {
        UserRole role;
        // optional organizational identifier for requesters only (hashed), patients can set to 0
        uint256 orgHash;
        mapping(uint256 => uint256) attributes; // keyHash => valueHash
    }

    address public owner;
    mapping(address => bool) public isRegistered;
    mapping(address => Identity) private identities;

    event Registered(address indexed user, UserRole role, uint256 orgHash);
    event Unregistered(address indexed user);
    event IdentityUpdated(address indexed user, uint256 indexed keyHash, uint256 valueHash);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // orgHash is only relevant for Requesters and can be 0x0 for patients
    function registerUser(UserRole role, uint256 orgHash) external {
        require(role != UserRole.None, "Invalid role");
        require(!isRegistered[msg.sender], "Already registered");

        isRegistered[msg.sender] = true;
        Identity storage id = identities[msg.sender];
        id.role = role;
        id.orgHash = orgHash;

        emit Registered(msg.sender, role, orgHash);
    }

    // unregister caller - role becomes None, orgHash becomes 0x0.
    function unregisterUser() external {
        require(isRegistered[msg.sender], "Not registered");
        isRegistered[msg.sender] = false;
        identities[msg.sender].role = UserRole.None;
        identities[msg.sender].orgHash = 0;
        emit Unregistered(msg.sender);
    }

    // update caller's identity
    function updateIdentity(uint256 keyHash, uint256 valueHash) external {
        require(isRegistered[msg.sender], "Not registered");
        identities[msg.sender].attributes[keyHash] = valueHash;
        emit IdentityUpdated(msg.sender, keyHash, valueHash);
    }

    // returns caller's role
    function getUserRole(address user) external view returns (UserRole) {
        return identities[user].role;
    }

    // returns a hashed attribute value for user by key hash
    function getHashedAttributes(address user, uint256 keyHash) external view returns (uint256) {
        return identities[user].attributes[keyHash];
    }

    //returns get org hash (for requesters).
    function getOrgHash(address user) external view returns (uint256) {
        return identities[user].orgHash;
    }
}