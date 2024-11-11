// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract UserNFT is ERC721, ERC721Burnable, ERC721URIStorage, AccessControl {
    using Counters for Counters.Counter;
    using Strings for uint256;
    
    uint256 public constant COMMUNITY_USER = 1;
    uint256 public constant MARKET_USER = 2;

    struct UserInfo {
        address referrer;    
        string userId;       
        string zone;         
        uint256 mintTime;    
        bool isActive;       
        uint256 nftType;      
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    Counters.Counter private _tokenIds;

    string private _baseTokenURI;

    mapping(address => UserInfo) public userInfos;
    mapping(string => bool) public usedUserIds;
    mapping(address => bool) public hasNFT;

    event UserRegistered(
        address indexed user,
        address indexed referrer,
        uint256 nftType,
        string userId,
        string zone
    );
    event UserActivated(address indexed user);
    event ZoneChanged(address indexed user, string oldZone, string newZone);

    constructor(
        string memory name,
        string memory symbol,
        string memory baseTokenURI
    ) ERC721(name, symbol) {
        _baseTokenURI = baseTokenURI;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseTokenURI) external onlyRole(ADMIN_ROLE) {
        _baseTokenURI = baseTokenURI;
    }

    function register(
        address user,
        uint256 nftType,
        address referrer,
        string calldata userId,
        string calldata zone
    ) external onlyRole(ADMIN_ROLE) {
        require(!hasNFT[user], "User already registered");
        require(nftType == COMMUNITY_USER || nftType == MARKET_USER, "Invalid NFT type");
        require(!usedUserIds[userId], "UserId already used");
        require(
            keccak256(bytes(zone)) == keccak256(bytes("left")) ||
            keccak256(bytes(zone)) == keccak256(bytes("center")) ||
            keccak256(bytes(zone)) == keccak256(bytes("right")),
            "Invalid zone value"
        );

        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();

        userInfos[user] = UserInfo({
            referrer: referrer,
            userId: userId,
            zone: zone,
            mintTime: block.timestamp,
            isActive: false,
            nftType: nftType
        });

        usedUserIds[userId] = true;
        hasNFT[user] = true;

        _safeMint(user, tokenId);

        emit UserRegistered(user, referrer, nftType, userId, zone);
    }

    function activate(address user) external onlyRole(ADMIN_ROLE) {
        require(hasNFT[user], "User not registered");
        require(!userInfos[user].isActive, "User already activated");

        userInfos[user].isActive = true;
        emit UserActivated(user);
    }

    function changeZone(address user, string calldata newZone) external {
        require(msg.sender == user, "Not authorized");
        require(hasNFT[user], "User not registered");
        require(
            keccak256(bytes(newZone)) == keccak256(bytes("left")) ||
            keccak256(bytes(newZone)) == keccak256(bytes("center")) ||
            keccak256(bytes(newZone)) == keccak256(bytes("right")),
            "Invalid zone value"
        );

        string memory oldZone = userInfos[user].zone;
        userInfos[user].zone = newZone;

        emit ZoneChanged(user, oldZone, newZone);
    }

    function getUserInfo(
        address user
    ) external view returns (
        address referrer,
        string memory userId,
        string memory zone,
        uint256 mintTime,
        bool isActive,
        uint256 nftType
    ) {
        require(hasNFT[user], "User not registered");
        UserInfo storage info = userInfos[user];
        return (
            info.referrer,
            info.userId,
            info.zone,
            info.mintTime,
            info.isActive,
            info.nftType
        );
    }

    function isRegistered(address user) external view returns (bool) {
        return hasNFT[user];
    }

    function isUserIdUsed(string calldata userId) external view returns (bool) {
        return usedUserIds[userId];
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }


    function burnUserNFT(address user) external onlyRole(ADMIN_ROLE) {
        require(hasNFT[user], "User not registered");
        uint256 tokenId = 0;
        
        for(uint256 i = 1; i <= _tokenIds.current(); i++) {
            if(_exists(i) && ownerOf(i) == user) {
                tokenId = i;
                break;
            }
        }
        
        require(tokenId != 0, "Token not found");
        
        delete userInfos[user];
        delete hasNFT[user];
        delete usedUserIds[userInfos[user].userId];
        
        _burn(tokenId);
    }
}
