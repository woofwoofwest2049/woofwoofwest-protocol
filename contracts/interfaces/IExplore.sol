// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

interface IExplore {
    struct ExploreRecord {
        uint8 result;
        uint16 exploreId;
        uint16 eventId;
        uint16[4] dropItems;
        uint16 dropEquipmentBlindBox;
        uint32 nftId;
        uint32 rewardBabyId;
        uint32 startTime;
        uint32 endTime;
        uint256 pawRewardAmount;
        uint256 gemRewardAmount;
        address explorer;
    }

    function getLastNftExploreRecords(uint32 _nftId) external view returns(ExploreRecord memory record, uint256 recordId);
}