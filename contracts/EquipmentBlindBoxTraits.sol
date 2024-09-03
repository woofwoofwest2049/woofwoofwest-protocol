// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;
import "./library/Strings.sol";
import "./library/Base64.sol";
import "./interfaces/ITraits.sol";
import "./interfaces/IEquipment.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract EquipmentBlindBoxTraits is OwnableUpgradeable, ITraits {
    using Strings for uint256;
    using Base64 for bytes;

    IEquipment public nft;
    string public ipfsHash;

    function initialize() external initializer {
        __Ownable_init();
        ipfsHash = "";
    }

    function setIpfsHash(string memory _hash) external onlyOwner {
        ipfsHash = _hash;
    }

    function setNft(address _nft) external onlyOwner {
        require(_nft != address(0));
        nft = IEquipment(_nft);
    }

    function tokenURI(uint256 _type) public view override returns (string memory) {
        IEquipmentConfig.sEquipmentBoxConfig memory eConfig = nft.getEquipmentBoxConfig(uint8(_type));
        string memory imageUrl = getImageUrl(eConfig);
        string memory externalUrl = getExternalUrl(eConfig);

        string memory metadata = string(abi.encodePacked(
            '{"name": "',
            eConfig.name,
            ' #',
            _type.toString(),
            '", "description": "Gear Mystery Box is a surprise box containing one unknown Gear to boost up the Battle Stats of your Miners, Bandits or Bounty Hunters in Woof Woof West. All the metadata are generated and stored 100% on chain.", ',
            imageUrl,
            ', ',
            externalUrl,
            ', "attributes":',
            compileAttributes(eConfig),
            "}"
        ));

        return string(abi.encodePacked(
            "data:application/json;base64,",
            bytes(metadata).base64()
        ));
    }

    function getImageUrl(IEquipmentConfig.sEquipmentBoxConfig memory _e) internal view returns(string memory) {
        return string(abi.encodePacked('"image": "https://woofwoofwest.mypinata.cloud/ipfs/',
            ipfsHash,
            '/equipmentBlindBox_',
            uint256(_e.eType).toString(),
            '.png"'
        ));
    }

    function getExternalUrl(IEquipmentConfig.sEquipmentBoxConfig memory _e) internal pure returns(string memory) {
        return string(abi.encodePacked('"external_url": "https://woofwoofwest.io/equipment/equipmentBlindBox_',
            uint256(_e.eType).toString(),
            '.png"'
        ));
    }

    function compileAttributes(IEquipmentConfig.sEquipmentBoxConfig memory _e) internal pure returns (string memory) { 
        string memory traits = string(abi.encodePacked(
            attributeForTypeAndValue("Type", uint256(_e.eType).toString()),',',
            attributeForTypeAndValue("Description", _e.des)
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