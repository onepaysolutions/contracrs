// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IStarNFT {
    function getTokenInfo(uint256 tokenId) external view returns (
        bool isActivated,
        uint256 activationTimestamp,
        uint256 usdValueCap,
        uint256 totalOPSBought,
        uint256 totalOPSRewarded,
        uint256 totalOPSAirdropped,
        bool isReleasing
    );
}

interface IPriceController {
    function getCurrentPrice() external view returns (uint256);
    function getNextPhasePrice() external view returns (uint256);
    function advancePhase() external returns (bool);
    function isPhaseCompleted() external view returns (bool);
    function getCurrentPhaseInfo() external view returns (
        uint256 phaseIndex,
        uint256 price,
        uint256 target,
        uint256 sold
    );
}

interface IFundsDistributor {
    function distributeFunds(address token) external;
}

interface IOPSToken {
    function mint(address to, uint256 amount) external;
}

contract OPSPresale is AccessControl, ReentrancyGuard {
    IERC20 public usdcToken;
    IERC20 public usdtToken;
    IERC20 public nativeToken;
    IStarNFT public starNFT;
    IPriceController public priceController;
    IFundsDistributor public fundsDistributor;
    IOPSToken public opsToken;

    bool public isPresaleActive;
    uint256 public currentCycleId;

    event TokensPurchased(
        address indexed buyer,
        address token,
        uint256 payAmount,
        uint256 opsAmount,
        uint256 price
    );
    event CycleCompleted(uint256 indexed cycleId, uint256 timestamp);

    constructor(
        address initialOwner,
        address _usdcToken,
        address _usdtToken,
        address _nativeToken,
        address _starNFT,
        address _priceController,
        address _fundsDistributor,
        address _opsToken
    ) AccessControl(initialOwner) {
        usdcToken = IERC20(_usdcToken);
        usdtToken = IERC20(_usdtToken);
        nativeToken = IERC20(_nativeToken);
        starNFT = IStarNFT(_starNFT);
        priceController = IPriceController(_priceController);
        fundsDistributor = IFundsDistributor(_fundsDistributor);
        opsToken = IOPSToken(_opsToken);
    }

    function updateContracts(
        address _priceController,
        address _fundsDistributor,
        address _opsToken
    ) external onlyOwner {
        require(_priceController != address(0), "Invalid price controller");
        require(_fundsDistributor != address(0), "Invalid funds distributor");
        require(_opsToken != address(0), "Invalid OPS token");

        priceController = IPriceController(_priceController);
        fundsDistributor = IFundsDistributor(_fundsDistributor);
        opsToken = IOPSToken(_opsToken);
    }

    function purchaseWithNativeToken(
        uint256 amount,
        uint256 tokenId
    ) external nonReentrant whenNotPaused {
        require(isPresaleActive, "Presale not active");
        _validatePurchase(tokenId);

        uint256 currentPrice = priceController.getCurrentPrice();
        uint256 opsAmount = (amount * 1e18) / currentPrice;

        require(
            nativeToken.transferFrom(msg.sender, address(this), amount),
            "Token transfer failed"
        );

        _processPurchase(msg.sender, opsAmount, amount, address(nativeToken));
    }

    function _validatePurchase(uint256 tokenId) internal view {
        (
            bool isActivated,
            ,
            ,
            ,
            ,
            ,
            bool isReleasing
        ) = starNFT.getTokenInfo(tokenId);

        require(isActivated, "StarNFT not activated");
        require(!isReleasing, "StarNFT in releasing state");
    }

    function _processPurchase(
        address buyer,
        uint256 opsAmount,
        uint256 payAmount,
        address payToken
    ) internal {
        opsToken.mint(buyer, opsAmount);

        fundsDistributor.distributeFunds(payToken);

        if (priceController.isPhaseCompleted()) {
            if (priceController.advancePhase()) {
                currentCycleId++;
                emit CycleCompleted(currentCycleId, block.timestamp);
            }
        }

        emit TokensPurchased(
            buyer,
            payToken,
            payAmount,
            opsAmount,
            priceController.getCurrentPrice()
        );
    }

    function startPresale() external onlyManager {
        isPresaleActive = true;
    }

    function pausePresale() external onlyManager {
        isPresaleActive = false;
    }

    function getCurrentCycleInfo() external view returns (
        uint256 cycleId,
        uint256 currentPrice,
        uint256 nextPrice,
        bool isActive
    ) {
        return (
            currentCycleId,
            priceController.getCurrentPrice(),
            priceController.getNextPhasePrice(),
            isPresaleActive
        );
    }

    function updateTokenAddresses(
        address _usdcToken,
        address _usdtToken,
        address _nativeToken
    ) external onlyOwner {
        require(_usdcToken != address(0), "Invalid USDC address");
        require(_usdtToken != address(0), "Invalid USDT address");
        require(_nativeToken != address(0), "Invalid native token address");

        usdcToken = IERC20(_usdcToken);
        usdtToken = IERC20(_usdtToken);
        nativeToken = IERC20(_nativeToken);
    }
}

