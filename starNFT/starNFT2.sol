// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./StarNFTBase.sol";

contract Star2NFT is StarNFTBase {
    constructor(address initialOwner) 
        StarNFTBase(
            "Star2 NFT",
            "STAR2",
            initialOwner,
            1000e6,   // 1000 USDC activation price
            550e6,    // 550 USDC OPS presale amount
            8         // 8 reward levels
        ) {}
} 
