// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;
import "./library/Strings.sol";
import "./library/Base64.sol";
import "./interfaces/ITraits.sol";
import "./interfaces/IBaby.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract BabyTraits is OwnableUpgradeable, ITraits {
    using Strings for uint256;
    using Base64 for bytes;

    IBaby public nft;
    function initialize() external initializer {
        __Ownable_init();
    }

    function setNft(address _nft) external onlyOwner {
        require(_nft != address(0));
        nft = IBaby(_nft);
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        IBaby.WoofBaby memory w = nft.getTokenTraits(_tokenId);
        string memory imageUrl = getImageUrl(w);
        string memory externalUrl = getExternalUrl(w);

        string memory metadata = string(abi.encodePacked(
            '{"name": "Fur Baby #',
            _tokenId.toString(),
            '", "description": "Raise your little fur baby with love and care! All the metadata are generated and stored 100% on-chain.", ',
            imageUrl,
            ', ',
            externalUrl,
            ', "attributes":',
            compileAttributes(w),
            "}"
        ));

        return string(abi.encodePacked(
            "data:application/json;base64,",
            bytes(metadata).base64()
        ));
    }

    function getImageUrl(IBaby.WoofBaby memory _w) internal pure returns(string memory) {
        string memory ipfsHash = "QmeWdWC2WF4heVGJ3eSjzozzrKVt3GrQTjm3KHRwtRJENi";
        return string(abi.encodePacked('"image": "https://woofwoofwest.mypinata.cloud/ipfs/',
            ipfsHash,
            '/baby_',
            uint256(_w.race).toString(),
            '_',
            uint256(_w.gender).toString(),
            '.png"'
        ));
    }

    function getExternalUrl(IBaby.WoofBaby memory _w) internal pure returns(string memory) {
        return string(abi.encodePacked('"external_url": "https://woofwoofwest.io/baby/baby_',
            uint256(_w.race).toString(),
            '_',
            uint256(_w.gender).toString(),
            '.png"'
        ));
    }

    function compileAttributes(IBaby.WoofBaby memory _w) internal pure returns (string memory) { 
        string memory traits;
        traits = string(abi.encodePacked(
            attributeForTypeAndValue("Quality", qualityString(_w.quality))
        ));
    
        return string(abi.encodePacked(
            '[',
            traits,
            ']'
        ));
    }

    function attributeForTypeAndValue(string memory _traitType, string memory _value) internal pure returns (string memory) {
        return string(abi.encodePacked(
            '{"trait_type":"',
            _traitType,
            '","value":"',
            _value,
            '"}'
        ));
    }

    function qualityString(uint8 _quality) internal pure returns (string memory) {
        if (_quality == 0) {
            return "Common";
        } else if (_quality == 1) {
            return "Rare";
        } else if (_quality == 2) {
            return "Epic";
        } else if (_quality == 3) {
            return "Legendary";
        } else {
            return "Mythic";
        }
    }
}