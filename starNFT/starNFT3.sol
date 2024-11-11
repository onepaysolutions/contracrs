// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./StarNFTBase.sol";

contract Star3NFT is StarNFTBase {
    constructor(address initialOwner) 
        StarNFTBase(
            "Star3 NFT",
            "STAR3",
            initialOwner,
            3000e6,   // 3000 USDC activation price
            1800e6,   // 1800 USDC OPS presale amount
            13        // 13 reward levels
        ) {}
} 
