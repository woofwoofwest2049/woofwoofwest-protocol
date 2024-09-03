// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./interfaces/IWoofMineRentEnumerable.sol";
import "./interfaces/IWoofEnumerable.sol";
import "./interfaces/IWoofMinePool.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IWoofMinePool2 is IWoofMinePool {
    function getStakedMiners(uint32 _tokenId) external view returns(IWoofMinePool.StakedMiner[] memory);
    function stakedHunter(uint32 _tokenId) external view returns(IWoofMinePool.StakedHunter memory);
    function mineReward(uint32 _tokenId) external view returns(IWoofMinePool.Reward memory);
    function pendingRewards(IWoofMinePool.StakedMiner memory _miner, IWoofMine.WoofWoofMine memory _woofMine, IWoof.WoofWoofWest memory _woofWest) external view returns(uint256 pendingPaw, uint256 pendingGem);
    function currentStamina(uint32 _depositTime, IWoofMine.WoofWoofMine memory _woofMine, IWoof.WoofWoofWest memory _woofWest) external view returns(uint32);
}

interface ILoot {
    function mineLootBrief(uint32 _tokenId) external view returns(uint32 totalLootCount, uint8 dailyLootCount);
}

contract WoofMineRentEnumerable is OwnableUpgradeable {
    IWoofMineRentEnumerable public woofMine;
    IWoofMinePool2 public woofMinePool;
    IWoofEnumerable public woof;
    ILoot public loot;
    uint8 public maxPerAmount;

    function initialize(
        address _woofMine,
        address _woofMinePool,
        address _woof,
        address _loot
    ) external initializer {
        require(_woofMine != address(0));
        require(_woofMinePool != address(0));
        require(_woof != address(0));
        require(_loot != address(0));
        __Ownable_init();
        woofMine = IWoofMineRentEnumerable(_woofMine);
        woofMinePool = IWoofMinePool2(_woofMinePool);
        woof = IWoofEnumerable(_woof);
        loot = ILoot(_loot);
        maxPerAmount = 20;
    }

    function setMaxPerAmount(uint8 _amount) external onlyOwner {
        require(_amount >= 4 && _amount <= 20);
        maxPerAmount = _amount;
    }

    function balanceOfRent(address _user) public view returns(uint256) {
        return woofMine.balanceOfRent(_user);
    }

    function rentEndTime(uint256 _tokenId) public pure returns(uint256) {
        _tokenId;
        return 0;
    }

    struct WoofMineBrief {
        IWoofMineEnumerable.WoofMineBrief woofMine;
        uint256 rentEndTime;
        address owner;
    }

    function getUserTokenTraits(address _user, uint256 _index, uint8 _len) public view returns(
        WoofMineBrief[] memory nfts, 
        uint8 len
    ) {
        require(_len <= maxPerAmount && _len != 0);
        nfts = new WoofMineBrief[](_len);
        len = 0;

        uint256 bal = woofMine.balanceOfRent(_user);
        if (bal == 0 || _index >= bal) {
            return (nfts, len);
        }

        for (uint8 i = 0; i < _len; ++i) {
            uint256 tokenId = woofMine.tokenOfRenterByIndex(_user, _index);
            nfts[i].woofMine = woofMineBrief(uint32(tokenId));
            nfts[i].owner = woofMine.ownerOf(tokenId);
            nfts[i].rentEndTime = 0;
            (nfts[i].woofMine.totalLootCount, nfts[i].woofMine.dailyLootCount) = loot.mineLootBrief(uint32(tokenId));
            ++_index;
            ++len;
            if (_index >= bal) {
                return (nfts, len);
            }
        }
    }


    function getTokenDetails(uint32 _tokenId) public view returns(WoofMineBrief memory) {
        WoofMineBrief memory detail;
        detail.woofMine = woofMineBrief(_tokenId);
        (detail.woofMine.totalLootCount, detail.woofMine.dailyLootCount) = loot.mineLootBrief(_tokenId);
        detail.owner = woofMine.ownerOf(_tokenId);
        detail.rentEndTime = 0;
        return detail;
    }

    function farmInfo(address _user) public view returns(
        uint256 balance_,
        uint256 totalPawPendingRewards_,
        uint256 totalGemPendingRewards_
    ) {
        balance_ = balanceOfRent(_user);
        totalPawPendingRewards_ = 0;
        totalGemPendingRewards_ = 0;
        for (uint256 i = 0; i < balance_; ++i) {
            uint256 tokenId = woofMine.tokenOfRenterByIndex(_user, i);
            IWoofMineEnumerable.WoofMineBrief memory ww = woofMineBrief(uint32(tokenId));
            totalPawPendingRewards_ += ww.pendingPaw;
            totalGemPendingRewards_ += ww.pendingGem;
        }
    }

    function woofMineBrief(uint32 _tokenId) public view returns(IWoofMineEnumerable.WoofMineBrief memory) {
        IWoofMineEnumerable.WoofMineBrief memory brief;
        IWoofMine.WoofWoofMine memory w = woofMine.getTokenTraits(_tokenId);
        brief.quality = w.quality;
        brief.level = w.level;
        brief.tokenId = w.tokenId;
        brief.perPowerOutputGemOfSec = w.perPowerOutputGemOfSec;
        brief.perPowerOutputPawOfSec = w.perPowerOutputPawOfSec;
        IWoofMinePool.Reward memory reward = woofMinePool.mineReward(_tokenId);
        brief.pendingPaw = reward.pendingPaw;
        brief.pendingGem = reward.pendingGem;
        brief.lastRewardTime = reward.lastRewardTime;
        IWoofMinePool.StakedMiner[] memory miners = woofMinePool.getStakedMiners(_tokenId);
        if (miners.length > 0) {
            brief.miners = new IWoofMineEnumerable.WoofBrief[](miners.length);
        }
        for (uint256 i = 0; i < miners.length; ++i) {
            IWoofMinePool.StakedMiner memory miner  = miners[i];
            IWoof.WoofWoofWest memory ww = woof.getTokenTraits(miner.tokenId);
            (uint256 pendingPaw, uint256 pendingGem) = woofMinePool.pendingRewards(miner, w, ww);
            uint32 miningPower = woof.miningPowerOf(ww);
            brief.miningPower += miningPower;
            brief.pendingPaw += pendingPaw;
            brief.pendingGem += pendingGem;
            brief.miners[i].nftType = ww.nftType;
            brief.miners[i].quality = ww.quality;
            brief.miners[i].level = ww.level;
            brief.miners[i].cid = ww.cid;
            brief.miners[i].stamina = woofMinePool.currentStamina(miner.depositTime, w, ww);
            brief.miners[i].tokenId = ww.tokenId;
            brief.miners[i].pendingPaw = pendingPaw;
            brief.miners[i].pendingGem = pendingGem;
            brief.miners[i].name = ww.name;
        }
        IWoofMinePool.StakedHunter memory hunter = woofMinePool.stakedHunter(_tokenId);
        if (hunter.tokenId > 0) {
            IWoof.WoofWoofWest memory ww = woof.getTokenTraits(hunter.tokenId);
            brief.hunter.nftType = ww.nftType;
            brief.hunter.quality = ww.quality;
            brief.hunter.level = ww.level;
            brief.hunter.cid = ww.cid;
            brief.hunter.stamina = woofMinePool.currentStamina(hunter.depositTime, w, ww);
            brief.hunter.tokenId = ww.tokenId;
            brief.hunter.name = ww.name;
        }
        return brief;
    }
}