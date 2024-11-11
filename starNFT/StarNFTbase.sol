// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IOPSPresale {
    function getCurrentPrice() external view returns (uint256);
}

contract StarNFTBase is ERC721Enumerable, Ownable, ReentrancyGuard {
    struct TokenInfo {
        bool isActivated;
        uint256 activationTimestamp;
        uint256 usdValueCap;
        uint256 totalOPSBought;
        uint256 totalOPSRewarded;
        uint256 totalOPSAirdropped;
        bool isReleasing;
    }

    mapping(uint256 => TokenInfo) public tokenInfo;
    
    uint256 public immutable ACTIVATION_PRICE;
    uint256 public immutable OPS_PRESALE_AMOUNT;
    uint256 public immutable REWARD_LEVELS;
    uint256 public immutable STAR_LEVEL;

    uint256 private _tokenIdCounter;

    IERC20 public usdcToken;
    IERC20 public usdtToken;
    IOPSPresale public presaleContract;

    event TokenMinted(address indexed to, uint256 indexed tokenId);
    event TokenActivated(uint256 indexed tokenId, uint256 activationPrice, uint256 opsAmount);
    event RewardRecorded(uint256 indexed tokenId, uint256 amount);
    event AirdropRecorded(uint256 indexed tokenId, uint256 amount);
    event TokenReleased(uint256 indexed tokenId);

    constructor(
        string memory name,
        string memory symbol,
        address initialOwner,
        uint256 starLevel,
        uint256 activationPrice,
        uint256 opsPresaleAmount,
        uint256 rewardLevels,
        address _usdcToken,
        address _usdtToken,
        address _presaleContract
    ) ERC721(name, symbol) Ownable(initialOwner) {
        STAR_LEVEL = starLevel;
        ACTIVATION_PRICE = activationPrice;
        OPS_PRESALE_AMOUNT = opsPresaleAmount;
        REWARD_LEVELS = rewardLevels;
        usdcToken = IERC20(_usdcToken);
        usdtToken = IERC20(_usdtToken);
        presaleContract = IOPSPresale(_presaleContract);
    }

    function mint() external nonReentrant {
        _tokenIdCounter++;
        uint256 tokenId = _tokenIdCounter;
        _safeMint(msg.sender, tokenId);
        emit TokenMinted(msg.sender, tokenId);
    }

    function activateNFT(uint256 tokenId, bool useUSDC) external nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        require(!tokenInfo[tokenId].isActivated, "Already activated");

        IERC20 token = useUSDC ? usdcToken : usdtToken;
        require(
            token.transferFrom(msg.sender, address(this), ACTIVATION_PRICE),
            "Payment failed"
        );

        tokenInfo[tokenId] = TokenInfo({
            isActivated: true,
            activationTimestamp: block.timestamp,
            usdValueCap: ACTIVATION_PRICE,
            totalOPSBought: OPS_PRESALE_AMOUNT,
            totalOPSRewarded: 0,
            totalOPSAirdropped: 0,
            isReleasing: false
        });

        emit TokenActivated(tokenId, ACTIVATION_PRICE, OPS_PRESALE_AMOUNT);
    }

    function recordReward(uint256 tokenId, uint256 amount) external onlyOwner {
        require(_exists(tokenId), "Token does not exist");
        TokenInfo storage info = tokenInfo[tokenId];
        require(info.isActivated, "Not activated");
        require(!info.isReleasing, "Token is releasing");
        
        info.totalOPSRewarded += amount;
        checkReleaseCondition(tokenId);
        emit RewardRecorded(tokenId, amount);
    }

    function recordAirdrop(uint256 tokenId, uint256 amount) external onlyOwner {
        require(_exists(tokenId), "Token does not exist");
        TokenInfo storage info = tokenInfo[tokenId];
        require(info.isActivated, "Not activated");
        require(!info.isReleasing, "Token is releasing");
        
        info.totalOPSAirdropped += amount;
        checkReleaseCondition(tokenId);
        emit AirdropRecorded(tokenId, amount);
    }

    function checkReleaseCondition(uint256 tokenId) internal {
        TokenInfo storage info = tokenInfo[tokenId];
        if (!info.isReleasing) {
            uint256 currentPrice = presaleContract.getCurrentPrice();
            uint256 totalValue = (info.totalOPSBought + 
                                info.totalOPSRewarded + 
                                info.totalOPSAirdropped) * currentPrice;
            
            if (totalValue >= info.usdValueCap) {
                info.isReleasing = true;
                emit TokenReleased(tokenId);
            }
        }
    }

    function getUserTokens(address user) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(user);
        uint256[] memory tokens = new uint256[](balance);
        for (uint256 i = 0; i < balance; i++) {
            tokens[i] = tokenOfOwnerByIndex(user, i);
        }
        return tokens;
    }

    function getStarLevel() external view returns (uint256) {
        return STAR_LEVEL;
    }

    function getTokenInfo(uint256 tokenId) external view returns (
        bool isActivated,
        uint256 activationTimestamp,
        uint256 usdValueCap,
        uint256 totalOPSBought,
        uint256 totalOPSRewarded,
        uint256 totalOPSAirdropped,
        bool isReleasing
    ) {
        TokenInfo storage info = tokenInfo[tokenId];
        return (
            info.isActivated,
            info.activationTimestamp,
            info.usdValueCap,
            info.totalOPSBought,
            info.totalOPSRewarded,
            info.totalOPSAirdropped,
            info.isReleasing
        );
    }

    function withdrawToken(address token, uint256 amount) external onlyOwner {
        require(
            IERC20(token).transfer(owner(), amount),
            "Transfer failed"
        );
    }
} 
