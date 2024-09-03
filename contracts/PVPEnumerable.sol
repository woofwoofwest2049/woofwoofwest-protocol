// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./interfaces/IPVP.sol";
import "./interfaces/IWoofEnumerable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IPVP2 is IPVP {
    function getReport(uint32 _id) external view returns(Report memory);
    function getPVPInfo(uint32 _tokenId) external view returns(PVPInfo memory);
    function getUserReports(address _user) external view returns(uint32[] memory);
}

contract PVPEnumerable is OwnableUpgradeable {
    IPVP2 public pvp;
    IWoofEnumerable public woof;
    function initialize(
        address _pvp,
        address _woof
    ) external initializer {
        require(_pvp != address(0));
        require(_woof != address(0));

        __Ownable_init();
        pvp = IPVP2(_pvp);
        woof = IWoofEnumerable(_woof);
    }

    function setWoof(address _woof) public onlyOwner {
        require(_woof != address(0));
        woof = IWoofEnumerable(_woof);
    }

    function totalReportCount() public view returns(uint256) {
        return pvp.totalReportCount();
    }

    function getLastAttackReport(uint32 _nftId) public view returns(IPVP.Report memory report) {
        IPVP.PVPInfo memory attackInfo = pvp.getPVPInfo(_nftId);
        if (attackInfo.attackReport.length > 0) {
            uint32 reportId = attackInfo.attackReport[attackInfo.attackReport.length - 1];
            report = pvp.getReport(reportId);
        }
    }

    function pvpReportCountOf(address _user) public view returns(uint256) {
        return pvp.getUserReports(_user).length;
    }

    function getUserPVPReports(address _user, uint256 _index, uint8 _len) public view returns(
        IPVP.Report[] memory reports_, 
        uint8 len
    ) {
        require(_len <= 100 && _len != 0);
        reports_ = new IPVP.Report[](_len);
        len = 0;

        uint256 bal = pvpReportCountOf(_user);
        if (bal == 0 || _index >= bal) {
            return (reports_, len);
        }

        uint32[] memory reportIds = pvp.getUserReports(_user);
        for (uint8 i = 0; i < _len; ++i) {
            uint32 reportId = reportIds[_index];
            reports_[i] = pvp.getReport(reportId);
            ++_index;
            ++len;
            if (_index >= bal) {
                return (reports_, len);
            }
        }
    }

    struct SlaveInfo {
        uint32 tokenId;
        uint256 taxPaw;
        uint256 taxGem;
    }

    struct WoofPVPInfo {
        uint32 lastBattleTimestamp;
        uint32 reedemTimestamp;
        uint32 slaveOwner;
        uint32 attackReportCount;
        uint32 defensiveReportCount;
        SlaveInfo[] slaves;
    }

    function getPVPInfo(uint32 _tokenId) public view returns(WoofPVPInfo memory info) {
        IPVP.PVPInfo memory tempInfo = pvp.getPVPInfo(_tokenId);
        info.lastBattleTimestamp = tempInfo.lastBattleTimestamp;
        info.reedemTimestamp = tempInfo.reedemTimestamp;
        info.slaveOwner = tempInfo.slaveOwner;
        info.attackReportCount = uint32(tempInfo.attackReport.length);
        info.defensiveReportCount = uint32(tempInfo.defensiveReport.length);
        if (tempInfo.slaves.length > 0) {
            info.slaves = new SlaveInfo[](tempInfo.slaves.length);
            for (uint256 i = 0; i < tempInfo.slaves.length; ++i) {
                SlaveInfo memory slaveInfo;
                slaveInfo.tokenId = tempInfo.slaves[i];
                IPVP.PVPInfo memory tempInfo2 = pvp.getPVPInfo(slaveInfo.tokenId);
                slaveInfo.taxPaw = tempInfo2.taxPaw;
                slaveInfo.taxGem = tempInfo2.taxGem;
                info.slaves[i] = slaveInfo;
            }
        }
    }

    function getSlaveAmount(uint32 _tokenId) public view returns(uint32) {
        IPVP.PVPInfo memory tempInfo = pvp.getPVPInfo(_tokenId);
        return uint32(tempInfo.slaves.length);
    }

    function getPVPAttackReports(uint32 _tokenId, uint256 _index, uint8 _len) public view returns(
        IPVP.Report[] memory reports_, 
        uint8 len
    ) {
        require(_len <= 100 && _len != 0);
        reports_ = new IPVP.Report[](_len);
        len = 0;

        IPVP.PVPInfo memory info = pvp.getPVPInfo(_tokenId);
        uint256 bal = info.attackReport.length;
        if (bal == 0 || _index >= bal) {
            return (reports_, len);
        }

        for (uint8 i = 0; i < _len; ++i) {
            uint32 reportId = info.attackReport[_index];
            reports_[i] = pvp.getReport(reportId);
            ++_index;
            ++len;
            if (_index >= bal) {
                return (reports_, len);
            }
        }
    }

    function getPVPDefensiveReports(uint32 _tokenId, uint256 _index, uint8 _len) public view returns(
        IPVP.Report[] memory reports_, 
        uint8 len
    ) {
        require(_len <= 100 && _len != 0);
        reports_ = new IPVP.Report[](_len);
        len = 0;

        IPVP.PVPInfo memory info = pvp.getPVPInfo(_tokenId);
        uint256 bal = info.defensiveReport.length;
        if (bal == 0 || _index >= bal) {
            return (reports_, len);
        }

        for (uint8 i = 0; i < _len; ++i) {
            uint32 reportId = info.defensiveReport[_index];
            reports_[i] = pvp.getReport(reportId);
            ++_index;
            ++len;
            if (_index >= bal) {
                return (reports_, len);
            }
        }
    }

    struct PVPObject {
        IWoof.WoofWoofWest woof;
        uint32 reedemTimestamp;
        uint32 slaveOwnerId;
        uint32 slaveProtectEndTime;
        address owner;
    }

    function randomObjectOfPVP(uint32[] memory _ids) public view returns(PVPObject[] memory nfts) {
        require(_ids.length <= 50);
        nfts = new PVPObject[](_ids.length);
        for (uint256 i = 0; i < _ids.length; ++i) {
            IPVP.PVPInfo memory info = pvp.getPVPInfo(_ids[i]);
            nfts[i].woof = woof.getTokenTraits(_ids[i]);
            nfts[i].owner = woof.ownerOf2(_ids[i]);
            nfts[i].reedemTimestamp = info.reedemTimestamp;
            nfts[i].slaveProtectEndTime = info.slaveProtectEndTime;
            nfts[i].slaveOwnerId = info.slaveOwner;
        }
    }
}