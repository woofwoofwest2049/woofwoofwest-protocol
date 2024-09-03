
// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

interface IPVP {
    struct PVPInfo {
        uint32 lastBattleTimestamp;
        uint32 reedemTimestamp;
        uint32 slaveProtectEndTime;
        uint32 slaveOwner;
        uint32 powerSnapShot;
        uint32[] slaves;
        uint32[] attackReport;
        uint32[] defensiveReport;
        uint256 taxPaw;
        uint256 taxGem;
    }

    struct Report {
        //0: Stone, 1: Scissors, 2: Paper
        bool attackWin;
        uint8[5] attackFormation;  
        uint8[5] defensiveFormation;
        uint32 pvpTime;
        uint32 attackId;
        uint32 defensiveId;
        uint32[5] attackHit;
        uint32[5] defensiveHit;
        uint32[5] attackHP;
        uint32[5] defensiveHP;
    }

    function totalReportCount() external view returns(uint256);
    function slaveOwnerAndPayTax(uint32 _tokenId, uint256 _paw, uint256 _gem) external returns(address, uint256, uint256);
    function payTax(uint32 _tokenId, uint256 _paw, uint256 _gem) external returns(uint256, uint256);
}

interface IPVPLogic {
    function pvp(uint32 _attackTokenId, uint32 _defensiveTokenId) external view returns(IPVP.Report memory);
}