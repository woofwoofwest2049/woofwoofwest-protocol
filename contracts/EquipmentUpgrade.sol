// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./interfaces/IEquipment.sol";
import "./interfaces/ITraits.sol";
import "./library/SafeERC20.sol";
import "./library/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

interface ITreasury {
    function deposit(address _token, uint256 _amount) external;
}

interface IVestingPool {
    function balanceOf(address _user) external view returns(uint256);
    function transferFrom(address _from, address _to, uint256 _amount) external;
}

interface IRandomseeds {
    function randomseed(uint256 _seed) external view returns (uint256);
    function multiRandomSeeds(uint256 _seed, uint256 _count) external view returns (uint256[] memory);
}

contract EquipmentUpgrade is OwnableUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    event UpgradeEquipment(address indexed sender, IEquipment.sEquipment e);
    event UpgradeEquipmentToLevel(address indexed sender, IEquipment.sEquipment e, uint8 level);
    event UpgradeEquipmentQuality(address indexed sender, IEquipment.sEquipment e, bool success);

    IEquipmentEnumerable public equipment;
    ITreasury public treasury;
    IVestingPool public pawVestingPool;
    IVestingPool public gemVestingPool;
    IRandomseeds public randomseeds;
    address public gem;
    address public paw;
    uint8 public maxLevel;

    function initialize(
        address _equipment,
        address _treasury,
        address _pawVestingPool,
        address _gemVestingPool,
        address _paw,
        address _gem,
        address _randomseeds
    ) external initializer {
        require(_equipment != address(0));
        require(_treasury != address(0));
        require(_pawVestingPool != address(0));
        require(_gemVestingPool != address(0));
        require(_paw != address(0));
        require(_gem != address(0));
        require(_randomseeds != address(0));

        __Ownable_init();
        __Pausable_init();

        equipment = IEquipmentEnumerable(_equipment);
        treasury = ITreasury(_treasury);
        pawVestingPool = IVestingPool(_pawVestingPool);
        gemVestingPool = IVestingPool(_gemVestingPool);
        paw = _paw;
        gem = _gem;
        randomseeds = IRandomseeds(_randomseeds);
        maxLevel = 5;

        _safeApprove(_gem, _treasury);
        _safeApprove(_paw, _treasury);
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function setMaxLevel(uint8 _level) external onlyOwner {
        require(_level >= 5);
        maxLevel = _level;
    }

    function setGemVestingPool(address _pool) external onlyOwner {
        gemVestingPool = IVestingPool(_pool);
    }

    function setPawVestingPool(address _pool) external onlyOwner {
        pawVestingPool = IVestingPool(_pool);
    }

    function upgrade(uint32 _tokenId) external whenNotPaused {
        require(tx.origin == _msgSender(), "Not EOA");
        require(equipment.ownerOf(_tokenId) == _msgSender(), "Not owner");
        IEquipment.sEquipment memory e = equipment.getTokenTraits(_tokenId);
        require(e.level < maxLevel, "Reach the maximum level cap");
        IEquipmentConfig.sEquipmentLevelConfig memory curLevelConfig = equipment.getLevelConfig(e.eType, e.level);
        _upgradeCost(curLevelConfig.costToken, curLevelConfig.cost[e.quality]);
        e.level += 1;
        uint256[] memory seeds = randomseeds.multiRandomSeeds(block.difficulty + _tokenId, 3);
        e = equipment.randomEquipmentBattleAttributes(seeds[0], seeds[1], seeds[2], e);
        equipment.updateTokenTraits(e);
        emit UpgradeEquipment(_msgSender(), e);
    }

    function upgradeTo(uint32 _tokenId, uint8 _level) external whenNotPaused {
        require(tx.origin == _msgSender(), "Not EOA");
        require(equipment.ownerOf(_tokenId) == _msgSender(), "Not owner");
        IEquipment.sEquipment memory e = equipment.getTokenTraits(_tokenId);
        require(e.level < maxLevel, "Reach the maximum level cap");
        require(_level > e.level && _level <= maxLevel, "Invalid _level");
        uint256 pawCost = 0;
        uint256 gemCost = 0;
        for (uint8 i = e.level; i < _level; ++i) {
            IEquipmentConfig.sEquipmentLevelConfig memory lc = equipment.getLevelConfig(e.eType, i);
            if (lc.costToken == 0) {
                pawCost += lc.cost[e.quality];
            } else {
                gemCost += lc.cost[e.quality];
            }
        }
        _upgradeCost(0, pawCost);
        _upgradeCost(1, gemCost);
        e.level = _level;
        uint256[] memory seeds = randomseeds.multiRandomSeeds(block.difficulty + _tokenId, 3);
        e = equipment.randomEquipmentBattleAttributes(seeds[0], seeds[1], seeds[2], e);
        equipment.updateTokenTraits(e);
        emit UpgradeEquipmentToLevel(_msgSender(), e, _level);
    }

    function _upgradeCost(uint8 _costToken, uint256 _cost) internal {
        if (_cost == 0) {
            return;
        }

        if (_costToken == 0) {
            uint256 bal1 = IERC20(paw).balanceOf(_msgSender());
            uint256 bal2 = pawVestingPool.balanceOf(_msgSender());
            require(bal1 + bal2 >= _cost, "pawCost exceeds balance");
            if (bal2 >= _cost) {
                pawVestingPool.transferFrom(_msgSender(), address(this), _cost);
            } else {
                if (bal2  > 0) {
                    pawVestingPool.transferFrom(_msgSender(), address(this), bal2);
                }
                IERC20(paw).safeTransferFrom(_msgSender(), address(this), _cost - bal2);
            }
            treasury.deposit(paw, _cost);
        } else {
            uint256 bal1 = IERC20(gem).balanceOf(_msgSender());
            uint256 bal2 = gemVestingPool.balanceOf(_msgSender());
            require(bal1 + bal2 >= _cost, "gemCost exceeds balance");
            if (bal2 >= _cost) {
                gemVestingPool.transferFrom(_msgSender(), address(this), _cost);
            } else {
                if (bal2  > 0) {
                    gemVestingPool.transferFrom(_msgSender(), address(this), bal2);
                }
                IERC20(gem).safeTransferFrom(_msgSender(), address(this), _cost - bal2);
            }
            treasury.deposit(gem, _cost);
        }
    }

    function upgradeQuality(uint32 _tokenId, uint32[] memory _nftIds) external whenNotPaused {
        require(tx.origin == _msgSender(), "Not EOA");
        require(equipment.ownerOf(_tokenId) == _msgSender(), "Not owner");
        IEquipment.sEquipment memory e = equipment.getTokenTraits(_tokenId);
        require(e.level == maxLevel, "Not reach the maximum level cap");
        require(e.quality < 5, "Reach the maximum quality cap");
        for (uint32 i = 0; i < _nftIds.length; ++i) {
            require(equipment.ownerOf(_nftIds[i]) == _msgSender(), "Not owner");
            require(_nftIds[i] != _tokenId, "_nftIds[i]  == _tokenId");
        }
        IEquipmentConfig.sEquipmentQualityConfig memory config = equipment.getQualityConfig(e.quality);
        _upgradeQualityCost(config, _nftIds, e.eType);
        uint256[] memory seeds = randomseeds.multiRandomSeeds(block.difficulty + _tokenId, 4);
        bool success = false;
        if (seeds[0] % 100 < config.successProbability) {
            success = true;
            e.quality += 1;
            e.level = 1;
            e = equipment.randomEquipmentBattleAttributes(seeds[1], seeds[2], seeds[3], e);
            equipment.updateTokenTraits(e);
        }
        emit UpgradeEquipmentQuality(_msgSender(), e, success);        
    }

    function _upgradeQualityCost(IEquipmentConfig.sEquipmentQualityConfig memory _config, uint32[] memory _nftIds, uint16 _eType) internal {
        _upgradeCost(_config.costToken, _config.cost);
        for (uint8 i = 0; i < 5; ++i) {
            if (_config.nftCost[i] > 0) {
                uint8 count = 0;
                for (uint32 j = 0; j < _nftIds.length; ++j) {
                    IEquipment.sEquipment memory e = equipment.getTokenTraits(_nftIds[j]);
                    if (e.quality == i && e.level >= _config.nftRequiredLevel[i] && e.eType == _eType) {
                        count += 1;
                        equipment.burn(e.tokenId);
                    }
                    if (count == _config.nftCost[i]) {
                        break;
                    }
                }
                require(count == _config.nftCost[i], "Not enough consumption nfts");
            }
        }
    }

    function _safeApprove(address _token, address _spender) internal {
        if (_token != address(0) && IERC20(_token).allowance(address(this), _spender) == 0) {
            IERC20(_token).safeApprove(_spender, type(uint256).max);
        }
    }

    function randomseedTo(uint256 _seed, uint256 _r) public view returns(uint256) {
        uint256[] memory seeds = randomseeds.multiRandomSeeds(block.difficulty + _seed, 4);
        return seeds[0] % _r;
    }
}