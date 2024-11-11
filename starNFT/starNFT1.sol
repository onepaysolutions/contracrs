// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../contracts/star/StarNFTbase.sol";

contract Star1NFT is StarNFTBase {
    constructor(
        address initialOwner,
        address _usdcToken,
        address _usdtToken,
        address _presaleContract
    ) StarNFTBase(
        "Star1 NFT",
        "STAR1",
        initialOwner,
        500e6,    // 500 USDC activation price
        250e6,    // 250 USDC OPS presale amount
        3,        // 3 reward levels
        _usdcToken,
        _usdtToken,
        _presaleContract
    ) {
        _mint(initialOwner, 1);  // 铸造 NFT ID 1
    }
} 
