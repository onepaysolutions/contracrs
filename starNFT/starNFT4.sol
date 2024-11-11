// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./StarNFTBase.sol";

contract Star4NFT is StarNFTBase {
    constructor(address initialOwner) 
        StarNFTBase(
            "Star4 NFT",
            "STAR4",
            initialOwner,
            7000e6,   // 7000 USDC activation price
            4450e6,   // 4450 USDC OPS presale amount
            20        // 20 reward levels
        ) {}
} 
