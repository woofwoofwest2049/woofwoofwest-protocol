// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

interface IWoof {
    struct WoofWoofWest {
        uint8 generation;
        uint8 nftType;  //0: Miner, 1: Bandit, 2: Hunter
        uint8 gender;   //0: Male, 1: Female
        uint8 race;     //0: Dog, 1: Cat
        uint8 quality;
        uint8 level;
        uint16 cid; 
        uint32[7] attributes; //0: stamina，1: max stamina, 2: mining basic power，3: mining dynamic power, 4: hp, 5: attack, 6: hit rate
        uint32 slavesPower; 
        uint32 tokenId;
        string name;
    }

    function mint(address _user, WoofWoofWest memory _w) external;
    function batchMint(address _user, WoofWoofWest[10] memory _w) external;
    function getTokenTraits(uint256 _tokenId) external view returns (WoofWoofWest memory);
    function balanceOfType(uint256 _type) external view returns(uint256);
    function tokenOfTypeByIndex(uint256 _type, uint256 _index) external view returns(uint256);
    function dividendU(uint256 _amount) external;
    function claimU(uint256 _tokenId) external;
    function pendingU(uint256 _tokenId) external view returns(uint256);
    function miningPowerOf(WoofWoofWest memory _w) external pure returns(uint32);
    function miningPowerOf(uint256 _tokenId) external view returns(uint32);
    function updateTokenTraits(WoofWoofWest memory _w) external;
    function updateStamina(uint256 _tokenId, uint32 _stamina) external;
    function updateName(uint256 _tokenId, string memory _name) external;
    function burn(uint256 _tokenId) external;
    function ownerOf2(uint256 _tokenId) external view returns(address);
    function getBattleAttributes(uint256 _tokenId) external view returns(uint32[4] memory attr /*0: hp, 1: attack, 2: hitRate, 3: equipmentHitRate*/);
    function addSlavePower(uint32 _tokenId, uint32 _power) external;
    function delSlavePower(uint32 _tokenId, uint32 _power) external;
}
