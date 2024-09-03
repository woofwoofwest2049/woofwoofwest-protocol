// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./interfaces/IWoofRentEnumerable.sol";
import "./interfaces/IExplore.sol";
import "./interfaces/IExploreConfig.sol";
import "./interfaces/IBaby.sol";
import "./interfaces/IWoofConfig.sol";
import "./interfaces/IPVP.sol";
import "./interfaces/IUserDashboard.sol";
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

interface IItem {
    function mint(address _account, uint256 _itemId, uint256 _amount) external;
}

interface IGemMintHelper {
    function mint(address _account, uint256 _amount) external;
    function gem() external view returns(address);
}

interface IPaw {
    function mint(address to, uint256 amount) external;
}

interface IEquipmentBlindBox {
    function mint(address _to, uint8 _type, uint8 _amount) external;
}

struct ExploreInfo {
    uint8 difficulty;
    uint16 exploreId;
    uint16 eventId;
    uint32 nftId;
    uint32 startTime;
    address owner;
}

contract Explore is IExplore, OwnableUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    event StartExplore(address indexed account, uint256 indexed nftId, uint256 indexed exploreId, uint8 difficulty, uint256 eventId);
    event EndExplore(address indexed account, uint256 indexed nftId, uint256 indexed recordId);

    IExploreConfig public eConfig;
    IWoofRentEnumerable public woof;
    ITreasury public treasury;
    IVestingPool public gemVestingPool;
    IVestingPool public pawVestingPool;
    IRandomseeds public randomseeds;
    IItem public item;
    IGemMintHelper public gemMintHelper;
    address public gem;
    address public paw;
    IBaby public baby;

    mapping (uint32=>ExploreInfo) nftIdToInfo;
    mapping (address=>uint32[]) userExploreNftIds;

    ExploreRecord[] public exploreRecords;
    mapping (uint32=>uint32[]) nftExploreRecords;

    uint32 public unitTime;

    IWoofConfig public woofConfig;
    IPVP public pvp;
    IEquipmentBlindBox public equipmentBlindBox;

    mapping(uint32 => uint32) public nftExploreCount;
    IUserDashboard public userDashboard;
    address public rentManager;

    function initialize(
        address _config,
        address _woof,
        address _treasury,
        address _pawVestingPool,
        address _gemVestingPool,
        address _randomseeds,
        address _item,
        address _gemMintHelper,
        address _paw,
        address _baby,
        address _woofConfig
    ) external initializer {
        require(_config != address(0));
        require(_woof != address(0));
        require(_treasury != address(0));
        require(_pawVestingPool != address(0));
        require(_gemVestingPool != address(0));
        require(_randomseeds != address(0));
        require(_item != address(0));
        require(_gemMintHelper != address(0));
        require(_paw != address(0));
        require(_baby != address(0));
        require(_woofConfig != address(0));

        __Ownable_init();
        __Pausable_init();

        eConfig = IExploreConfig(_config);
        woof = IWoofRentEnumerable(_woof);
        treasury = ITreasury(_treasury);
        pawVestingPool = IVestingPool(_pawVestingPool);
        gemVestingPool = IVestingPool(_gemVestingPool);
        randomseeds = IRandomseeds(_randomseeds);
        item = IItem(_item);
        gemMintHelper = IGemMintHelper(_gemMintHelper);
        gem = gemMintHelper.gem();
        paw = _paw;
        baby = IBaby(_baby);
        woofConfig = IWoofConfig(_woofConfig);
        unitTime = 3600;

        _safeApprove(gem, _treasury);
        _safeApprove(_paw, _treasury);
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function setUnitTime(uint32 _unitTime) external onlyOwner {
        unitTime = _unitTime;
    }

    function setPVP(address _pvp) external onlyOwner {
        pvp = IPVP(_pvp);
    }

    function setEquipmentBlindBox(address _euipmentBlindBox) external onlyOwner {
        equipmentBlindBox = IEquipmentBlindBox(_euipmentBlindBox);
    }

    function setExploreConfig(address _config) external onlyOwner {
        eConfig = IExploreConfig(_config);
    }

    function setUserDashboard(address _userDashboard) external onlyOwner {
        require(_userDashboard != address(0));
        userDashboard = IUserDashboard(_userDashboard);
    }

    function setRentManager(address _rentManager) external onlyOwner {
        require(_rentManager != address(0));
        rentManager = _rentManager;
    }

    function exploreConfig() public view returns(address) {
        return address(eConfig);
    }

    function setGemVestingPool(address _pool) external onlyOwner {
        gemVestingPool = IVestingPool(_pool);
    }

    function setPawVestingPool(address _pool) external onlyOwner {
        pawVestingPool = IVestingPool(_pool);
    }

    function startExplore(uint32 _nftId, uint16 _exploreId, uint8 _difficulty) public whenNotPaused {
        require(tx.origin == _msgSender(), "Not EOA");
        require(_difficulty <= 2, "Invalid difficulty");
        require(woof.ownerOf(_nftId) == _msgSender(), "Not Owner");
        IExploreConfig.ExploreConfig memory config = eConfig.getExploreConfig(_exploreId);
        require(config.cid == _exploreId, "Not exist explore id");
        IWoof.WoofWoofWest memory w = woof.getTokenTraits(_nftId);
        require(w.attributes[0] >= config.staminaCost, "Not enough stamina");
        require(w.quality >= config.minQuality, "Unsatisfactory quality");
        _exploreCost(config.costToken, config.cost[_difficulty]);
        woof.transferFrom(_msgSender(),  address(this),  _nftId);
        w.attributes[0] = w.attributes[0] - config.staminaCost;
        woof.updateTokenTraits(w);

        uint256[] memory seeds = randomseeds.multiRandomSeeds(block.timestamp + _nftId, 1);
        ExploreInfo memory info;
        info.difficulty = _difficulty;
        info.exploreId = _exploreId;
        info.eventId =  eConfig.randomEventId(_exploreId, _difficulty, seeds[0]);
        info.nftId = _nftId;
        info.owner = _msgSender();
        info.startTime = (uint32)(block.timestamp);
        nftIdToInfo[_nftId] = info;
        userExploreNftIds[_msgSender()].push(_nftId);
        emit StartExplore(_msgSender(), _nftId, _exploreId, _difficulty, info.eventId);
    }

    function endExplore(uint32 _nftId) public {
        require(tx.origin == _msgSender(), "Not EOA");
        _endExplore(_nftId, _msgSender());
        woof.transferFrom(address(this), _msgSender(), _nftId);
    }

    function _endExplore(uint32 _nftId, address _owner) internal {
        ExploreInfo memory info = nftIdToInfo[_nftId];
        require(info.nftId == _nftId, "Not explore nft");
        require(info.owner == _owner, "Not Owner");
        IExploreConfig.ExploreConfig memory config = eConfig.getExploreConfig(info.exploreId);
        IWoof.WoofWoofWest memory w = woof.getTokenTraits(_nftId);
        require(config.duration[w.level-1] *  unitTime + info.startTime <= block.timestamp, "Not over");
        uint256[] memory seeds = randomseeds.multiRandomSeeds(block.timestamp + _nftId, 5);
        IExploreConfig.ExporeEventConfig memory eEvent = eConfig.getExploreEventConfig(info.eventId);

        ExploreRecord memory record;
        record.exploreId = info.exploreId;
        record.eventId = eEvent.cid;
        record.nftId = _nftId;
        record.explorer = _owner;
        record.startTime = info.startTime;
        record.endTime = uint32(block.timestamp);
        uint256 power = woof.miningPowerOf(_nftId);
        uint32 exploreCount = nftExploreCount[_nftId];
        uint32 probabilityBufOfPower = eEvent.probabilityBufOfPower[exploreCount % eEvent.probabilityBufOfPower.length];
        uint256 probability = power * 10 / probabilityBufOfPower;
        probability = probability + eEvent.result1Probability;
        if (seeds[0] % 1000 < probability) {
            record.result = 1;
            record.pawRewardAmount = _randomReward(seeds[1], eEvent.pawRewardPerPowerOfResult1, power, eEvent.maxPawRewardOfResult1);
            record.gemRewardAmount = _randomReward(seeds[2], eEvent.gemRewardPerPowerOfResult1, power, eEvent.maxGemRewardOfResult1);
            record.dropItems = _dropItems(eEvent.dropItemProbabilityOfResult1, seeds[3], eEvent.dropItems);
            record.dropEquipmentBlindBox = _dropEquipmentBlindBox(eEvent.dropEquipBoxProbability, seeds[4]);
            if (eEvent.rewardBaby == true) {
                record.rewardBabyId = baby.mint(_owner, _nftId);
            }
        } else {
            record.result = 2;
            record.pawRewardAmount = _randomReward(seeds[1], eEvent.pawRewardPerPowerOfResult2, power, eEvent.maxPawRewardOfResult2);
            record.dropItems = _dropItems(eEvent.dropItemProbabilityOfResult2, seeds[2], eEvent.dropItems);
        }
        (record.pawRewardAmount, record.gemRewardAmount) = _paySlaveTax(_nftId, record.pawRewardAmount, record.gemRewardAmount);
        if (record.pawRewardAmount > 0) {
            IPaw(paw).mint(_owner, record.pawRewardAmount);
        }
        if (record.gemRewardAmount > 0) {
            gemMintHelper.mint(_owner, record.gemRewardAmount);
        }
        userDashboard.rewardFromScene(_owner, 4, record.pawRewardAmount, record.gemRewardAmount, 0);
        nftExploreCount[_nftId] += 1;
        exploreRecords.push(record);
        uint256 rid = exploreRecords.length - 1;
        nftExploreRecords[_nftId].push(uint32(rid));
        _removeUserNft(_owner, _nftId);
        delete nftIdToInfo[_nftId];
        emit EndExplore(_owner, _nftId, rid);
    }

    function unstake(uint32 _nftId, address _renter) public {
        require(_msgSender() == rentManager, "No auth");
        _endExplore(_nftId, _renter);
        woof.transferFrom(address(this), _msgSender(), _nftId);
    }

    function balanceOf(address _user) public view returns(uint256) {
        return userExploreNftIds[_user].length;
    }

    function ownerOf(uint32 _tokenId) public view returns(address) {
        return nftIdToInfo[_tokenId].owner;
    }

    struct ExploredNft {
        uint8 generation;
        uint8 nftType;  //0: Miner, 1: Bandit, 2: Hunter
        uint8 quality;
        uint8 level;
        uint16 cid;
        uint16 exploreId;
        uint16 eventId;
        uint32 stamina;
        uint32 maxStamina;
        uint32 tokenId;
        uint32 startTime;
        string name;
    }

    function getUserTokenTraits(address _user, uint256 _index, uint8 _len) public view returns(
        ExploredNft[] memory nfts, 
        uint8 len
    ) {
        require(_len <= 100 && _len != 0);
        nfts = new ExploredNft[](_len);
        len = 0;

        uint256 bal = balanceOf(_user);
        if (bal == 0 || _index >= bal) {
            return (nfts, len);
        }

        uint32[] memory userTokenIds = userExploreNftIds[_user];
        for (uint8 i = 0; i < _len; ++i) {
            uint32 tokenId = userTokenIds[_index];
            ExploreInfo memory info = nftIdToInfo[tokenId];
            ExploredNft memory exploredNft;
            exploredNft.tokenId = tokenId;
            IWoof.WoofWoofWest memory nft = woof.getTokenTraits(tokenId);
            exploredNft.generation = nft.generation;
            exploredNft.nftType = nft.nftType;
            exploredNft.quality = nft.quality;
            exploredNft.level = nft.level;
            exploredNft.cid = nft.cid;
            exploredNft.exploreId = info.exploreId;
            exploredNft.eventId = info.eventId;
            exploredNft.startTime = info.startTime;
            exploredNft.maxStamina = nft.attributes[1];
            exploredNft.name = nft.name;
            nfts[i] = exploredNft;
            ++_index;
            ++len;
            if (_index >= bal) {
                return (nfts, len);
            }
        }
    }

    function exploredBalanceOf(uint32 _nftId) public view returns(uint256) {
        return nftExploreRecords[_nftId].length;
    }

    function getNftExploredRecords(uint32 _nftId, uint256 _index, uint8 _len) public view returns(
        ExploreRecord[] memory records, 
        uint8 len
    ) {
        require(_len <= 100 && _len != 0);
        records = new ExploreRecord[](_len);
        len = 0;

        uint256 bal = exploredBalanceOf(_nftId);
        if (bal == 0 || _index >= bal) {
            return (records, len);
        }

        uint32[] memory recordIds = nftExploreRecords[_nftId];
        for (uint8 i = 0; i < _len; ++i) {
            uint32 recordId = recordIds[_index];
            records[i] = exploreRecords[recordId];
            ++_index;
            ++len;
            if (_index >= bal) {
                return (records, len);
            }
        }
    }

    function getLastNftExploreRecords(uint32 _nftId) external override view returns(ExploreRecord memory record, uint256 recordId) {
        if (exploredBalanceOf(_nftId) > 0) {
            uint32[] memory recordIds = nftExploreRecords[_nftId];
            recordId = recordIds[recordIds.length - 1];
            record = exploreRecords[recordId];
        }
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

    function _dropItems(uint8[4] memory _dropItemProbability, uint256 _seed, uint16[] memory _dropItemIds) internal returns(uint16[4] memory) {
        _seed = _seed % 100;
        uint256 count = 0;
        for (uint256 i = 0; i < 4; ++i) {
            if (_seed < _dropItemProbability[i]) {
                count = 4 - i;
                break;
            }
        }
        uint16[4] memory items;
        if (count > 0) {
            uint256[] memory seeds = randomseeds.multiRandomSeeds(_seed, count);
            for (uint256 i = 0; i < count; ++i) {
                uint16 itemId = _dropItemIds[seeds[i] % _dropItemIds.length];
                items[i] = itemId;
                item.mint(_msgSender(), itemId, 1);
            }
        }
        return items;
    }

    function _dropEquipmentBlindBox(uint8[3] memory _dropEquipBoxProbability, uint256 _seed) internal returns(uint16) {
        if (address(equipmentBlindBox) == address(0)) {
            return 255;
        }
        _seed = _seed % 100;
        for (uint8 i = 0; i < 3; ++i) {
            if (_seed < _dropEquipBoxProbability[i]) {
                equipmentBlindBox.mint(_msgSender(), i, 1);
                return i;
            }
        }
        return 255;
    }

    function _safeApprove(address _token, address _spender) internal {
        if (_token != address(0) && IERC20(_token).allowance(address(this), _spender) == 0) {
            IERC20(_token).safeApprove(_spender, type(uint256).max);
        }
    }

    function _removeUserNft(address _user, uint32 _tokenId) internal {
        uint32[] memory userStakedIds = userExploreNftIds[_user];
        for (uint256 i = 0; i < userStakedIds.length; ++i) {
            if (userStakedIds[i] == _tokenId) {
                uint32 lastId = userStakedIds[userStakedIds.length - 1];
                userExploreNftIds[_user][i] = lastId;
                userExploreNftIds[_user].pop();  
                break;
            }
        }

        if (userExploreNftIds[_user].length == 0) {
            delete userExploreNftIds[_user];
        }
    }

    function _paySlaveTax(uint32 _tokenId, uint256 _paw, uint256 _gem) internal returns(uint256, uint256) {
        if (address(pvp) != address(0)) {
            (uint256 pawTax, uint256 gemTax) = pvp.payTax(_tokenId, _paw, _gem);
            _paw -= pawTax;
            _gem -= gemTax;
        }
        return (_paw, _gem);
    }

    function _randomReward(uint256 _seed, uint256[2] memory _rewards, uint256 _power, uint256 _maxReward) internal pure returns(uint256) {
        uint256 gap = _rewards[1] - _rewards[0];
        if (gap == 0) {
            return 0;
        }

        uint256 reward = _power * (_rewards[0] + _seed % gap);
        if (reward > _maxReward) {
            reward = _maxReward;
        }
        return reward;
    }
}