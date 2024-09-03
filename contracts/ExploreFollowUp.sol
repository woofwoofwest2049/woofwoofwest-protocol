// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./interfaces/IWoofEnumerable.sol";
import "./interfaces/IExplore.sol";
import "./interfaces/IExploreConfig.sol";
import "./interfaces/IWoofConfig.sol";
import "./interfaces/IItem.sol";
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

contract ExploreFollowUp is OwnableUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    event AddBatttleAttributes(address indexed user, uint256 indexed nftId, IWoof.WoofWoofWest w);
    event UpdateBattleAttributes(address indexed user, uint32 indexed woofId, uint32 hp, uint32 attack, uint32 hitRate);

    IExplore public explore;
    IExploreConfig public exploreConfig;
    ITreasury public treasury;
    IWoofEnumerable public woof;
    IVestingPool public gemVestingPool;
    IVestingPool public pawVestingPool;
    IRandomseeds public randomseeds;
    IWoofConfig public woofConfig;
    address public gem;
    address public paw;

    mapping(uint32 => mapping(uint256 => bool)) public nftExploreFollowUp;
    address public item;

    function initialize(
        address _explore,
        address _eConfig,
        address _woof,
        address _treasury,
        address _pawVestingPool,
        address _gemVestingPool,
        address _randomseeds,
        address _woofConfig,
        address _paw,
        address _gem
    ) external initializer {
        require(_explore != address(0));
        require(_eConfig != address(0));
        require(_woof != address(0));
        require(_treasury != address(0));
        require(_pawVestingPool != address(0));
        require(_gemVestingPool != address(0));
        require(_randomseeds != address(0));
        require(_woofConfig != address(0));
        require(_paw != address(0));
        require(_gem != address(0));

        __Ownable_init();
        __Pausable_init();

        explore = IExplore(_explore);
        exploreConfig = IExploreConfig(_eConfig);
        woof = IWoofEnumerable(_woof);
        treasury = ITreasury(_treasury);
        pawVestingPool = IVestingPool(_pawVestingPool);
        gemVestingPool = IVestingPool(_gemVestingPool);
        randomseeds = IRandomseeds(_randomseeds);
        woofConfig = IWoofConfig(_woofConfig);
        paw = _paw;
        gem = _gem;

        _safeApprove(_paw, _treasury);
        _safeApprove(_gem, _treasury);
    }

    function setExploreConfig(address _config) external onlyOwner {
        exploreConfig = IExploreConfig(_config);
    }

    function setGemVestingPool(address _pool) external onlyOwner {
        gemVestingPool = IVestingPool(_pool);
    }

    function setPawVestingPool(address _pool) external onlyOwner {
        pawVestingPool = IVestingPool(_pool);
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }


    function setItem(address _item) external onlyOwner {
        require(_item != address(0));
        item = _item;
    }

    function addBatttleAttributes(uint32 _nftId) public whenNotPaused {
        require(tx.origin == _msgSender(), "Not EOA");
        require(woof.ownerOf(_nftId) == _msgSender(), "Not Owner");
        (IExplore.ExploreRecord memory record, uint256 recordId) = explore.getLastNftExploreRecords(_nftId);
        require(record.nftId == _nftId, "Invalid nftId");
        require(nftExploreFollowUp[_nftId][recordId] == false, "Exist explore record");
        nftExploreFollowUp[_nftId][recordId] = true;

        IExploreConfig.ExporeEventConfig memory eEvent = exploreConfig.getExploreEventConfig(record.eventId);
        _exploreCost(0, eEvent.addBattleAttriCost);
        uint256[] memory seeds = randomseeds.multiRandomSeeds(block.timestamp + recordId, 3);
        uint32 addHp = eEvent.addHp[0] + uint32(seeds[0] % (eEvent.addHp[1] - eEvent.addHp[0]));
        uint32 addAttack = eEvent.addAttack[0] + uint32(seeds[1] % (eEvent.addAttack[1] - eEvent.addAttack[0]));
        uint32 addHitRate = eEvent.addHitRate[0] + uint32(seeds[2] % (eEvent.addHitRate[1] - eEvent.addHitRate[0]));
        IWoof.WoofWoofWest memory w = woof.getTokenTraits(_nftId);
        IWoofConfig.WoofWoofWestLevelConfig memory wConfig = woofConfig.getLevelConfig(w.nftType, w.level);
        uint32 hp = addHp + w.attributes[4];
        uint32 attack = addAttack + w.attributes[5];
        uint32 hitRate = addHitRate + w.attributes[6];
        if (hp > wConfig.maxHp) {
            hp = wConfig.maxHp;
        }
        if (attack > wConfig.maxAttack) {
            attack = wConfig.maxAttack;
        }
        if (hitRate > wConfig.maxHitRate) {
            hitRate = wConfig.maxHitRate;
        }
        w.attributes[4] = hp;
        w.attributes[5] = attack;
        w.attributes[6] = hitRate;
        woof.updateTokenTraits(w);

        emit AddBatttleAttributes(_msgSender(), _nftId, w);
    }

    function _exploreCost(uint8 _costToken, uint256 _cost) internal {
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

    function _safeApprove(address _token, address _spender) internal {
        if (_token != address(0) && IERC20(_token).allowance(address(this), _spender) == 0) {
            IERC20(_token).safeApprove(_spender, type(uint256).max);
        }
    }

    function updateBattleAttributes(uint32 _tokenId, uint32[] memory _itemIds, uint32[] memory _amount) external whenNotPaused {
        require(tx.origin == _msgSender(), "Not EOA");
        require(woof.ownerOf(_tokenId) == _msgSender(), "Not owner");
        require(_itemIds.length <= 3 && _itemIds.length == _amount.length, "Invalid items");
        (uint32 addHp, uint32 addAttack, uint32 addHitRate) = _consumeBattleAttributesItem(_itemIds, _amount);
        IWoof.WoofWoofWest memory w = woof.getTokenTraits(_tokenId);
        IWoofConfig.WoofWoofWestLevelConfig memory wConfig = woofConfig.getLevelConfig(w.nftType, w.level);
        uint32 hp = addHp + w.attributes[4];
        uint32 attack = addAttack + w.attributes[5];
        uint32 hitRate = addHitRate + w.attributes[6];
        if (hp > wConfig.maxHp) {
            hp = wConfig.maxHp;
        }
        if (attack > wConfig.maxAttack) {
            attack = wConfig.maxAttack;
        }
        if (hitRate > wConfig.maxHitRate) {
            hitRate = wConfig.maxHitRate;
        }
        w.attributes[4] = hp;
        w.attributes[5] = attack;
        w.attributes[6] = hitRate;
        woof.updateTokenTraits(w);
        emit UpdateBattleAttributes(_msgSender(), _tokenId, hp, attack, hitRate);
    }

    function _consumeBattleAttributesItem(uint32[] memory _itemIds, uint32[] memory _amount) internal returns(uint32 addHp, uint32 addAttack, uint32 addHitRate) {
        addHp = 0;
        addAttack = 0;
        addHitRate = 0;
        for (uint32 i = 0; i < _itemIds.length; ++i) {
            if (_itemIds[i] == 0) {
                continue;
            }
            if (_amount[i] == 0) {
                continue;
            }
            IItem.ItemConfig memory itemConfig = IItem(item).getConfig(_itemIds[i]);
            require(itemConfig.itemId == _itemIds[i], "Invalid itemId");
            require(itemConfig.itemType == 1 || itemConfig.itemType == 2 || itemConfig.itemType == 3, "Invalid itemId");
            IItem(item).burn(_msgSender(), _itemIds[i], _amount[i]);
            if (itemConfig.itemType == 1) {
                addHp += itemConfig.value * _amount[i];
            } else if (itemConfig.itemType == 2) {
                addAttack += itemConfig.value * _amount[i];
            } else if (itemConfig.itemType == 3) {
                addHitRate += itemConfig.value * _amount[i];
            }
        }
    }
}