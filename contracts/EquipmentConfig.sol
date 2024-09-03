// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./interfaces/IEquipment.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract EquipmentConfig is OwnableUpgradeable, IEquipmentConfig {

    mapping(uint16 => sEquipmentConfig) public equipmentConfigs;
    mapping(uint8 => sEquipmentLevelConfig[]) public equipmentLevelConfigs;
    mapping(uint8 => sEquipmentBoxConfig) public equipmentBoxConfigs;
    sEquipmentQualityConfig[5] public equipmentQualityConfigs;
    uint16[][3] public mintCid;
    uint16[5] public qualityProbability;

    function initialize() external initializer {
        __Ownable_init();
        qualityProbability = [850,140,10,0,0];
        mintCid[0].push(1);
        mintCid[0].push(2);
        mintCid[0].push(3);
        mintCid[1].push(4);
        mintCid[1].push(5);
        mintCid[1].push(6);
        mintCid[2].push(7);
        mintCid[2].push(8);
        mintCid[2].push(9);
    }

    function setQualityProbability(uint16[5] memory _qualityProbability) external onlyOwner {
        require(_qualityProbability[0] + _qualityProbability[1] + _qualityProbability[2] + _qualityProbability[3] + _qualityProbability[4] == 1000);
        qualityProbability = _qualityProbability;
    }

    function setEquipmentConfig(sEquipmentConfig[] memory _configs) external onlyOwner {
        for (uint256 i = 0; i < _configs.length; ++i) {
            equipmentConfigs[_configs[i].cid] = _configs[i];
        }
    }

    function setEquipmentLevelConfig(sEquipmentLevelConfig[] memory _configs) external onlyOwner {
        delete equipmentLevelConfigs[0];
        delete equipmentLevelConfigs[1];
        delete equipmentLevelConfigs[2];
        for (uint256 i = 0; i < _configs.length; ++i) {
            equipmentLevelConfigs[_configs[i].eType].push(_configs[i]);
        }
    }

    function setEquipmentBoxConfig(sEquipmentBoxConfig[] memory _configs) external onlyOwner {
        for (uint256 i = 0; i < _configs.length; ++i) {
            equipmentBoxConfigs[_configs[i].eType] = _configs[i];
        }
    }

    function setQualityConfig(sEquipmentQualityConfig[5] memory _config) external onlyOwner {
        for (uint8 i = 0; i < 5; ++i) {
            equipmentQualityConfigs[i] = _config[i];
        }
    }

    function setMintCid(uint8 _eType, uint16[] memory _cid) external onlyOwner {
        require(_eType < 3);
        mintCid[_eType] = _cid;
    }

    
    function getConfig(uint16 _cid) external override view returns(sEquipmentConfig memory) {
        return equipmentConfigs[_cid];
    }

    function getLevelConfig(uint8 _type, uint8 _level) external override view returns(sEquipmentLevelConfig memory) {
        return equipmentLevelConfigs[_type][_level - 1];
    }

    function getEquipmentBoxConfig(uint8 _type) external override view returns(sEquipmentBoxConfig memory) {
        return equipmentBoxConfigs[_type];
    }

    function getQualityConfig(uint8 _quality) external override view returns(sEquipmentQualityConfig memory) {
        return equipmentQualityConfigs[_quality];
    }

    function randomEquipment(uint256[] memory _seeds, uint8 _type) external override view returns(IEquipment.sEquipment memory) {
        uint256 pos = _seeds[0] % mintCid[_type].length;
        uint16 cid = mintCid[_type][pos];
        IEquipment.sEquipment memory e;
        e.eType = _type;
        e.level = 1;
        e.cid = cid;
        e.quality = randomQuality(_seeds[1]);
        e = randomEquipmentBattleAttributes(_seeds[2], _seeds[3], _seeds[4], e);
        return e;
    }

    function randomQuality(uint256 _seed) public view returns(uint8) {
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
        return quality;
    }

    function randomEquipmentBattleAttributes(uint256 _hpSeed, uint256 _attackSeed, uint256 _hitRateSeed, IEquipment.sEquipment memory e) public override view returns(IEquipment.sEquipment memory) {
        sEquipmentLevelConfig memory eLevelConfig = equipmentLevelConfigs[e.eType][e.level - 1];
        e.hp = eLevelConfig.minHP[e.quality];
        e.attack = eLevelConfig.minAttack[e.quality];
        e.hitRate = eLevelConfig.minHitRate[e.quality];
        if (eLevelConfig.maxHP[e.quality] - eLevelConfig.minHP[e.quality] > 0) {
            e.hp += uint32(_hpSeed % (eLevelConfig.maxHP[e.quality] - eLevelConfig.minHP[e.quality]));
        }
        if (eLevelConfig.maxAttack[e.quality] - eLevelConfig.minAttack[e.quality] > 0) {
            e.attack += uint32(_attackSeed % (eLevelConfig.maxAttack[e.quality] - eLevelConfig.minAttack[e.quality]));
        }
        if (eLevelConfig.maxHitRate[e.quality] - eLevelConfig.minHitRate[e.quality] > 0) {
            e.hitRate += uint32(_hitRateSeed % (eLevelConfig.maxHitRate[e.quality] - eLevelConfig.minHitRate[e.quality]));
        }
        return e;
    }
}