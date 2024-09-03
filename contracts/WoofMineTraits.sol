// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;
import "./library/Strings.sol";
import "./library/Base64.sol";
import "./interfaces/ITraits.sol";
import "./interfaces/IWoofMine.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract WoofMineTraits is OwnableUpgradeable, ITraits {
    using Strings for uint256;
    using Base64 for bytes;

    IWoofMine public nft;

    function initialize() external initializer {
        __Ownable_init();
    }

    function setNft(address _nft) external onlyOwner {
        require(_nft != address(0));
        nft = IWoofMine(_nft);
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        IWoofMine.WoofWoofMine memory w = nft.getTokenTraits(_tokenId);
        string memory imageUrl = getImageUrl(w);
        string memory externalUrl = getExternalUrl(w);

        string memory metadata = string(abi.encodePacked(
            '{"name": "Private Mine #',
            _tokenId.toString(),
            '", "description": "Enjoy higher earnings with Private Mines! Make sure to safeguard it against robbery from Bandits! All the metadata are generated and stored 100% on-chain.", ',
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

    function compileAttributes(IWoofMine.WoofWoofMine memory _w) internal pure returns (string memory) { 
        string memory traits;
        traits = string(abi.encodePacked(
            attributeForTypeAndValue("Level", uint256(_w.level).toString())
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

    function getImageUrl(IWoofMine.WoofWoofMine memory _w) internal pure returns(string memory) {
        string memory ipfsHash = "QmUrpCoxf3Xks8NBXmBG29aJN8DGZGYQYiWtby9CFejkUH";
        return string(abi.encodePacked('"image": "https://woofwoofwest.mypinata.cloud/ipfs/',
            ipfsHash,
            '/privateMine',
            uint256(_w.level).toString(),
            '.png"'
        ));
    }

    function getExternalUrl(IWoofMine.WoofWoofMine memory _w) internal pure returns(string memory) {
        return string(abi.encodePacked('"external_url": "https://woofwoofwest.io/privateMine/',
            'privateMine',
            uint256(_w.level).toString(),
            '.png"'
        ));
    }
}