// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./AccessControl.sol"; 
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title Funds Distributor Contract
 * @notice Handles the distribution of funds according to predefined ratios
 * @dev Distributes funds to promotion, exchange, and buyback wallets
 */
contract FundsDistributor is AccessControl, ReentrancyGuard {
    // Fund distribution ratios (base 10000)
    uint256 public constant PROMOTION_SHARE = 3500;    // 35% for OPS promotion
    uint256 public constant EXCHANGE_SHARE = 6000;     // 60% for exchange
    uint256 public constant BUYBACK_SHARE = 500;       // 5% for OPE token buyback

    // Wallet addresses
    address public promotionWallet;    // OPS promotion wallet
    address public exchangeWallet;      // Exchange wallet
    address public buybackWallet;       // OPE buyback wallet

    event FundsDistributed(
        address indexed token,
        uint256 promotionAmount,
        uint256 exchangeAmount,
        uint256 buybackAmount
    );

    constructor(
        address initialOwner,
        address _promotionWallet,
        address _exchangeWallet,
        address _buybackWallet
    ) AccessControl(initialOwner) {
        require(_promotionWallet != address(0), "Invalid promotion wallet");
        require(_exchangeWallet != address(0), "Invalid exchange wallet");
        require(_buybackWallet != address(0), "Invalid buyback wallet");

        promotionWallet = _promotionWallet;
        exchangeWallet = _exchangeWallet;
        buybackWallet = _buybackWallet;
    }

    /**
     * @notice Distributes tokens according to predefined ratios
     * @param token Address of the token to distribute
     * @param amount Total amount to distribute
     */
    function distributeTokens(
        address token,
        uint256 amount
    ) external onlyOwner nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        
        uint256 promotionAmount = (amount * PROMOTION_SHARE) / 10000;
        uint256 exchangeAmount = (amount * EXCHANGE_SHARE) / 10000;
        uint256 buybackAmount = (amount * BUYBACK_SHARE) / 10000;

        IERC20 tokenContract = IERC20(token);

        require(
            tokenContract.transfer(promotionWallet, promotionAmount),
            "Promotion transfer failed"
        );
        require(
            tokenContract.transfer(exchangeWallet, exchangeAmount),
            "Exchange transfer failed"
        );
        require(
            tokenContract.transfer(buybackWallet, buybackAmount),
            "Buyback transfer failed"
        );

        emit FundsDistributed(
            token,
            promotionAmount,
            exchangeAmount,
            buybackAmount
        );
    }

    /**
     * @notice Updates the promotion wallet address
     * @param newWallet New promotion wallet address
     */
    function setPromotionWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Invalid wallet address");
        promotionWallet = newWallet;
    }

    /**
     * @notice Updates the exchange wallet address
     * @param newWallet New exchange wallet address
     */
    function setExchangeWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Invalid wallet address");
        exchangeWallet = newWallet;
    }

    /**
     * @notice Updates the buyback wallet address
     * @param newWallet New buyback wallet address
     */
    function setBuybackWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Invalid wallet address");
        buybackWallet = newWallet;
    }

    /**
     * @notice Emergency withdrawal of tokens
     * @param token Address of token to withdraw
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(
        address token,
        uint256 amount
    ) external onlyOwner {
        require(
            IERC20(token).transfer(msg.sender, amount),
            "Transfer failed"
        );
    }
}
