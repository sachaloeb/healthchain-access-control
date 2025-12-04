// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

contract RewardToken {
    string public name = "Data Access Reward Token";
    string public symbol = "DART";
    uint8 public decimals = 18;

    uint256 public totalSupply;
    uint256 public maxRewardSupply = 1_000_000 * 10**18;

    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;
    mapping(address => uint256) public totalRewarded;

    address public owner;
    address public consentManager;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed tokenOwner, address indexed spender, uint256 value);
    event ConsentManagerUpdated(address indexed previous, address indexed current);
    event RewardGiven(address indexed patient, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyConsentManager() {
        require(msg.sender == consentManager, "Not consent manager");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setConsentManager(address newManager) external onlyOwner {
        require(newManager != address(0), "Invalid manager");
        address prev = consentManager;
        consentManager = newManager;
        emit ConsentManagerUpdated(prev, newManager);
    }

    function rewardForConsent(address user, uint256 amount) external onlyConsentManager {
        require(user != address(0), "Zero user");
        require(amount > 0, "Zero amount");
        require(totalSupply + amount <= maxRewardSupply, "Cap exceeded");

        totalRewarded[user] += amount;
        _mint(user, amount);
        emit RewardGiven(user, amount);
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    function allowance(address tokenOwner, address spender) external view returns (uint256) {
        return allowances[tokenOwner][spender];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowances[from][msg.sender];
        require(allowed >= amount, "Allowance too low");

        if (allowed != type(uint256).max) {
            unchecked {
                allowances[from][msg.sender] = allowed - amount;
            }
        }

        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(to != address(0), "Bad recipient");
        uint256 fromBal = balances[from];
        require(fromBal >= amount, "Balance too low");

        unchecked {
            balances[from] = fromBal - amount;
        }
        balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "Mint to zero");

        totalSupply += amount;
        balances[to] += amount;

        emit Transfer(address(0), to, amount);
    }
}
