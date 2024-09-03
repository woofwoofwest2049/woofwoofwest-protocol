// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./interfaces/IExploreConfig.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract ExploreConfig is OwnableUpgradeable, IExploreConfig {

    mapping (uint256=>ExploreConfig) public exploreConfigs;
    mapping (uint256=>ExporeEventConfig) public exploreEventConfigs;
    mapping (uint256=>uint16[]) public exploreEventIds;

    function initialize() external initializer {
        __Ownable_init();
    }

    function setExploreConfig(ExploreConfig[] memory _config) public onlyOwner {
        for (uint256 i = 0; i < _config.length; ++i) {
            _config[i].cost[0] *= 1e18;
            _config[i].cost[1] *= 1e18;
            _config[i].cost[2] *= 1e18;
            exploreConfigs[_config[i].cid] = _config[i];
        }
    }

    function setExploreEventConfig(ExporeEventConfig[] memory _config) public onlyOwner {
        for (uint256 i = 0; i < _config.length; ++i) {
            uint256 key = eventKey(_config[i].parentId, _config[i].difficulty);
            delete exploreEventIds[key];
        }

        for (uint256 i = 0; i < _config.length; ++i) {
            uint256 key = eventKey(_config[i].parentId, _config[i].difficulty);
            exploreEventIds[key].push(_config[i].cid);
            _config[i].addBattleAttriCost *= 1e18;
            _config[i].maxGemRewardOfResult1 *= 1e18;
            _config[i].maxPawRewardOfResult1 *= 1e18;
            _config[i].maxPawRewardOfResult2 *= 1e18;
            exploreEventConfigs[_config[i].cid] = _config[i];
        }
    }

    function getExploreConfig(uint256 _cid) external override view returns(ExploreConfig memory config) {
        return exploreConfigs[_cid];
    }

    function getExploreEventConfig(uint256 _eventId) external override view returns(ExporeEventConfig memory config) {
        return exploreEventConfigs[_eventId];
    }

    function randomEventId(uint16 _exploreId, uint8 _difficulty, uint256 _seed) external override view returns(uint16) {
        uint256 key = eventKey(_exploreId, _difficulty);
        require(exploreEventIds[key].length > 0, "No event");
        uint256 pos = _seed % exploreEventIds[key].length;
        return exploreEventIds[key][pos];
    }

    function eventKey(uint16 _exploreId, uint8 _difficulty) public pure returns(uint256) {
        return _difficulty * 100 + _exploreId;
    }
}