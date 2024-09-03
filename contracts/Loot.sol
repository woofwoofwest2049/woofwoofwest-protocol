// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./interfaces/IUserDashboard.sol";
import "./library/SafeERC20.sol";
import "./library/SafeMath.sol";
import "./interfaces/IWoofMineEnumerable.sol";
import "./interfaces/IWoofEnumerable.sol";
import "./interfaces/IPVP.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

interface IWoofMinePool  {
    function staminaCostOfLoot(uint32 _tokenId) external view returns(uint8);
    function loot(uint32 _banditId, uint32 _tokenId, uint8 _percent) external returns(
        bool success,
        uint256 lootPawAmount, 
        uint256 lootGemAmount
    );
}

interface IWanted {
    function payForHunter(address _user, uint32 _tokenId, uint256 _pawAmount, uint256 _gemAmount, bool _escape) external returns(
        uint256 taxPawAmount, 
        uint256 taxGemAmount
    );
}

contract Loot is OwnableUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    event LootMine(
        address indexed account, 
        uint256 indexed banditId, 
        uint256 indexed mineId, 
        uint256 pawRewards, 
        uint256 gemRewards,
        bool success
    );

    event Claim(address indexed account, uint256 indexed banditId, uint256 pawRewards, uint256 gemRewards, uint256 taxPawAmount, uint256 taxGemAmount);

    IWoofEnumerable public woof;
    IWoofMineEnumerable public woofMine;
    IWoofMinePool public woofMinePool;
    IWanted public wanted;
    address public paw;
    address public gem;

    struct LootInfo {
        uint8 dailyLootCount;
        uint32 dailyLootStartTime;
    }

    struct LootVesting {
        uint32 lastClaimTime;
        uint256 pendingPaw;
        uint256 rewardPaidPaw;
        uint256 pendingGem;
        uint256 rewardPaidGem;
    }

    struct LootRecord {
        bool success;
        uint32 mineId;
        uint32 banditId;
        uint32 lootTime;
        uint256 pawRewards;
        uint256 gemRewards;
    }

    mapping (uint32=>LootInfo) public lootInfoOfMine;
    mapping (uint32=>LootInfo) public lootInfoOfBandit;
    mapping (uint32=>LootVesting) public lootVesting;
    LootRecord[] public lootRecords;
    mapping (uint32=>uint32[]) public banditLootRecords;
    mapping (uint32=>uint32[]) public mineLootedRecords;
    uint8[3] public lootPercent;
    uint8[20] public lootMaxCountOfLevel;

    uint8 public maxPerAmount;
    uint256 public perPowerMaxClaimPawAmount;
    uint256 public perPowerMaxClaimGemAmount;

    uint32 public claimCD;
    uint32 public lootCD;

    IPVP public pvp;
    IUserDashboard public userDashboard;

    function initialize(
        address _woof,
        address _woofMine,
        address _woofMinePool,
        address _paw,
        address _gem,
        address _wanted
    ) external initializer {
        require(_woof != address(0));
        require(_woofMine != address(0));
        require(_woofMinePool != address(0));
        require(_paw != address(0));
        require(_gem != address(0));
        require(_wanted != address(0));

        __Ownable_init();
        __Pausable_init();

        woof = IWoofEnumerable(_woof);
        woofMine = IWoofMineEnumerable(_woofMine);
        woofMinePool = IWoofMinePool(_woofMinePool);
        paw = _paw;
        gem = _gem;
        wanted = IWanted(_wanted);
        lootPercent = [33, 25, 20];
        lootMaxCountOfLevel = [6,6,6,6,7,7,7,7,8,8,8,8,9,9,9,9,10,10,10,10];
        maxPerAmount = 10;

        _safeApprove(_paw, _wanted);
        _safeApprove(_gem, _wanted);

        perPowerMaxClaimPawAmount = 3 ether;
        perPowerMaxClaimGemAmount = 5e15;

        claimCD = 1 days;
        lootCD = 1 days;
    }

    function setLootPercent(uint8[3] memory _lootPercent) public onlyOwner {
        lootPercent = _lootPercent;
    }

    function setLootMaxCountOfLevel(uint8[20] memory _count) public  onlyOwner {
        lootMaxCountOfLevel = _count;
    }

    function setMaxPerAmount(uint8 _amount) external onlyOwner {
        require(_amount >= 10 && _amount <= 100);
        maxPerAmount = _amount;
    }

    function setPerPowerMaxClaimPawAmount(uint256 _amount) external onlyOwner  {
        perPowerMaxClaimPawAmount = _amount;
    }

    function setPerPowerMaxClaimGemAmount(uint256 _amount) external onlyOwner  {
        perPowerMaxClaimGemAmount = _amount;
    }

    function setClaimCD(uint32 _cd) external onlyOwner {
        claimCD = _cd;
    }

    function setLootCD(uint32 _cd) external onlyOwner {
        lootCD = _cd;
    }

    function setPVP(address _pvp) external onlyOwner {
        pvp = IPVP(_pvp);
    }

    function setUserDashboard(address _userDashboard) external onlyOwner {
        require(_userDashboard != address(0));
        userDashboard = IUserDashboard(_userDashboard);
    }

    function banditLootCount(uint32 _tokenId) public view returns(uint256) {
        return banditLootRecords[_tokenId].length;
    }

    function mineLootedCount(uint32 _tokenId) public view returns(uint256) {
        return mineLootedRecords[_tokenId].length;
    }

    function lootRecordsLength() public view returns(uint256) {
        return lootRecords.length;
    }

    function banditLootBrief(uint32 _tokenId, uint8 _level) public view returns(
        uint32 totalLootCount, 
        uint8 dailyLootCount, 
        uint8 maxDailyLootCount
    ) {
        totalLootCount = uint32(banditLootCount(_tokenId));
        dailyLootCount = lootInfoOfBandit[_tokenId].dailyLootCount;
        if (lootInfoOfBandit[_tokenId].dailyLootStartTime + lootCD <= block.timestamp) {
            dailyLootCount = 0;
        }
        maxDailyLootCount = lootMaxCountOfLevel[_level - 1];
    }

    function mineLootBrief(uint32 _tokenId) public view returns(uint32 totalLootCount, uint8 dailyLootCount) {
        totalLootCount = uint32(mineLootedCount(_tokenId));
        dailyLootCount = lootInfoOfMine[_tokenId].dailyLootCount;
        if (lootInfoOfMine[_tokenId].dailyLootStartTime + lootCD <= block.timestamp) {
            dailyLootCount = 0;
        }
    }

    function banditLootVesting(uint32 _tokenId) public view returns(
        uint32 lastClaimTime,
        uint256 pendingPaw,
        uint256 pendingGem,
        uint256 claimablePaw,
        uint256 claimableGem
    )  {
        LootVesting memory vesting = lootVesting[_tokenId];
        lastClaimTime = vesting.lastClaimTime;
        pendingPaw = vesting.pendingPaw;
        pendingGem = vesting.pendingGem;
        uint32 power = woof.miningPowerOf(_tokenId);
        claimablePaw = power * perPowerMaxClaimPawAmount;
        claimableGem = power * perPowerMaxClaimGemAmount;
        if (lastClaimTime + claimCD < block.timestamp) {
            claimablePaw = claimablePaw.min(pendingPaw);
            claimableGem = claimableGem.min(pendingGem);
        } else {
            claimablePaw = claimablePaw.sub(vesting.rewardPaidPaw);
            claimableGem = claimableGem.sub(vesting.rewardPaidGem);
            claimablePaw = claimablePaw.min(pendingPaw);
            claimableGem = claimableGem.min(pendingGem);
        }
    } 

    struct Bandit {
        uint8 quality;
        uint8 level;
        uint16 cid;
        string name;
    }

    struct Mine {
        uint8 quality;
        uint8 level;
    }

    struct BanditLootRecord {
        LootRecord record;
        Mine mine;
    }

    struct MineLootedRecord {
        LootRecord record;
        Bandit bandit;
    }

    function banditLootRecordByIndex(uint256 _index) public view returns(BanditLootRecord memory) {
        LootRecord memory record = lootRecords[_index];
        BanditLootRecord memory banditRecord;
        banditRecord.record = record;
        IWoofMine.WoofWoofMine memory w = woofMine.getTokenTraits(record.mineId);
        banditRecord.mine.quality = w.quality;
        banditRecord.mine.level = w.level;
        return banditRecord;
    }

    function mineLootedRecordByIndex(uint256 _index) public view returns(MineLootedRecord memory) {
        LootRecord memory record = lootRecords[_index];
        MineLootedRecord memory mineRecord;
        mineRecord.record = record;
        IWoof.WoofWoofWest memory ww = woof.getTokenTraits(record.banditId);
        mineRecord.bandit.quality = ww.quality;
        mineRecord.bandit.level = ww.level;
        mineRecord.bandit.cid = ww.cid;
        mineRecord.bandit.name = ww.name;
        return mineRecord;
    }

    function getBanditLootRecords(uint32 _tokenId, uint256 _index, uint8 _len, uint8 _sort) public view returns(
        BanditLootRecord[] memory nfts, 
        uint8 len
    ) {
        require(_len <= maxPerAmount && _len != 0);
        nfts = new BanditLootRecord[](_len);
        len = 0;

        uint256 bal = banditLootRecords[_tokenId].length;
        if (bal == 0 || _index >= bal) {
            return (nfts, len);
        }

        for (uint8 i = 0; i < _len; ++i) {
            uint256 index = (_sort == 0) ? _index : (bal - _index - 1);
            uint256 recordId = banditLootRecords[_tokenId][index];
            nfts[i] = banditLootRecordByIndex(recordId);
            ++_index;
            ++len;
            if (_index >= bal) {
                return (nfts, len);
            }
        }
    }

    function getMineLootedRecords(uint32 _tokenId, uint256 _index, uint8 _len, uint8 _sort) public view returns(
        MineLootedRecord[] memory nfts, 
        uint8 len
    ) {
        require(_len <= maxPerAmount && _len != 0);
        nfts = new MineLootedRecord[](_len);
        len = 0;

        uint256 bal = mineLootedRecords[_tokenId].length;
        if (bal == 0 || _index >= bal) {
            return (nfts, len);
        }

        for (uint8 i = 0; i < _len; ++i) {
            uint256 index = (_sort == 0) ? _index : (bal - _index - 1);
            uint256 recordId = mineLootedRecords[_tokenId][index];
            nfts[i] = mineLootedRecordByIndex(recordId);
            ++_index;
            ++len;
            if (_index >= bal) {
                return (nfts, len);
            }
        }
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function lootMine(uint32 _banditId, uint32 _mineId) external whenNotPaused {
        require(tx.origin == _msgSender(), "Not EOA");
        _check(_banditId, _mineId);
        uint8 percent = lootPercent[lootInfoOfMine[_mineId].dailyLootCount - 1];
        (bool success, uint256 lootPawAmount, uint256 lootGemAmount) = woofMinePool.loot(_banditId, _mineId, percent);
        LootRecord memory record;
        record.success = success;
        record.mineId = _mineId;
        record.banditId = _banditId;
        record.lootTime = uint32(block.timestamp);
        record.pawRewards = lootPawAmount;
        record.gemRewards = lootGemAmount;
        lootRecords.push(record);
        uint32 id = uint32(lootRecords.length - 1);
        banditLootRecords[_banditId].push(id);
        mineLootedRecords[_mineId].push(id);

        if (success) {
            LootVesting storage vesting = lootVesting[_banditId];
            vesting.pendingGem += lootGemAmount;
            vesting.pendingPaw += lootPawAmount;
        }

        emit LootMine(
            _msgSender(),
            _banditId, 
            _mineId, 
            lootPawAmount,
            lootGemAmount, 
            record.success
        );
    }

    function claim(uint32 _banditId, bool _escape) external whenNotPaused  {
        require(tx.origin == _msgSender(), "Not EOA");
        require(woof.ownerOf(_banditId) == _msgSender(), "Not owner");
        IWoof.WoofWoofWest memory ww = woof.getTokenTraits(_banditId);
        require(ww.nftType == 1, "Not bandit");
        
        LootVesting memory vesting = lootVesting[_banditId];
        if (vesting.pendingPaw == 0 && vesting.pendingGem == 0) {
            emit Claim(_msgSender(), _banditId, 0, 0, 0, 0);
            return;
        }

        uint32 power = woof.miningPowerOf(_banditId);
        uint256 claimablePaw = power * perPowerMaxClaimPawAmount;
        uint256 claimableGem = power * perPowerMaxClaimGemAmount;
        if (vesting.lastClaimTime + claimCD < block.timestamp) {
            claimablePaw = claimablePaw.min(vesting.pendingPaw);
            claimableGem = claimableGem.min(vesting.pendingGem);
            vesting.rewardPaidPaw = claimablePaw;
            vesting.rewardPaidGem = claimableGem;
            vesting.lastClaimTime = uint32(block.timestamp);
        } else {
            claimablePaw = claimablePaw.sub(vesting.rewardPaidPaw);
            claimableGem = claimableGem.sub(vesting.rewardPaidGem);
            claimablePaw = claimablePaw.min(vesting.pendingPaw);
            claimableGem = claimableGem.min(vesting.pendingGem);
            vesting.rewardPaidPaw = vesting.rewardPaidPaw.add(claimablePaw);
            vesting.rewardPaidGem = vesting.rewardPaidGem.add(claimableGem);
        }

        vesting.pendingPaw = vesting.pendingPaw.sub(claimablePaw);
        vesting.pendingGem = vesting.pendingGem.sub(claimableGem);
        lootVesting[_banditId] = vesting;

        (uint256 taxPawAmount, uint256 taxGemAmount) = wanted.payForHunter(
            _msgSender(), 
            _banditId, 
            claimablePaw,
            claimableGem,
            _escape
        );

        claimablePaw -= taxPawAmount;
        claimableGem -= taxGemAmount;

        (claimablePaw, claimableGem) = _payTaxToSlaveOwner(_banditId, claimablePaw, claimableGem);
        _safeTransfer(paw, _msgSender(), claimablePaw);
        _safeTransfer(gem, _msgSender(), claimableGem);
        userDashboard.rewardFromScene(_msgSender(), 2, claimablePaw, claimableGem, 0);

        emit Claim(_msgSender(), _banditId, claimablePaw, claimableGem, taxPawAmount, taxGemAmount);
    } 

    function _check(uint32 _banditId, uint32 _mineId) internal {
        require(woof.ownerOf(_banditId) == _msgSender(), "Not owner");
        require(woofMine.ownerOf(_mineId) != _msgSender(), "Can't loot self mine");

        IWoof.WoofWoofWest memory ww = woof.getTokenTraits(_banditId);
        require(ww.nftType == 1, "Not bandit");
        uint8 costStamina = woofMinePool.staminaCostOfLoot(_mineId);
        require(ww.attributes[0] >= costStamina, "Not enough stamina");
        ww.attributes[0] -= costStamina;
        woof.updateStamina(_banditId, ww.attributes[0]);

        _checkBandit(_banditId, ww.level);
        _checkMine(_mineId);
    }  

    function _checkBandit(uint32 _banditId,  uint8 _level) internal {
        LootInfo memory banditInfo = lootInfoOfBandit[_banditId];
        if (banditInfo.dailyLootStartTime + lootCD <= block.timestamp) {
            banditInfo.dailyLootStartTime = uint32(block.timestamp);
            banditInfo.dailyLootCount = 1;
        } else {
            banditInfo.dailyLootCount += 1;
            require(banditInfo.dailyLootCount <= lootMaxCountOfLevel[_level - 1], "Reach the max loot count");
        }
        lootInfoOfBandit[_banditId] = banditInfo;
    }

    function _checkMine(uint32 _mineId) internal {
        LootInfo memory mineInfo = lootInfoOfMine[_mineId];
        if (mineInfo.dailyLootStartTime + lootCD <= block.timestamp) {
            mineInfo.dailyLootStartTime = uint32(block.timestamp);
            mineInfo.dailyLootCount = 1;
        } else {
            mineInfo.dailyLootCount += 1;
            require(mineInfo.dailyLootCount <= 3, "Reach the max looted count");
        }
        lootInfoOfMine[_mineId] = mineInfo;
    }

    function _safeApprove(address token, address spender) internal {
        if (token != address(0) && IERC20(token).allowance(address(this), spender) == 0) {
            IERC20(token).safeApprove(spender, type(uint256).max);
        }
    }

    function _safeTransfer(address _token, address _to, uint256 _amount) internal {
        uint256 bal = IERC20(_token).balanceOf(address(this));
        if (_amount > bal) {
            _amount = bal;
        }
        if (_amount == 0) {
            return;
        }
        IERC20(_token).safeTransfer(_to, _amount);
    }

    function _payTaxToSlaveOwner(uint32 _tokenId, uint256 _paw, uint256 _gem) internal returns(uint256, uint256) {
        if (address(pvp) != address(0)) {
            (address slaveOwer, uint256 pawTax, uint256 gemTax) = pvp.slaveOwnerAndPayTax(_tokenId, _paw, _gem);
            if (slaveOwer != address(0)) {
                _safeTransfer(paw, slaveOwer, pawTax);
                _safeTransfer(gem, slaveOwer, gemTax);
                _paw -= pawTax;
                _gem -= gemTax;
            }
        }
        return (_paw, _gem);
    }
}