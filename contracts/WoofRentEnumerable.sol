// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./interfaces/IWoofRentEnumerable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IBaby {
    function woofAccRewardBabyAmount(uint32 _tokenId) external view returns(uint32);
}

contract WoofRentEnumerable is OwnableUpgradeable {
    IWoofRentEnumerable public woof;
    uint8 public maxPerAmount;
    IBaby public baby;

    function initialize(
        address _woof,
        address _baby
    ) external initializer {
        require(_woof != address(0));
        require(_baby != address(0));

        __Ownable_init();
        woof = IWoofRentEnumerable(_woof);
        baby = IBaby(_baby);
        maxPerAmount = 100;
    }

    function setMaxPerAmount(uint8 _amount) external onlyOwner {
        require(_amount >= 10 && _amount <= 100);
        maxPerAmount = _amount;
    }

    function balanceOfRent(address _renter) public view returns(uint256) {
        return woof.balanceOfRent(_renter);
    }

    function rentEndTime(uint256 _tokenId) public pure returns(uint256) {
        _tokenId;
        return 0;
    }

    struct WoofWoofWest {
        IWoof.WoofWoofWest woof;
        uint32 rewardBabyAmount;
        uint256 rentEndTime;
        address owner;
    }

    function getUserRentTokenTraits(address _user, uint256 _index, uint8 _len) public view returns(
        WoofWoofWest[] memory nfts, 
        uint8 len
    ) {
        require(_len <= maxPerAmount && _len != 0);
        nfts = new WoofWoofWest[](_len);
        len = 0;

        uint256 bal = woof.balanceOfRent(_user);
        if (bal == 0 || _index >= bal) {
            return (nfts, len);
        }

        for (uint8 i = 0; i < _len; ++i) {
            uint256 tokenId = woof.tokenOfRenterByIndex(_user, _index);
            nfts[i].woof = woof.getTokenTraits(tokenId);
            nfts[i].rewardBabyAmount = baby.woofAccRewardBabyAmount(uint32(tokenId));
            nfts[i].rentEndTime = 0;
            nfts[i].owner = woof.ownerOf(tokenId);
            ++_index;
            ++len;
            if (_index >= bal) {
                return (nfts, len);
            }
        }
    }

    struct RentInfo {
        uint256 rentEndTime;
        address renter;
        address lender;
    }

    function getRentInfo(uint32[] memory _tokenIds) public pure returns(
        RentInfo[] memory nfts
    ) {
        nfts = new RentInfo[](_tokenIds.length);
        for (uint32 i = 0; i < _tokenIds.length; ++i) {
            nfts[i].rentEndTime = 0;
            nfts[i].renter = address(0);
            nfts[i].lender = address(0);
        }
    }
}

