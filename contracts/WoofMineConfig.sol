// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./interfaces/IWoofMine.sol";
import "./interfaces/IWoofMineConfig.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IWoofMineMintHelper {
    function minted() external view returns(uint256 totalMinted, uint256[5] memory mintedOfQuality);
}

contract WoofMineConfig is IWoofMineConfig, OwnableUpgradeable {
    IWoofMineMintHelper public mintHelper;
    IWoofMine public woofMine;
    uint16[5] public qualityProbability;
    WoofWoofMineQualityConfig[5] public qualityConfig;
    WoofWoofMineLevelConfig[5] public levelConfig;
    uint256[5][5] public upgradePawCost;
    uint256[5][5] public upgradeGemCost;
    bool public strict;

    function initialize(
    ) external initializer {
        __Ownable_init();

        qualityProbability = [1000, 0, 0, 0, 0];
        strict = false;
    }

    function setQualityProbability(uint16[5] memory _qualityProbability) external onlyOwner {
        qualityProbability = _qualityProbability;
    }

    function setQualityConfig(WoofWoofMineQualityConfig[5] memory _config) external onlyOwner {
        for (uint8 i = 0; i < 5; ++i) {
            qualityConfig[i] = _config[i];
        }
    }

    function setLevelConfig(WoofWoofMineLevelConfig[5] memory _config) external onlyOwner {
        for (uint8 i = 0; i < 5; ++i) {
            _config[i].perPowerOutputPawOfSec = _config[i].perPowerOutputPawOfSec / 86400;
            _config[i].perPowerOutputGemOfSec = _config[i].perPowerOutputGemOfSec / 86400;
            levelConfig[i] = _config[i];
        }
    }

    function setUpgradeCost(uint256[5][5] memory _pawCost, uint256[5][5] memory _gemCost) external onlyOwner {
        upgradePawCost = _pawCost;
        upgradeGemCost = _gemCost;
    }

    function setMintHelper(address _woofMineMintHelper) external onlyOwner {
        require(_woofMineMintHelper != address(0));
        mintHelper = IWoofMineMintHelper(_woofMineMintHelper);
    }

    function setStrict(bool _strict) public onlyOwner {
        strict = _strict;
    }

    function setWoofMine(address _woofMine) external onlyOwner {
        require(_woofMine != address(0));
        woofMine = IWoofMine(_woofMine);
    }

    function getLevelConfig(uint8 _level) public override view returns (WoofWoofMineLevelConfig memory) {
        return levelConfig[_level-1];
    }

    function getQualityConfig(uint8 _quality) public override view returns (WoofWoofMineQualityConfig memory) {
        return qualityConfig[_quality];
    }

    function getLevelUpCost(uint8 _quality, uint8 _level) public override view returns(uint256 pawCost, uint256 gemCost) {
        pawCost = upgradePawCost[_quality][_level-1];
        gemCost = upgradeGemCost[_quality][_level-1];
    }

    function randomWoofWoofMine(uint256[] memory _seeds) public override view returns (IWoofMine.WoofWoofMine memory) {
        require(_seeds.length >= 1, "not enough seeds");
        uint8 quality = 0;
        WoofWoofMineQualityConfig memory qConfig = qualityConfig[quality];
        WoofWoofMineLevelConfig memory lConfig = getLevelConfig(1);
        IWoofMine.WoofWoofMine memory w;
        w.quality = quality;
        w.level = 1;
        w.staminaCostPerHourOfMiner = lConfig.staminaCostPerHourOfMiner;
        w.staminaCostPerHourOfHunter = lConfig.staminaCostPerHourOfHunter;
        w.staminaCostOfLoot = lConfig.staminaCostOfLoot;
        w.minerCapacity = lConfig.minerCapacity;
        w.requiredMinLevel = lConfig.requiredMinLevel;
        w.perPowerOutputGemOfSec = lConfig.perPowerOutputGemOfSec * qConfig.gemOutputBuf / 100;
        w.perPowerOutputPawOfSec = lConfig.perPowerOutputPawOfSec * qConfig.pawOutputBuf / 100;
        return w;
    }

    function upgradeWoofWoofMine(uint32 _tokenId) public override view returns(IWoofMine.WoofWoofMine memory w, uint256 pawCost, uint256 gemCost) {
        w = woofMine.getTokenTraits(_tokenId);
        require(w.level + 1 <= 5, "Invalid level");
        (pawCost, gemCost) = getLevelUpCost(w.quality, w.level);
        w.level += 1;
        WoofWoofMineQualityConfig memory qConfig = qualityConfig[w.quality];
        WoofWoofMineLevelConfig memory lConfig = getLevelConfig(w.level);
        w.staminaCostPerHourOfMiner = lConfig.staminaCostPerHourOfMiner;
        w.staminaCostPerHourOfHunter = lConfig.staminaCostPerHourOfHunter;
        w.staminaCostOfLoot = lConfig.staminaCostOfLoot;
        w.minerCapacity = lConfig.minerCapacity;
        w.requiredMinLevel = lConfig.requiredMinLevel;
        w.perPowerOutputGemOfSec = lConfig.perPowerOutputGemOfSec * qConfig.gemOutputBuf / 100;
        w.perPowerOutputPawOfSec = lConfig.perPowerOutputPawOfSec * qConfig.pawOutputBuf / 100;
    }

    function _randomQuality(uint256 _seed) internal view returns(uint8) {
        (uint256 totalMinted, uint256[5] memory mintedOfQuality) = mintHelper.minted();
        uint8 quality = 0;
        uint16 probability = 0;
        uint256 r = _seed % 1000;
        for (uint8 i = 0; i < 5; ++i) {
            probability += qualityProbability[i];
            if (r < probability) {
                quality = i;
                break;
            }
        }
        if (strict && quality > 0 && _mintProportion(totalMinted, mintedOfQuality[quality]) >= qualityProbability[quality]) {
            quality = 0;
        }
        return quality;
    }

    function _mintProportion(uint256 _totalMinted, uint256 _minted) internal pure returns(uint256) {
        if (_totalMinted == 0) {
            return 0;
        }
        return _minted * 1000 / _totalMinted;
    }
}