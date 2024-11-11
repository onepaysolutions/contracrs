// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";

/**
 * @title Community OPE Reward Distributor
 * @notice Handles the distribution of OPE token rewards for Community NFT holders
 * @dev Includes mechanisms for both mining and referral rewards with expiration checks
 */
interface ICommunityNFT {
    function canClaimReferralReward(uint256 tokenId) external view returns (bool);
    function isReferralRewardExpired(uint256 tokenId) external view returns (bool);
    function referrers(uint256 tokenId) external view returns (address);
}

interface IOPEToken {
    function mint(address to, uint256 amount) external;
}

contract CommunityRewardDistributor is ContractMetadata, PermissionsEnumerable {
    // Core state variables
    IERC20 public opeToken;
    ICommunityNFT public communityNFT;
    IOPEToken public opeTokenContract;

    // Reward amounts
    uint256 public constant MINING_REWARD = 1000e18; // 1000 OPE for mining
    uint256 public constant REFERRAL_REWARD = 1000e18; // 1000 OPE for referral

    // Role definitions
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // Tracking mappings
    mapping(uint256 => bool) public processedMiningRewards;
    mapping(uint256 => bool) public processedReferralRewards;

    event MiningRewardDistributed(
        address indexed user,
        uint256 indexed tokenId,
        uint256 amount
    );

    event ReferralRewardDistributed(
        address indexed referrer,
        uint256 indexed tokenId,
        uint256 amount
    );

    event ReferralRewardExpired(
        uint256 indexed tokenId,
        address indexed referrer,
        uint256 amount
    );

    constructor(
        address _opeToken,
        address _communityNFT,
        address _opeTokenContract
    ) {
        opeToken = IERC20(_opeToken);
        communityNFT = ICommunityNFT(_communityNFT);
        opeTokenContract = IOPEToken(_opeTokenContract);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(OPERATOR_ROLE, msg.sender);
    }

    /**
     * @notice Processes mining reward for a specific token
     * @param tokenId The ID of the token to process mining reward for
     * @return The amount of OPE tokens distributed
     * @dev Can only be called by OPERATOR_ROLE
     */
    function processMiningReward(uint256 tokenId) external onlyRole(OPERATOR_ROLE) returns (uint256) {
        require(!processedMiningRewards[tokenId], "Mining reward already processed");
        
        address owner = communityNFT.ownerOf(tokenId);
        processedMiningRewards[tokenId] = true;

        opeTokenContract.mint(owner, MINING_REWARD);

        emit MiningRewardDistributed(owner, tokenId, MINING_REWARD);
        return MINING_REWARD;
    }

    /**
     * @notice Processes referral reward for a specific token
     * @param tokenId The ID of the token to process referral reward for
     * @return The amount of OPE tokens distributed (0 if expired or invalid)
     * @dev Can only be called by OPERATOR_ROLE
     */
    function processReferralReward(uint256 tokenId) external onlyRole(OPERATOR_ROLE) returns (uint256) {
        require(!processedReferralRewards[tokenId], "Referral reward already processed");
        
        address referrer = communityNFT.referrers(tokenId);
        require(referrer != address(0), "No referrer");

        if (communityNFT.isReferralRewardExpired(tokenId)) {
            processedReferralRewards[tokenId] = true;
            emit ReferralRewardExpired(tokenId, referrer, REFERRAL_REWARD);
            return 0;
        }

        if (communityNFT.canClaimReferralReward(tokenId)) {
            processedReferralRewards[tokenId] = true;
            opeTokenContract.mint(referrer, REFERRAL_REWARD);
            emit ReferralRewardDistributed(referrer, tokenId, REFERRAL_REWARD);
            return REFERRAL_REWARD;
        }

        return 0;
    }

    function emergencyWithdraw(
        address token,
        uint256 amount
    ) external onlyRole(ADMIN_ROLE) {
        require(
            IERC20(token).transfer(msg.sender, amount),
            "Transfer failed"
        );
    }

    function _canSetContractURI() internal view virtual override returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
} 
