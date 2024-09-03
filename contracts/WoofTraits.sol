// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;
import "./library/Strings.sol";
import "./library/Base64.sol";
import "./interfaces/ITraits.sol";
import "./interfaces/IWoof.sol";
import "./interfaces/IWoofConfig.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract WoofTraits is OwnableUpgradeable, ITraits {
    using Strings for uint256;
    using Base64 for bytes;

    IWoof public nft;
    IWoofConfig public config;

    function initialize() external initializer {
        __Ownable_init();
    }

    function setNft(address _nft) external onlyOwner {
        require(_nft != address(0));
        nft = IWoof(_nft);
    }

    function setConfig(address _config) external onlyOwner {
        require(_config != address(0));
        config = IWoofConfig(_config);
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        IWoof.WoofWoofWest memory w = nft.getTokenTraits(_tokenId);
        IWoofConfig.WoofWoofWestConfig memory woofConfig = config.getConfig(w.cid);
        string memory imageUrl = getImageUrl(w);
        string memory externalUrl = getExternalUrl(w);

        string memory metadata = string(abi.encodePacked(
            '{"name": "',
            w.name,
            ' #',
            _tokenId.toString(),
            '", "description": "Cats and dogs go wild in Woof Woof West! Miners, Bandits and Bounty Hunters fight hard to get tempting prizes, with deadly high stakes. All the metadata are generated and stored 100% on-chain.", ',
            imageUrl,
            ', ',
            externalUrl,
            ', "attributes":',
            compileAttributes(w, woofConfig),
            "}"
        ));

        return string(abi.encodePacked(
            "data:application/json;base64,",
            bytes(metadata).base64()
        ));
    }

    function getImageUrl(IWoof.WoofWoofWest memory _w) internal pure returns(string memory) {
        string memory ipfsHash = "QmZJEDEvDU1j9nAZfUJ8C6so1hySXDzNBaPDVVsVnaTArE";
        if (_w.cid == 42) {
            ipfsHash = "QmXtJWeFdrTvFbuaJZY7Dxn8DgE7APH7xQe4iR7HVekpDR";
        }
        return string(abi.encodePacked('"image": "https://woofwoofwest.mypinata.cloud/ipfs/',
            ipfsHash,
            '/',
            uint256(_w.quality).toString(),
            '_',
            uint256(_w.cid).toString(),
            '.png"'
        ));
    }

    function getExternalUrl(IWoof.WoofWoofWest memory _w) internal pure returns(string memory) {
        return string(abi.encodePacked('"external_url": "https://woofwoofwest.io/woof/',
            uint256(_w.quality).toString(),
            '_',
            uint256(_w.cid).toString(),
            '.png"'
        ));
    }

    function compileAttributes(IWoof.WoofWoofWest memory _w, IWoofConfig.WoofWoofWestConfig memory _woofConfig) internal pure returns (string memory) { 
        string memory traits;
        traits = string(abi.encodePacked(
            attributeForTypeAndValue("Generation", uint256(_w.generation).toString()),',',
            attributeForTypeAndValue("Type", typeString(_w.nftType)),',',
            attributeForTypeAndValue("Quality", qualityString(_w.quality)),',',
            attributeForTypeAndValue("Level", uint256(_w.level).toString()),',',
            attributesString(_w.attributes),',',
            attributeForTypeAndValue("Description", _woofConfig.des)
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

    function typeString(uint8 _nftType) internal pure returns (string memory) {
        if (_nftType == 0) {
            return "Miner";
        } else if (_nftType == 1) {
            return "Bandit";
        } else if (_nftType == 2) {
            return "Bounty Hunter";
        } else {
            return "Unknown";
        }
  }

    function attributesString(uint32[7] memory _attributes) public pure returns (string memory) {
        string memory s = string(
            abi.encodePacked(
                attributeForTypeAndValue("Stamina", uint256(_attributes[0]).toString()),',',
                attributeForTypeAndValue("Max Stamina", uint256(_attributes[1]).toString()),',',
                attributeForTypeAndValue("Earning Power", uint256(_attributes[2] + _attributes[3]).toString()),',',
                attributeForTypeAndValue("HP", uint256(_attributes[4]).toString()),',',
                attributeForTypeAndValue("Attack", uint256(_attributes[5]).toString()),',',
                attributeForTypeAndValue("Hit Rate", uint256(_attributes[6]).toString())
            )
        );
        return s;
    }
}