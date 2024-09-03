// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

interface IWoofMine {
    struct WoofWoofMine {
        uint8 quality;
        uint8 level;
        uint8 staminaCostPerHourOfMiner;
        uint8 staminaCostPerHourOfHunter;
        uint8 staminaCostOfLoot;
        uint8 minerCapacity;
        uint8 requiredMinLevel;
        uint32 tokenId;
        uint256 perPowerOutputGemOfSec;
        uint256 perPowerOutputPawOfSec;
    }
    function mint(address _user, WoofWoofMine memory _w) external;
    function updateTokenTraits(WoofWoofMine memory _w) external;
    function getTokenTraits(uint256 _tokenId) external view returns (WoofWoofMine memory);
}