
// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./IWoof.sol";

interface IWoofConfig {
    struct WoofWoofWestConfig {
        uint8 nftType;  //0: Miner, 1: Bandit, 2: Hunter
        uint8 gender;   //0: Male, 1: Female
        uint8 race;     //0: Dog, 1: Cat
        uint16 cid;
        uint32 basicPower;
        string name;
        string des;
    }
    struct WoofWoofWestLevelConfig {
        uint32[5] minDynamicPower;
        uint32[5] maxDynamicPower;
        uint32 stamina;
        uint32 hp;
        uint32 attack;
        uint32 hitRate;
        uint32 maxHp;
        uint32 maxAttack;
        uint32 maxHitRate;
    }
    struct WoofWoofWestQualityConfig {
        uint8 maxLevelCap;
        uint16 basicPowerBuf;
        uint16 dynamicPowerBuf;
        uint16 battleBuf;
    }

    struct LevelUpCost {
        uint8[5] nftCost;
        uint256[3] pawCost;
    }

    function getConfig(uint16 _cid) external view returns (WoofWoofWestConfig memory);
    function getLevelConfig(uint8 _nftType, uint8 _level) external view returns(WoofWoofWestLevelConfig memory);
    function getLevelUpCost(uint8 _quality, uint8 _level) external view returns(LevelUpCost memory);
    function getQualityConfig(uint8 _quality) external view returns(WoofWoofWestQualityConfig memory);
    function stealInfoOfBandit(uint16 _level) external view returns (uint16 buf, uint16 index);
    function stealBufOfBandit() external view returns (uint16[] memory buf);
    function randomWoofWoofWest(uint256[] memory _seeds) external view returns (IWoof.WoofWoofWest memory);
    function randomWoofWoofWest(uint256[] memory _seeds, uint8 _nftType) external view returns(IWoof.WoofWoofWest memory);
    function randomWoofWoofWest(uint256[] memory _seeds, uint8 _nftType, uint8 _quality, uint8 _race, uint8 _gender) external view returns(IWoof.WoofWoofWest memory);
    function randomWoofWoofWest2(uint256[] memory _seeds, uint8 _quality) external view returns (IWoof.WoofWoofWest memory);
    function levelUpWoofWoofWest(uint32 _tokenId, uint256 _seed) external view returns(IWoof.WoofWoofWest memory w, LevelUpCost memory cost);
    function syntheticWoofWoofWest(uint32 _tokenId, uint256 _seed) external view returns(IWoof.WoofWoofWest memory w, LevelUpCost memory cost);
}


    