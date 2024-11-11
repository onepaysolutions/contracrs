// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";

interface IUserNFT {
    function getUserInfo(address user) external view returns (
        address referrer,
        string memory userId,
        string memory zone,
        uint256 mintTime,
        bool isActive,
        uint256 nftType
    );
}

contract ReferralSystem is ContractMetadata, PermissionsEnumerable {
    struct UserInfo {
        address referrer;          // Address of the referrer
        uint256 level;            // Level in the referral tree
        uint256 totalOPS;         // Total personal OPS performance
        mapping(string => uint256) zoneOPS;  // OPS performance by zone
        mapping(string => uint256) zoneTeamOPS;  // Team OPS performance by zone
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    IUserNFT public userNFT;
    
    mapping(address => UserInfo) public users;
    mapping(address => address[]) public uplines;  // User's upline path

    // Events
    event ReferralAdded(
        address indexed referrer,
        address indexed referee,
        string zone,
        uint256 level
    );
    event OPSRecorded(
        address indexed user,
        uint256 amount,
        string zone,
        bool isPersonal
    );
    event TeamOPSUpdated(
        address indexed user,
        string zone,
        uint256 newAmount
    );

    constructor(
        address _userNFT
    ) {
        require(_userNFT != address(0), "Invalid UserNFT address");
        userNFT = IUserNFT(_userNFT);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    // Add referral relationship
    function addReferral(
        address referrer,
        address referee
    ) external onlyRole(ADMIN_ROLE) {
        require(referrer != address(0), "Invalid referrer");
        require(referee != address(0), "Invalid referee");
        require(referrer != referee, "Cannot refer self");

        // Get user's zone information
        (,, string memory zone,,,) = userNFT.getUserInfo(referee);

        UserInfo storage referrerInfo = users[referrer];
        
        // Set referral relationship
        users[referee].referrer = referrer;
        users[referee].level = referrerInfo.level + 1;

        // Update upline path
        address[] memory referrerUpline = uplines[referrer];
        address[] memory newUpline = new address[](referrerUpline.length + 1);
        for(uint i = 0; i < referrerUpline.length; i++) {
            newUpline[i] = referrerUpline[i];
        }
        newUpline[referrerUpline.length] = referrer;
        uplines[referee] = newUpline;

        emit ReferralAdded(referrer, referee, zone, users[referee].level);
    }

    // Record personal OPS performance
    function recordOPS(
        address user,
        uint256 amount
    ) external onlyRole(ADMIN_ROLE) {
        // Get user's zone information
        (,, string memory zone,,,) = userNFT.getUserInfo(user);
        
        users[user].totalOPS += amount;
        users[user].zoneOPS[zone] += amount;
        
        // Update team performance for all uplines
        address[] memory userUplines = uplines[user];
        for(uint i = 0; i < userUplines.length; i++) {
            users[userUplines[i]].zoneTeamOPS[zone] += amount;
            emit TeamOPSUpdated(userUplines[i], zone, users[userUplines[i]].zoneTeamOPS[zone]);
        }

        emit OPSRecorded(user, amount, zone, true);
    }

    // Get user's personal OPS performance in a specific zone
    function getZoneOPS(
        address user,
        string memory zone
    ) external view returns (uint256) {
        return users[user].zoneOPS[zone];
    }

    // Get user's team OPS performance in a specific zone
    function getZoneTeamOPS(
        address user,
        string memory zone
    ) external view returns (uint256) {
        return users[user].zoneTeamOPS[zone];
    }

    // Get user's upline path
    function getUplines(address user) external view returns (address[] memory) {
        return uplines[user];
    }

    // Get user's level in the referral tree
    function getUserLevel(address user) external view returns (uint256) {
        return users[user].level;
    }

    // Get user's total OPS performance
    function getTotalOPS(address user) external view returns (uint256) {
        return users[user].totalOPS;
    }

    // Get user's complete information
    function getUserInfo(
        address user,
        string memory zone
    ) external view returns (
        address referrer,
        uint256 level,
        uint256 totalOPS,
        uint256 zoneOPS,
        uint256 zoneTeamOPS
    ) {
        UserInfo storage info = users[user];
        return (
            info.referrer,
            info.level,
            info.totalOPS,
            info.zoneOPS[zone],
            info.zoneTeamOPS[zone]
        );
    }

    /// @dev Returns whether contract metadata can be set in the given execution context.
    function _canSetContractURI() internal view virtual override returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
}
