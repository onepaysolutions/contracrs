// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/base/ERC721Base.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRewardToken {
    function mint(address to, uint256 amount) external;
}

interface IUserNFT {
    function userId(address user) external view returns (uint256);
}

contract CommunityNFT is ERC721Base, PermissionsEnumerable {
    // Declare token addresses for payment and rewards
    IRewardToken public rewardToken;
    IUserNFT public userNFT;

    struct ClaimCondition {
        uint256 startTime;
        uint256 endTime;
        uint256 claimPrice;
        uint256 rewardAmount;
        address rewardToken;
        bool isActive;
    }

    ClaimCondition[] public claimConditions;
    mapping(address => bool) public acceptedTokens;

    mapping(uint256 => bool) public claimed;
    mapping(uint256 => address) public referrers;
    mapping(uint256 => bool) public referralRewardClaimed;
    mapping(address => address[]) public directReferrals;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    event CommunityNFTMinted(address indexed owner, uint256 indexed tokenId, address indexed referrer);
    event RewardClaimed(uint256 indexed tokenId, uint256 amount);
    event ReferralRewardClaimed(uint256 indexed tokenId, address indexed referrer, uint256 amount);
    event ClaimConditionAdded(uint256 index, uint256 startTime, uint256 endTime, uint256 claimPrice, uint256 rewardAmount, address rewardToken);
    event ClaimConditionUpdated(uint256 index, uint256 newClaimPrice, uint256 newRewardAmount, address newRewardToken);

    constructor(
        address _defaultAdmin,
        string memory _name,
        string memory _symbol,
        address _royaltyRecipient,
        uint128 _royaltyBps,
        address _userNFT
    ) ERC721Base(_defaultAdmin, _name, _symbol, _royaltyRecipient, _royaltyBps) {
        userNFT = IUserNFT(_userNFT);

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    // Add accepted payment tokens
    function addAcceptedToken(address token) external onlyRole(ADMIN_ROLE) {
        acceptedTokens[token] = true;
    }

    // Remove accepted payment token
    function removeAcceptedToken(address token) external onlyRole(ADMIN_ROLE) {
        acceptedTokens[token] = false;
    }

    // Add claim condition
    function addClaimCondition(
        uint256 startTime,
        uint256 endTime,
        uint256 claimPrice,
        uint256 rewardAmount,
        address rewardTokenAddress
    ) external onlyRole(ADMIN_ROLE) {
        require(endTime > startTime, "End time must be after start time");

        ClaimCondition memory newCondition = ClaimCondition({
            startTime: startTime,
            endTime: endTime,
            claimPrice: claimPrice,
            rewardAmount: rewardAmount,
            rewardToken: rewardTokenAddress,
            isActive: true
        });

        claimConditions.push(newCondition);
        emit ClaimConditionAdded(claimConditions.length - 1, startTime, endTime, claimPrice, rewardAmount, rewardTokenAddress);
    }

    // Update claim condition
    function updateClaimCondition(
        uint256 conditionIndex,
        uint256 newClaimPrice,
        uint256 newRewardAmount,
        address newRewardTokenAddress
    ) external onlyRole(ADMIN_ROLE) {
        require(conditionIndex < claimConditions.length, "Invalid condition index");

        ClaimCondition storage condition = claimConditions[conditionIndex];
        condition.claimPrice = newClaimPrice;
        condition.rewardAmount = newRewardAmount;
        condition.rewardToken = newRewardTokenAddress;

        emit ClaimConditionUpdated(conditionIndex, newClaimPrice, newRewardAmount, newRewardTokenAddress);
    }

    function mint(uint256 conditionIndex, address referrer, address paymentToken) external {
        require(conditionIndex < claimConditions.length, "Invalid condition index");
        ClaimCondition memory condition = claimConditions[conditionIndex];

        require(condition.isActive, "Claim condition is inactive");
        require(block.timestamp >= condition.startTime, "Claim period has not started");
        require(block.timestamp <= condition.endTime, "Claim period has ended");
        require(acceptedTokens[paymentToken], "Payment token not accepted");

        // Transfer payment token
        require(
            IERC20(paymentToken).transferFrom(msg.sender, address(this), condition.claimPrice),
            "Payment failed"
        );

        uint256 tokenId = nextTokenIdToMint();
        _safeMint(msg.sender, tokenId);
        claimed[tokenId] = true;

        // Handle referral rewards and store direct referral relationship
        if (referrer != address(0) && referrer != msg.sender) {
            referrers[tokenId] = referrer;
            directReferrals[referrer].push(msg.sender); // Store direct referral
            IRewardToken(condition.rewardToken).mint(referrer, condition.rewardAmount / 10); // Example: 10% referral reward
            referralRewardClaimed[tokenId] = true;
            emit ReferralRewardClaimed(tokenId, referrer, condition.rewardAmount / 10);
        }

        // Mint reward tokens to the buyer
        IRewardToken(condition.rewardToken).mint(msg.sender, condition.rewardAmount);

        emit CommunityNFTMinted(msg.sender, tokenId, referrer);
        emit RewardClaimed(tokenId, condition.rewardAmount);
    }

    function getClaimCondition(uint256 index) external view returns (
        uint256 startTime,
        uint256 endTime,
        uint256 claimPrice,
        uint256 rewardAmount,
        address rewardToken,
        bool isActive
    ) {
        ClaimCondition memory condition = claimConditions[index];
        return (
            condition.startTime,
            condition.endTime,
            condition.claimPrice,
            condition.rewardAmount,
            condition.rewardToken,
            condition.isActive
        );
    }

    function getDirectReferrals(address user) external view returns (address[] memory) {
        return directReferrals[user];
    }

    function getUserIdFromUserNFT(address user) external view returns (uint256) {
        return userNFT.userId(user);
    }

    function emergencyWithdraw(address token, uint256 amount) external onlyRole(ADMIN_ROLE) {
        require(IERC20(token).transfer(msg.sender, amount), "Withdraw failed");
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721Base) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
