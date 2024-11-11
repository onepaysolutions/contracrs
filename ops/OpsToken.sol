// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStarNFT {
    function ownerOf(uint256 tokenId) external view returns (address);
    function getTokenInfo(uint256 tokenId) external view returns (
        bool isActivated,
        uint256 activationTimestamp,
        uint256 usdValueCap,
        uint256 totalOPSBought,
        uint256 totalOPSRewarded,
        uint256 totalOPSAirdropped,
        bool isReleasing
    );
    function burn(uint256 tokenId) external;
}

interface IOPSPresale {
    function getNextCycleStartPrice() external view returns (uint256);
}

contract OPSToken is ERC20, Ownable, ReentrancyGuard {
    IERC20 public usdcToken;
    IStarNFT public starNFT;
    IOPSPresale public presaleContract;
    address public managementWallet;

    uint256 public constant MIN_BURN_PERCENTAGE = 15;
    uint256 public constant MAX_BURN_PERCENTAGE = 85;

    mapping(uint256 => bool) public burnedTokens;
    bool public burnEnabled = false;

    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(
        address indexed from, 
        uint256 burnedAmount, 
        uint256 releasedAmount, 
        uint256 usdcAmount
    );
    event StarNFTBurned(
        uint256 indexed tokenId, 
        uint256 burnedOPS, 
        uint256 releasedOPS, 
        uint256 usdcAmount
    );
    event BurnEnabledChanged(bool enabled);
    event PresaleContractChanged(address newContract);

    constructor(
        address initialOwner,
        address _usdcToken,
        address _starNFT,
        address _managementWallet
    ) ERC20("OPS Token", "OPS") Ownable(initialOwner) {
        usdcToken = IERC20(_usdcToken);
        starNFT = IStarNFT(_starNFT);
        managementWallet = _managementWallet;
    }

    modifier onlyPresale() {
        require(msg.sender == address(presaleContract), "Only presale contract");
        _;
    }

    function setPresaleContract(address _presaleContract) external onlyOwner {
        require(_presaleContract != address(0), "Invalid address");
        presaleContract = IOPSPresale(_presaleContract);
        emit PresaleContractChanged(_presaleContract);
    }

    function setManagementWallet(address _managementWallet) external onlyOwner {
        require(_managementWallet != address(0), "Invalid address");
        managementWallet = _managementWallet;
    }

    function setBurnEnabled(bool _enabled) external onlyOwner {
        burnEnabled = _enabled;
        emit BurnEnabledChanged(_enabled);
    }

    function mint(address to, uint256 amount) external onlyPresale {
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    function burnStarNFTForUSDC(
        uint256 tokenId, 
        uint256 burnPercentage
    ) external nonReentrant {
        require(burnEnabled, "Burn not enabled");
        require(!burnedTokens[tokenId], "Token already burned");
        require(starNFT.ownerOf(tokenId) == msg.sender, "Not token owner");
        require(
            burnPercentage >= MIN_BURN_PERCENTAGE && 
            burnPercentage <= MAX_BURN_PERCENTAGE,
            "Invalid burn percentage"
        );

        (
            bool isActivated,
            ,
            uint256 usdValueCap,
            uint256 totalOPSBought,
            uint256 totalOPSRewarded,
            uint256 totalOPSAirdropped,
            bool isReleasing
        ) = starNFT.getTokenInfo(tokenId);

        require(isActivated, "Token not activated");
        require(isReleasing, "Token not in releasing state");

        uint256 totalOPS = totalOPSBought + totalOPSRewarded + totalOPSAirdropped;
        uint256 burnAmount = (totalOPS * burnPercentage) / 100;
        uint256 releaseAmount = totalOPS - burnAmount;

        require(balanceOf(msg.sender) >= totalOPS, "Insufficient OPS balance");

        uint256 nextCyclePrice = presaleContract.getNextCycleStartPrice();
        uint256 usdcAmount = (burnAmount * nextCyclePrice) / 1e18;

        _burn(msg.sender, burnAmount);

        _transfer(msg.sender, address(this), releaseAmount);

        require(
            usdcToken.transfer(managementWallet, usdcAmount),
            "USDC transfer failed"
        );

        starNFT.burn(tokenId);
        burnedTokens[tokenId] = true;

        emit TokensBurned(msg.sender, burnAmount, releaseAmount, usdcAmount);
        emit StarNFTBurned(tokenId, burnAmount, releaseAmount, usdcAmount);
    }

    function emergencyWithdraw(
        address token,
        uint256 amount
    ) external onlyOwner {
        require(
            IERC20(token).transfer(owner(), amount),
            "Transfer failed"
        );
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
    }
} 
