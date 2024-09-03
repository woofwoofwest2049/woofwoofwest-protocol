// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./interfaces/IBabyConfig.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract BabyConfig is OwnableUpgradeable, IBabyConfig {
    ExploreBabyConfig[3] public exploreBabyConfig;
    mapping(uint16 => BabyFeedConfig) public babyFeedConfig;
    ExploreBabyQualityConfig[5] private _exploreBabyQuality;

    function initialize() external initializer {
        __Ownable_init();
    }

    function setExploreBabyConfig(ExploreBabyConfig[3] memory _config) external onlyOwner {
        for (uint8 i = 0; i < 3; ++i) { 
            exploreBabyConfig[i] = _config[i];
        }
    }

    function setExploreBabyQuality(ExploreBabyQualityConfig[5] memory _config) external onlyOwner {
        for (uint256 i = 0; i < 5; ++i) {
            _exploreBabyQuality[i] = _config[i];
        }
    }

    function setBabyFeedConfig(BabyFeedConfig[] memory _config) external onlyOwner {
        for (uint256 i = 0; i < _config.length; ++i) {
            babyFeedConfig[_config[i].cid] = _config[i];
        }
    }

    function getExploreBabyProbability(uint8 _gen, uint8 _quality, uint32 _exploreCount) override external view returns(uint16 maxRewardBabyAmount_, uint16 probability_) {
        ExploreBabyConfig memory config = exploreBabyConfig[_gen];
        if (_exploreCount >= 5) {
            _exploreCount = 4;
        }

        maxRewardBabyAmount_ = config.maxRewardBabyAmount;
        probability_ = config.woofRewardBabyProbability[_quality][_exploreCount];
    }

    function getExploreBabyQualityConfig(uint8 _quality, uint32 _exploreCount) override external view returns(uint8[5] memory) {
        ExploreBabyQualityConfig memory config = _exploreBabyQuality[_quality];
        if (_exploreCount == 0) {
            return config.babyQualityProbability1;
        } else if (_exploreCount == 1) {
            return config.babyQualityProbability2;
        } else if (_exploreCount == 2) {
            return config.babyQualityProbability3;
        } else if (_exploreCount == 3) {
            return config.babyQualityProbability4;
        } else if (_exploreCount == 4) {
            return config.babyQualityProbability5;
        } else {
            return config.babyQualityProbability6;
        }
    }

    function getBabyFeedConfig(uint16 _cid) override external view returns(BabyFeedConfig memory) {
        return babyFeedConfig[_cid];
    }
}