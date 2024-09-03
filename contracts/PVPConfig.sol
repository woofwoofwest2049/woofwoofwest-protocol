// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./interfaces/IPVPConfig.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract PVPConfig is OwnableUpgradeable, IPVPConfig {

    mapping (uint32=>sPVPConfig) public configs;
    uint256 pvpCost;
    uint256 reedemCostOfPerPower;
    uint32 protectionPeriod;
    uint32 slaveTaxPercent;

    function initialize() external initializer {
        __Ownable_init();

        pvpCost = 200 ether;
        protectionPeriod = 12 hours;
        reedemCostOfPerPower = 3 ether;
        slaveTaxPercent = 20;
    }

    function setPVPCost(uint256 _cost) external onlyOwner {
        pvpCost = _cost;
    }

    function setProtectionPeriod(uint32 _period) external onlyOwner {
        protectionPeriod = _period;
    }

    function setReedemCostOfPerPower(uint256 _reedemCostOfPerPower) external onlyOwner {
        reedemCostOfPerPower = _reedemCostOfPerPower;
    }

    function setPVPConfig(sPVPConfig[20] memory _conifg) external onlyOwner {
        for (uint32 i = 0; i < _conifg.length; ++i) {
            configs[i+1] = _conifg[i];
        }
    }

    function setSlaveTaxPercent(uint32 _percent) external onlyOwner {
        require(_percent >= 10 && _percent <= 30);
        slaveTaxPercent = _percent;
    }

    function getPVPConfig(uint32 _level) external view override returns(sPVPConfig memory) {
        return configs[_level];
    }

    function getPVPCost() external view override returns(uint256) {
        return pvpCost;
    }

    function getReedemTax(uint256 _power) external view override returns(uint256) {
        return _power * reedemCostOfPerPower;
    }

    function getProtectionPeriod() external view override returns(uint32) {
        return protectionPeriod;
    }

    function getSlaveTax(uint256 _reward) external view override returns(uint256) {
        return slaveTaxPercent * _reward / 100;
    }

}