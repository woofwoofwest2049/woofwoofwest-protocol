// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

interface IExploreConfig {
    struct ExploreConfig {
        uint8[20] duration;
        uint8 costToken; //0: Paw,  1: Gem
        uint8 staminaCost;
        uint8 minQuality;
        uint16 cid;
        uint256[3] cost;
    }

    struct ExporeEventConfig {
        bool rewardBaby;
        uint8 difficulty;
        uint16 result1Probability;
        uint16 cid;
        uint16 parentId;
        uint16 partnerRewardId;
        uint8[4] dropItemProbabilityOfResult1;
        uint8[4] dropItemProbabilityOfResult2;
        uint8[3] dropEquipBoxProbability;
        uint16[2] addHp;
        uint16[2] addAttack;
        uint16[2] addHitRate;
        uint16[] dropItems;
        uint32[] probabilityBufOfPower;
        uint256 addBattleAttriCost;
        uint256 maxGemRewardOfResult1;
        uint256 maxPawRewardOfResult1;
        uint256 maxPawRewardOfResult2;
        uint256[2] gemRewardPerPowerOfResult1;
        uint256[2] pawRewardPerPowerOfResult1;
        uint256[2] pawRewardPerPowerOfResult2;
    }

    function getExploreConfig(uint256 _cid) external view returns(ExploreConfig memory config);
    function getExploreEventConfig(uint256 _eventId) external view returns(ExporeEventConfig memory config);
    function randomEventId(uint16 _exploreId, uint8 _difficulty, uint256 _seed) external view returns(uint16);
}