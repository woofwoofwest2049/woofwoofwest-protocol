// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;
import "./library/Strings.sol";
import "./library/Base64.sol";
import "./interfaces/ITraits.sol";
import "./interfaces/IEquipment.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract EquipmentTraits is OwnableUpgradeable, ITraits {
    using Strings for uint256;
    using Base64 for bytes;

    IEquipment public nft;
    string public ipfsHash;

    function initialize() external initializer {
        __Ownable_init();
        ipfsHash = "QmezmoQZDtc9NoGttVFTmRsTeJGmMfUzoPVyUg2P1Uz6Et";
    }

    function setIpfsHash(string memory _hash) external onlyOwner {
        ipfsHash = _hash;
    }

    function setNft(address _nft) external onlyOwner {
        require(_nft != address(0));
        nft = IEquipment(_nft);
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        IEquipment.sEquipment memory e = nft.getTokenTraits(_tokenId);
        IEquipmentConfig.sEquipmentConfig memory eConfig = nft.getConfig(e.cid);
        string memory imageUrl = getImageUrl(e);
        string memory externalUrl = getExternalUrl(e);

        string memory metadata = string(abi.encodePacked(
            '{"name": "',
            eConfig.name,
            ' #',
            _tokenId.toString(),
            '", "description": "Boost up the Battle Stats of your Miners, Bandits or Bounty Hunters in Woof Woof West with the Gears. All the metadata are generated and stored 100% on chain.", ',
            imageUrl,
            ', ',
            externalUrl,
            ', "attributes":',
            compileAttributes(e),
            "}"
        ));

        return string(abi.encodePacked(
            "data:application/json;base64,",
            bytes(metadata).base64()
        ));
    }

    function getImageUrl(IEquipment.sEquipment memory _e) internal view returns(string memory) {
        return string(abi.encodePacked('"image": "https://woofwoofwest.mypinata.cloud/ipfs/',
            ipfsHash,
            '/equipment_',
            uint256(_e.cid).toString(),
            '_',
            uint256(_e.quality).toString(),
            '.png"'
        ));
    }

    function getExternalUrl(IEquipment.sEquipment memory _e) internal pure returns(string memory) {
        return string(abi.encodePacked('"external_url": "https://woofwoofwest.io/equipment/equipment_',
            uint256(_e.cid).toString(),
            '_',
            uint256(_e.quality).toString(),
            '.png"'
        ));
    }

    function compileAttributes(IEquipment.sEquipment memory _e) internal pure returns (string memory) { 
        string memory traits;
        traits = string(abi.encodePacked(
            attributeForTypeAndValue("Level", uint256(_e.level).toString()),',',
            attributeForTypeAndValue("Type", uint256(_e.eType).toString()),',',
            attributeForTypeAndValue("HP", uint256(_e.hp).toString()),',',
            attributeForTypeAndValue("Attack", uint256(_e.attack).toString()),',',
            attributeForTypeAndValue("Hit Rate", uint256(_e.hitRate).toString())
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
}