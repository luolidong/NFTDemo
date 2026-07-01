// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721URIStorageUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract NMTNFT is Initializable, UUPSUpgradeable, ERC721Upgradeable, ERC721URIStorageUpgradeable, OwnableUpgradeable {
    struct NMTNFTStorage {
        uint256 _tokenIdCounter;
    }

    function _getNMTNFTStorage() private pure returns (NMTNFTStorage storage $) {
        bytes32 slot = keccak256("NMTNFT.storage");
        assembly {
            $.slot := slot
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC721_init("NMTNFT", "NMT");
        __ERC721URIStorage_init();
        __Ownable_init(msg.sender);
    }

    function safeMint(address to, string memory uri) public onlyOwner {
        NMTNFTStorage storage $ = _getNMTNFTStorage();
        uint256 tokenId = $._tokenIdCounter++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function mint(address to, string memory uri) public onlyOwner {
        NMTNFTStorage storage $ = _getNMTNFTStorage();
        uint256 tokenId = $._tokenIdCounter++;
        _mint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {}
}