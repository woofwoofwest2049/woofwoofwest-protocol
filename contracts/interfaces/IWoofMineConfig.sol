
// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./IWoofMine.sol";

interface IWoofMineConfig {
    struct WoofWoofMineLevelConfig {
        uint8 staminaCostPerHourOfMiner;
        uint8 staminaCostPerHourOfHunter;
        uint8 staminaCostOfLoot;
        uint8 minerCapacity;
        uint8 requiredMinLevel;
        uint256 perPowerOutputGemOfSec;
        uint256 perPowerOutputPawOfSec;
    }
    struct WoofWoofMineQualityConfig {
        uint256 gemOutputBuf;
        uint256 pawOutputBuf;
    }
    function getLevelConfig(uint8 _level) external view returns (WoofWoofMineLevelConfig memory);
    function getQualityConfig(uint8 _quality) external view returns (WoofWoofMineQualityConfig memory);
    function getLevelUpCost(uint8 _quality, uint8 _level) external view returns(uint256 pawCost, uint256 gemCost);
    function randomWoofWoofMine(uint256[] memory _seeds) external view returns (IWoofMine.WoofWoofMine memory);
    function upgradeWoofWoofMine(uint32 _tokenId) external view returns(IWoofMine.WoofWoofMine memory w, uint256 pawCost, uint256 gemCost);
}