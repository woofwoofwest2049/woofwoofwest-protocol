// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

interface IBabyConfig {
    struct ExploreBabyConfig {
        uint8 generation;
        uint16 maxRewardBabyAmount;
        uint16[5][5] woofRewardBabyProbability;
    }

    struct ExploreBabyQualityConfig {
        uint8[5] babyQualityProbability1;
        uint8[5] babyQualityProbability2;
        uint8[5] babyQualityProbability3;
        uint8[5] babyQualityProbability4;
        uint8[5] babyQualityProbability5;
        uint8[5] babyQualityProbability6;
    }

    struct BabyFeedConfig {
        uint16 cid;
        uint8[4] qualityProbability;
        uint8[5] qualityItemCostAmount;
        uint16[5] addBanditProbability;
        uint16[5] addHunterProbability;
        uint32[5] itemCost;
        uint256[5] qualityPawCost;
    }

    function getExploreBabyQualityConfig(uint8 _quality, uint32 _exploreCount) external view returns(uint8[5] memory);
    function getExploreBabyProbability(uint8 _gen, uint8 _quality, uint32 _exploreCount) external view returns(uint16 maxRewardBabyAmount_, uint16 probability_);
    function getBabyFeedConfig(uint16 _cid) external view returns(BabyFeedConfig memory);
}