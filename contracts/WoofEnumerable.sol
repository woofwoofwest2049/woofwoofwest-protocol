// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./interfaces/IWoofEnumerable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface ILoot {
    function banditLootBrief(uint32 _tokenId, uint8 _level) external view returns(uint32 totalLootCount, uint8 dailyLootCount, uint8 maxDailyLootCount);
    function banditLootVesting(uint32 _tokenId) external view returns(
        uint32 lastClaimTime,
        uint256 pendingPaw,
        uint256 pendingGem,
        uint256 claimablePaw,
        uint256 claimableGem
    );
}

interface IWanted {
    function wantedBrief(uint32 _hunterId) external view returns(uint8 wantedCount, uint8 maxWantedCount);
    function wantedRewards(uint32 _hunterId) external view returns(uint256 totalPendingPaw, uint256 totalPendingGem);
    function wantedHuntersOfBandit(uint32 _banditId) external view returns(uint32[] memory);
}

interface IWoofHelper {
    function stolenRecordsCountOfBandit(uint32 _banditId) external view returns(uint32);
}

interface IBaby {
    function woofAccRewardBabyAmount(uint32 _tokenId) external view returns(uint32);
}

interface IExplore {
    function balanceOf(address _user) external view returns(uint256);
    function exploredBalanceOf(uint32 _nftId) external view returns(uint256);
}

interface IPVPEnumerable {
    function getSlaveAmount(uint32 _tokenId) external view returns(uint32);
}

contract WoofEnumerable is OwnableUpgradeable {
    IWoofEnumerable public woof;
    ILoot public loot;
    IWanted public wanted;
    uint8 public maxPerAmount;
    IWoofHelper public woofHelper;
    IBaby public baby;
    IExplore public explore;
    IPVPEnumerable public pvp;

    function initialize(
        address _woof,
        address _loot,
        address _wanted
    ) external initializer {
        require(_woof != address(0));
        require(_loot != address(0));
        require(_wanted != address(0));

        __Ownable_init();
        woof = IWoofEnumerable(_woof);
        loot = ILoot(_loot);
        wanted = IWanted(_wanted);
        maxPerAmount = 100;
    }

    function setMaxPerAmount(uint8 _amount) external onlyOwner {
        require(_amount >= 10 && _amount <= 100);
        maxPerAmount = _amount;
    }

    function setWoofHelper(address _woofHelper) external onlyOwner {
        require(_woofHelper != address(0));
        woofHelper = IWoofHelper(_woofHelper);
    }

    function setBaby(address _baby) external onlyOwner {
        require(_baby != address(0));
        baby = IBaby(_baby);
    }

    function setExplore(address _explore) external onlyOwner {
        require(_explore != address(0));
        explore = IExplore(_explore);
    }

    function setPVP(address _pvp) external onlyOwner {
        require(_pvp != address(0));
        pvp = IPVPEnumerable(_pvp);
    }

    function balanceOf(address _user) public view returns(uint256) {
        return woof.balanceOf(_user);
    }

    function balanceOfType(uint256 _type) public view returns(uint256) {
        return woof.balanceOfType(_type);
    }    

    function getUserTokenTraits(address _user, uint256 _index, uint8 _len) public view returns(
        IWoof.WoofWoofWest[] memory nfts, 
        uint8 len
    ) {
        require(_len <= maxPerAmount && _len != 0);
        nfts = new IWoof.WoofWoofWest[](_len);
        len = 0;

        uint256 bal = woof.balanceOf(_user);
        if (bal == 0 || _index >= bal) {
            return (nfts, len);
        }

        for (uint8 i = 0; i < _len; ++i) {
            uint256 tokenId = woof.tokenOfOwnerByIndex(_user, _index);
            nfts[i] = woof.getTokenTraits(tokenId);
            ++_index;
            ++len;
            if (_index >= bal) {
                return (nfts, len);
            }
        }
    }

    struct WoofWoofWest2 {
        IWoof.WoofWoofWest woof;
        uint32 rewardBabyAmount;
    }

    function getUserTokenTraits2(address _user, uint256 _index, uint8 _len) public view returns(
        WoofWoofWest2[] memory nfts, 
        uint8 len
    ) {
        require(_len <= maxPerAmount && _len != 0);
        nfts = new WoofWoofWest2[](_len);
        len = 0;

        uint256 bal = woof.balanceOf(_user);
        if (bal == 0 || _index >= bal) {
            return (nfts, len);
        }

        for (uint8 i = 0; i < _len; ++i) {
            uint256 tokenId = woof.tokenOfOwnerByIndex(_user, _index);
            nfts[i].woof = woof.getTokenTraits(tokenId);
            nfts[i].rewardBabyAmount = baby.woofAccRewardBabyAmount(uint32(tokenId));
            ++_index;
            ++len;
            if (_index >= bal) {
                return (nfts, len);
            }
        }
    }


    function getLastUserTokenTraits(address _user) public view returns(
        IWoof.WoofWoofWest memory nft) 
    {
        uint256 bal = woof.balanceOf(_user);
        if (bal > 0) {
            uint256 tokenId = woof.tokenOfOwnerByIndex(_user, bal - 1);
            nft = woof.getTokenTraits(tokenId);
        }
    }

    struct WoofWoofWest {
        IWoof.WoofWoofWest woof;
        address owner;
    }

    function getTokenTraitsOfType(uint256 _type, uint256 _index, uint8 _len) public view returns(
        WoofWoofWest[] memory nfts, 
        uint8 len
    ) {
        require(_len <= maxPerAmount && _len != 0);
        nfts = new WoofWoofWest[](_len);
        len = 0;

        uint256 bal = woof.balanceOfType(_type);
        if (bal == 0 || _index >= bal) {
            return (nfts, len);
        }

        for (uint8 i = 0; i < _len; ++i) {
            uint256 tokenId = woof.tokenOfTypeByIndex(_type, _index);
            nfts[i].woof = woof.getTokenTraits(tokenId);
            nfts[i].owner = woof.ownerOf2(tokenId);
            ++_index;
            ++len;
            if (_index >= bal) {
                return (nfts, len);
            }
        }
    }

    function getTokenTraitsByIds(uint32[] memory _tokenIds) public view returns(WoofWoofWest[] memory nfts) {
        require(_tokenIds.length <= 50);
        nfts = new WoofWoofWest[](_tokenIds.length);
        for (uint256 i = 0; i < _tokenIds.length; ++i) {
            nfts[i].woof = woof.getTokenTraits(_tokenIds[i]);
            nfts[i].owner = woof.ownerOf2(_tokenIds[i]);
        }
    }

    struct WoofWoofWestDetails {
        IWoof.WoofWoofWest woof;
        address owner;
        uint8 count; //hunter: wantedCount, bandit: dailyLootCount
        uint8 maxCount; //hunter: maxWantedCount, bandit: maxDailyLootCount
        uint32 totalLootCount;
        uint32 totalStolenCount;
        uint256 pendingUOfG0;
    }

    function getTokenDetails(uint32 _tokenId) public view returns(WoofWoofWestDetails memory) {
        WoofWoofWestDetails memory detail;
        detail.woof = woof.getTokenTraits(_tokenId);
        detail.owner = woof.ownerOf2(_tokenId);
        if (detail.woof.nftType == 1) {
            (detail.totalLootCount, detail.count, detail.maxCount) = loot.banditLootBrief(_tokenId, detail.woof.level);
            detail.totalStolenCount = woofHelper.stolenRecordsCountOfBandit(_tokenId);
        } else if (detail.woof.nftType == 2) {
            (detail.count, detail.maxCount) = wanted.wantedBrief(_tokenId);
        }
        detail.pendingUOfG0 = woof.pendingU(_tokenId);
        return detail;
    }

    function userDashboard(address _user) public view returns(
        uint32 banditAmount_,
        uint256 banditPawPendingRewards_,
        uint256 banditGemPendingRewards_, 
        uint32 hunterAmount_, 
        uint256 hunterPawPendingRewards_,
        uint256 hunterGemPendingRewards_,
        uint256 exploredAmount_,
        uint256 exploreInProgressAmount_,
        uint256 slaveAmount_
    ) {
        banditAmount_ = 0;
        banditPawPendingRewards_ = 0;
        banditGemPendingRewards_ = 0;
        hunterAmount_ = 0;
        hunterPawPendingRewards_ = 0;
        hunterGemPendingRewards_ = 0;
        exploredAmount_ = 0;
        exploreInProgressAmount_ = explore.balanceOf(_user);
        slaveAmount_ = 0;

        uint256 bal = woof.balanceOf(_user);
        for (uint8 i = 0; i < bal; ++i) {
            uint32 tokenId = uint32(woof.tokenOfOwnerByIndex(_user, i));
            IWoof.WoofWoofWest memory w = woof.getTokenTraits(tokenId);
            if (w.nftType == 1) {
                banditAmount_ += 1;
                (,uint256 pendingPaw, uint256 pendingGem,,) = loot.banditLootVesting(tokenId);
                banditPawPendingRewards_ += pendingPaw;
                banditGemPendingRewards_ += pendingGem;
            } else if (w.nftType == 2) {
                hunterAmount_ += 1;
                (uint256 pendingPaw, uint256 pendingGem) = wanted.wantedRewards(tokenId);
                hunterPawPendingRewards_ += pendingPaw;
                hunterGemPendingRewards_ += pendingGem;
            }
            exploredAmount_ += explore.exploredBalanceOf(tokenId);
            slaveAmount_ += pvp.getSlaveAmount(tokenId);
        }
    }

    function wantedHutersOfBandit(uint32 _banditId) public view returns(WoofWoofWest[] memory nfts) {
        uint32[] memory ids = wanted.wantedHuntersOfBandit(_banditId);
        if (ids.length > 0) {
            nfts = getTokenTraitsByIds(ids);
        }
    }
}