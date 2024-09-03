// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

interface IPVPConfig {
    struct sPVPConfig {
        uint16 staminaCost;
        uint32 countdown;
        uint32 maxSlaveCount;
        uint32 protectPeriod;
        uint32 percentOfPowerBuf;
    }

    function getPVPConfig(uint32 _level) external view returns(sPVPConfig memory);
    function getPVPCost() external view returns(uint256);
    function getReedemTax(uint256 _power) external view returns(uint256);
    function getProtectionPeriod() external view returns(uint32);
    function getSlaveTax(uint256 _reward) external view returns(uint256); 
}