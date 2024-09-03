// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./library/SafeERC20.sol";
import "./library/SafeMath.sol";
import "./interfaces/IWoofMineEnumerable.sol";
import "./interfaces/IWoofEnumerable.sol";
import "./interfaces/IUserDashboard.sol";
import "./interfaces/IWoofMinePool.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

interface IPaw {
    function mint(address to, uint256 amount) external;
}

interface IGemMintHelper {
    function mint(address _account, uint256 _amount) external;
    function gem() external view returns(address);
}

interface IPVP {
    function payTax(uint32 _tokenId, uint256 _paw, uint256 _gem) external returns(uint256, uint256);
}

contract WoofMinePool is OwnableUpgradeable, PausableUpgradeable, IWoofMinePool {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    event StakeMiner(address indexed owner, uint256 indexed tokenId, uint256 indexed minerId);
    event StakeHunter(address indexed owner, uint256 indexed tokenId, uint256 indexed hunterId);
    event UnStakeMiner(address indexed owner, uint256 indexed tokenId, uint256 indexed minerId, uint256 pendingPaw, uint256 pendingGem);
    event UnStakeHunter(address indexed owner, uint256 indexed tokenId, uint256 indexed hunterId);
    event Claim(address indexed owner, uint256 indexed tokenId, uint256 pawRewards, uint256 gemRewards);
    event UnstakeAll(address indexed owner, uint256 indexed tokenId);

    IWoofMineEnumerable public woofMine;
    IWoofEnumerable public woof;

    mapping(uint32 => StakedMiner[]) public stakedMiners;
    mapping(uint32 => StakedHunter) public stakedHunter;
    mapping(uint32 => uint32[2]) public woofIdToMine;
    mapping(uint32 => Reward) public mineReward;

    IPaw public paw;
    IGemMintHelper public gemMintHelper;
    mapping(address => bool) public authControllers;

    uint32 public claimCD;
    IPVP public pvp;
    IUserDashboard public userDashboard;

    function initialize(
        address _woofMine,
        address _woof,
        address _paw,
        address _gemMintHelper
    ) external initializer {
        require(_woofMine != address(0));
        require(_woof != address(0));
        require(_paw != address(0));
        require(_gemMintHelper != address(0));

        __Ownable_init();
        __Pausable_init();

        woofMine = IWoofMineEnumerable(_woofMine);
        woof = IWoofEnumerable(_woof);
        paw = IPaw(_paw);
        gemMintHelper = IGemMintHelper(_gemMintHelper);

        claimCD = 1 days;
    }

    function setAuthControllers(address _controller, bool _enable) external onlyOwner {
        authControllers[_controller] = _enable;
    }

    function setClaimCD(uint32 _cd) external onlyOwner {
        claimCD = _cd;
    }

    function setPVP(address _pvp) external onlyOwner {
        pvp = IPVP(_pvp);
    }

    function setUserDashboard(address _userDashboard) external onlyOwner {
        require(_userDashboard != address(0));
        userDashboard = IUserDashboard(_userDashboard);
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function getStakedMiners(uint32 _tokenId) public view returns(StakedMiner[] memory) {
        return stakedMiners[_tokenId];
    }

    function stakeMiner(uint32 _tokenId, uint32 _minerId) external whenNotPaused {
        require(tx.origin == _msgSender());
        require(woofMine.ownerOf(_tokenId) == _msgSender(), "1");
        require(woof.ownerOf(_minerId) == _msgSender(), "2");

        IWoofMine.WoofWoofMine memory w = woofMine.getTokenTraits(_tokenId);
        IWoof.WoofWoofWest memory ww = woof.getTokenTraits(_minerId);
        require(ww.nftType == 0, "3");
        require(ww.level >= w.requiredMinLevel, "4");
        require(w.minerCapacity > stakedMiners[_tokenId].length, "5");

        woof.transferFrom(_msgSender(),  address(this),  _minerId);
        StakedMiner memory miner;
        miner.tokenId = _minerId;
        miner.depositTime = uint32(block.timestamp);
        miner.lastRewardTime = uint32(block.timestamp);
        miner.maxWorkingTime = uint32(block.timestamp) + maxWorkingTime(w, ww);
        stakedMiners[_tokenId].push(miner);
        mineReward[_tokenId].lastRewardTime = uint32(block.timestamp);
        woofIdToMine[_minerId][0] = _tokenId;
        woofIdToMine[_minerId][1] = uint32(stakedMiners[_tokenId].length - 1);
        emit StakeMiner(_msgSender(), _tokenId, _minerId);
    }

    function stakeHunter(uint32 _tokenId, uint32 _hunterId) external whenNotPaused {
        require(tx.origin == _msgSender());
        require(woofMine.ownerOf(_tokenId) == _msgSender(), "1");
        require(woof.ownerOf(_hunterId) == _msgSender(), "2");

        IWoofMine.WoofWoofMine memory w = woofMine.getTokenTraits(_tokenId);
        IWoof.WoofWoofWest memory ww = woof.getTokenTraits(_hunterId);
        require(ww.nftType == 2, "3");
        require(ww.level >= w.requiredMinLevel, "4");
        require(stakedHunter[_tokenId].tokenId == 0, "5");

        woof.transferFrom(_msgSender(), address(this), _hunterId);
        StakedHunter memory hunter;
        hunter.tokenId = _hunterId;
        hunter.depositTime = uint32(block.timestamp);
        stakedHunter[_tokenId] = hunter;
        woofIdToMine[_hunterId][0] = _tokenId;
        emit StakeHunter(_msgSender(), _tokenId, _hunterId);
    }

    function unstakeMiner(uint32 _tokenId, uint8 _index) external {
        require(tx.origin == _msgSender());
        require(woofMine.ownerOf(_tokenId) == _msgSender(), "1");
        _unstakeMiner(_tokenId, _index);
    }

    function _unstakeMiner(uint32 _tokenId, uint8 _index) internal {
        StakedMiner[] memory miners = stakedMiners[_tokenId];
        require(_index < miners.length, "2");
        StakedMiner memory miner = miners[_index];
        IWoofMine.WoofWoofMine memory w = woofMine.getTokenTraits(_tokenId);
        IWoof.WoofWoofWest memory ww = woof.getTokenTraits(miner.tokenId);
        _updateStamina(miner.depositTime, w, ww);
        (uint256 pendingPaw, uint256 pendingGem) = _claim(miner, w, ww);
        Reward memory reward = mineReward[_tokenId];
        reward.pendingPaw += pendingPaw;
        reward.pendingGem += pendingGem;
        mineReward[_tokenId] = reward;
        woof.transferFrom(address(this), _msgSender(), miner.tokenId);

        StakedMiner memory lastMiner = miners[miners.length - 1];
        stakedMiners[_tokenId][_index] = lastMiner;
        stakedMiners[_tokenId].pop();
        woofIdToMine[lastMiner.tokenId][1] = _index;
        if (stakedMiners[_tokenId].length == 0) {
            delete stakedMiners[_tokenId];
        }
        delete woofIdToMine[miner.tokenId];
        emit UnStakeMiner(_msgSender(), _tokenId, miner.tokenId, pendingPaw, pendingGem);
    }

    function unstakeHunter(uint32 _tokenId) external {
        require(tx.origin == _msgSender());
        require(woofMine.ownerOf(_tokenId) == _msgSender(), "1");
        _unstakeHunter(_tokenId);
    }

    function _unstakeHunter(uint32 _tokenId) internal {
        uint32 hunterId  = _unstakeHunter(_tokenId, _msgSender());
        emit UnStakeHunter(_msgSender(), _tokenId, hunterId);
    }

    function unstakeAll(uint32 _tokenId) external {
        require(tx.origin == _msgSender());
        require(woofMine.ownerOf(_tokenId) == _msgSender(), "1");
        _unstakeAllMiners(_tokenId, _msgSender());
        _unstakeHunter(_tokenId, _msgSender());
        emit UnstakeAll(_msgSender(), _tokenId);
    }  

    function claim(uint32 _tokenId) external {
        require(tx.origin == _msgSender());
        require(woofMine.ownerOf(_tokenId) == _msgSender(), "1");
        Reward memory reward = mineReward[_tokenId];
        require(reward.lastRewardTime + claimCD < block.timestamp, "2");
        (uint256 totalPendingPaw, uint256 totalPendingGem) = _claim(_tokenId);
        totalPendingPaw += reward.pendingPaw;
        totalPendingGem += reward.pendingGem;
        _safeTransfer(address(paw), _msgSender(), totalPendingPaw);
        _safeTransfer(gemMintHelper.gem(), _msgSender(), totalPendingGem);
        userDashboard.rewardFromScene(_msgSender(), 1, totalPendingPaw, totalPendingGem, 0);
        reward.pendingPaw = 0;
        reward.pendingGem = 0;
        reward.lastRewardTime = uint32(block.timestamp);
        mineReward[_tokenId] = reward;
        emit Claim(_msgSender(), _tokenId, totalPendingPaw, totalPendingGem);
    }

    function unstake(uint32 _nftId, address _renter) public {
        _renter;
        require(authControllers[msg.sender] == true, "1");
        IWoof.WoofWoofWest memory ww = woof.getTokenTraits(_nftId);
        if (ww.nftType == 0) {
            _unstakeMiner(woofIdToMine[_nftId][0], uint8(woofIdToMine[_nftId][1]));
        } else if (ww.nftType == 2) {
            _unstakeHunter(woofIdToMine[_nftId][0]);
        }
    }

    function loot(uint32 _banditId, uint32 _tokenId, uint8 _percent) external returns(bool success, uint256 lootPawAmount, uint256 lootGemAmount) {
        require(authControllers[msg.sender] == true, "1");
        IWoofMine.WoofWoofMine memory w = woofMine.getTokenTraits(_tokenId);
        IWoof.WoofWoofWest memory ww = woof.getTokenTraits(_banditId);
        require(ww.level >= w.requiredMinLevel, "2");
        success = _lootCheck(w);
        if (success == false) {
            return  (false,  0, 0);
        }
        uint256 miningPower = woof.miningPowerOf(ww);
        success = true;
        (uint256 totalPendingPaw, uint256 totalPendingGem) = _claim(_tokenId);
        Reward memory reward = mineReward[_tokenId];
        totalPendingPaw += reward.pendingPaw;
        totalPendingGem += reward.pendingGem;
        lootPawAmount = totalPendingPaw * _percent / 100;
        lootGemAmount = totalPendingGem * _percent / 100;
        uint256 dailyPawAmount = miningPower * w.perPowerOutputPawOfSec * 1 days;
        uint256 dailyGemAmount = miningPower * w.perPowerOutputGemOfSec * 1 days;
        lootPawAmount = lootPawAmount > dailyPawAmount ? dailyPawAmount : lootPawAmount;
        lootGemAmount = lootGemAmount > dailyGemAmount ? dailyGemAmount : lootGemAmount;
        reward.pendingPaw = totalPendingPaw - lootPawAmount;
        reward.pendingGem = totalPendingGem - lootGemAmount;
        mineReward[_tokenId] = reward;
        _safeTransfer(address(paw), _msgSender(), lootPawAmount);
        _safeTransfer(gemMintHelper.gem(), _msgSender(), lootGemAmount);
    }

    function recoverStaminaOfMiner(uint32 _tokenId, uint32 _index, uint32 _stamina) external {
        require(authControllers[msg.sender] == true, "1");
        StakedMiner[] memory miners = stakedMiners[_tokenId];
        require(_index < miners.length, "3");
        StakedMiner memory miner = miners[_index];
        IWoofMine.WoofWoofMine memory w = woofMine.getTokenTraits(_tokenId);
        IWoof.WoofWoofWest memory ww = woof.getTokenTraits(miner.tokenId);
        uint32 curStamina = currentStamina(miner.depositTime, w, ww);
        if (curStamina == 0) {
            (uint256 pendingPaw, uint256 pendingGem) = pendingRewards(miner, w, ww);
            stakedMiners[_tokenId][_index].pendingPaw = pendingPaw;
            stakedMiners[_tokenId][_index].pendingGem = pendingGem;
            stakedMiners[_tokenId][_index].lastRewardTime = uint32(block.timestamp);
        }
        _stamina += curStamina;
        ww.attributes[0] = _stamina;
        uint32 depositTime = uint32(block.timestamp);
        stakedMiners[_tokenId][_index].depositTime = depositTime;
        stakedMiners[_tokenId][_index].maxWorkingTime = depositTime + maxWorkingTime(w, ww);
        woof.updateStamina(miner.tokenId, _stamina);
    }

    function recoverStaminaOfHunter(uint32 _tokenId, uint32 _stamina) external {
        require(authControllers[msg.sender] == true, "1");
        StakedHunter memory hunter = stakedHunter[_tokenId];
        require(hunter.tokenId > 0, "2");
        IWoofMine.WoofWoofMine memory w = woofMine.getTokenTraits(_tokenId);
        IWoof.WoofWoofWest memory ww = woof.getTokenTraits(hunter.tokenId);
        uint32 curStamina = currentStamina(hunter.depositTime, w, ww);
        _stamina += curStamina;
        hunter.depositTime = uint32(block.timestamp);
        stakedHunter[_tokenId] = hunter;
        woof.updateStamina(hunter.tokenId, _stamina);
    }

    function updatePower(uint32 _minerId, uint256 _miningPower, uint256 _beforeMiningPower) external {
        _miningPower;
        require(authControllers[msg.sender] == true, "1");
        uint32 mineId = woofIdToMine[_minerId][0];
        if (mineId == 0) {
            return;
        }

        uint32 index = woofIdToMine[_minerId][1];
        IWoofMine.WoofWoofMine memory w = woofMine.getTokenTraits(mineId);
        StakedMiner memory miner = stakedMiners[mineId][index];
        require(miner.tokenId == _minerId, "2");
        (uint256 pendingPaw, uint256 pendingGem) = pendingRewards(miner, w, _beforeMiningPower);
        miner.pendingPaw = pendingPaw;
        miner.pendingGem = pendingGem;
        miner.lastRewardTime = uint32(block.timestamp);
        stakedMiners[mineId][index] = miner;
    }

    function checkLevelUp(uint32 _tokenId) public view returns(bool) {
        StakedMiner[] memory miners = stakedMiners[_tokenId];
        if (miners.length > 0) {
            return false;
        }

        StakedHunter memory hunter = stakedHunter[_tokenId];
        if (hunter.tokenId > 0) {
            return false;
        }

        return true;
    }

    function maxWorkingTime(IWoofMine.WoofWoofMine memory _woofMine, IWoof.WoofWoofWest memory _woofWest) public pure returns(uint32) {
        uint32 cost = _staminaCostPerHour(_woofMine, _woofWest.nftType);
        if (cost == 0) {
            return 3650 days;
        }
        return _woofWest.attributes[0] * 3600 / cost;
    }

    function staminaCostOfLoot(uint32 _tokenId) public view returns(uint8) {
        IWoofMine.WoofWoofMine memory w = woofMine.getTokenTraits(_tokenId);
        return w.staminaCostOfLoot;
    }

    function pendingRewards(StakedMiner memory _miner, IWoofMine.WoofWoofMine memory _woofMine, IWoof.WoofWoofWest memory _woofWest) public view returns(uint256 pendingPaw, uint256 pendingGem) {
        uint256 curTime = block.timestamp > _miner.maxWorkingTime ? _miner.maxWorkingTime : block.timestamp;
        if (curTime <= _miner.lastRewardTime) {
            return (_miner.pendingPaw, _miner.pendingGem);
        }

        uint256 miningPower = woof.miningPowerOf(_woofWest);
        uint256 gap = curTime - _miner.lastRewardTime;
        pendingPaw = _miner.pendingPaw + gap * _woofMine.perPowerOutputPawOfSec * miningPower;
        pendingGem = _miner.pendingGem + gap * _woofMine.perPowerOutputGemOfSec * miningPower;
    }

    function pendingRewards(StakedMiner memory _miner, IWoofMine.WoofWoofMine memory _woofMine, uint256 _miningPower) public view returns(uint256 pendingPaw, uint256 pendingGem) {
        uint256 curTime = block.timestamp > _miner.maxWorkingTime ? _miner.maxWorkingTime : block.timestamp;
        if (curTime <= _miner.lastRewardTime) {
            return (_miner.pendingPaw, _miner.pendingGem);
        }

        uint256 gap = curTime - _miner.lastRewardTime;
        pendingPaw = _miner.pendingPaw + gap * _woofMine.perPowerOutputPawOfSec * _miningPower;
        pendingGem = _miner.pendingGem + gap * _woofMine.perPowerOutputGemOfSec * _miningPower;
    }

    function currentStamina(uint32 _depositTime, IWoofMine.WoofWoofMine memory _woofMine, IWoof.WoofWoofWest memory _woofWest) public view returns(uint32) {
        if (_depositTime > block.timestamp) {
            _depositTime = uint32(block.timestamp);
        }
        uint32 gap = uint32(block.timestamp) - _depositTime;
        uint32 costPerHour = _staminaCostPerHour(_woofMine, _woofWest.nftType);
        uint32 cost = gap * costPerHour / 3600;
        if (cost >= _woofWest.attributes[0]) {
            return 0;
        }
        return _woofWest.attributes[0] - cost;
    }

    function _staminaCostPerHour(IWoofMine.WoofWoofMine memory _woofMine, uint8 _nftType) internal pure returns(uint8) {
        if (_nftType == 0) {
            return _woofMine.staminaCostPerHourOfMiner;
        } else if (_nftType == 2) {
            return _woofMine.staminaCostPerHourOfHunter;
        } else {
            return 0;
        }
    }

    function _claim(uint32 _tokenId) internal returns(uint256 totalPendingPaw, uint256 totalPendingGem) {
        totalPendingPaw = 0;
        totalPendingGem = 0;
        IWoofMine.WoofWoofMine memory w = woofMine.getTokenTraits(_tokenId);
        StakedMiner[] memory miners = stakedMiners[_tokenId];
        for (uint256 i = 0; i < miners.length; ++i) {
            StakedMiner memory miner  = miners[i];
            IWoof.WoofWoofWest memory ww = woof.getTokenTraits(miner.tokenId);
            (uint256 pendingPaw, uint256 pendingGem) = pendingRewards(miner, w, ww);
            (pendingPaw, pendingGem) = _paySlaveTax(miner.tokenId, pendingPaw, pendingGem);
            totalPendingPaw += pendingPaw;
            totalPendingGem += pendingGem;
            stakedMiners[_tokenId][i].pendingPaw = 0;
            stakedMiners[_tokenId][i].pendingGem = 0;
            stakedMiners[_tokenId][i].lastRewardTime = uint32(block.timestamp);
        }
        if (totalPendingPaw > 0) {
            paw.mint(address(this), totalPendingPaw);
        }
        if (totalPendingGem > 0) {
            gemMintHelper.mint(address(this), totalPendingGem);
        }
    }

    function _unstakeAllMiners(uint32 _tokenId, address _owner) internal {
        StakedMiner[] memory miners = stakedMiners[_tokenId];
        if (miners.length == 0) {
            return;
        }
        uint256 totalPendingPaw = 0;
        uint256 totalPendingGem = 0;

        IWoofMine.WoofWoofMine memory w = woofMine.getTokenTraits(_tokenId);
        for (uint8 i = 0; i < miners.length; ++i) {
            StakedMiner memory miner = miners[i];
            IWoof.WoofWoofWest memory ww = woof.getTokenTraits(miner.tokenId);
            _updateStamina(miner.depositTime, w, ww);
            (uint256 pendingPaw, uint256 pendingGem) = pendingRewards(miner, w, ww);
            (pendingPaw, pendingGem) = _paySlaveTax(miner.tokenId, pendingPaw, pendingGem);
            totalPendingPaw += pendingPaw;
            totalPendingGem += pendingGem;
            woof.transferFrom(address(this), _owner, miner.tokenId);
            delete woofIdToMine[miner.tokenId];
        }

        if (totalPendingPaw > 0) {
            paw.mint(address(this), totalPendingPaw);
        }
        if (totalPendingGem > 0) {
            gemMintHelper.mint(address(this), totalPendingGem);
        }

        Reward memory reward = mineReward[_tokenId];
        reward.pendingPaw += totalPendingPaw;
        reward.pendingGem += totalPendingGem;
        mineReward[_tokenId] = reward;
        delete stakedMiners[_tokenId];
    }

    function _unstakeHunter(uint32 _tokenId, address _owner) internal returns(uint32) {
        StakedHunter memory hunter = stakedHunter[_tokenId];
        if (hunter.tokenId == 0)  {
            return 0;
        }
        IWoofMine.WoofWoofMine memory w = woofMine.getTokenTraits(_tokenId);
        IWoof.WoofWoofWest memory ww = woof.getTokenTraits(hunter.tokenId);
        _updateStamina(hunter.depositTime, w, ww);
        woof.transferFrom(address(this), _owner, hunter.tokenId);
        delete stakedHunter[_tokenId];
        delete woofIdToMine[hunter.tokenId];
        return hunter.tokenId;
    }

    function _claim(StakedMiner memory _miner, IWoofMine.WoofWoofMine memory _woofMine, IWoof.WoofWoofWest memory _woofWest) internal returns(uint256 pendingPaw, uint256 pendingGem) {
        (pendingPaw, pendingGem) = pendingRewards(_miner, _woofMine, _woofWest);
        (pendingPaw, pendingGem) = _paySlaveTax(_miner.tokenId, pendingPaw, pendingGem);
        if (pendingPaw > 0) {
            paw.mint(address(this), pendingPaw);
        }
        if (pendingGem > 0) {
            gemMintHelper.mint(address(this), pendingGem);
        }
    }

    function _updateStamina(uint32 _depositTime, IWoofMine.WoofWoofMine memory _woofMine, IWoof.WoofWoofWest memory _woofWest) internal {
        uint32 stamina = currentStamina(_depositTime, _woofMine, _woofWest);
        woof.updateStamina(_woofWest.tokenId, stamina);
    }

    function _lootCheck(IWoofMine.WoofWoofMine memory w) internal view returns(bool) {
        StakedHunter memory hunter = stakedHunter[w.tokenId];
        if (hunter.tokenId > 0) {
            IWoof.WoofWoofWest memory ww = woof.getTokenTraits(hunter.tokenId);
            uint32 maxWorkingTimeOfHunter = hunter.depositTime + maxWorkingTime(w, ww);
            if (maxWorkingTimeOfHunter > block.timestamp) {
                return false;
            }
        }
        return true;
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

    function _paySlaveTax(uint32 _tokenId, uint256 _paw, uint256 _gem) internal returns(uint256, uint256) {
        if (address(pvp) != address(0)) {
            (uint256 pawTax, uint256 gemTax) = pvp.payTax(_tokenId, _paw, _gem);
            _paw -= pawTax;
            _gem -= gemTax;
        }
        return (_paw, _gem);
    }
} 