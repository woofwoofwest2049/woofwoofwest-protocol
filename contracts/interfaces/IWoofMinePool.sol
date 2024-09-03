// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

interface IWoofMinePool {
    struct StakedHunter {
        uint32 tokenId;
        uint32 depositTime;
    }
    
    struct StakedMiner {
        uint32 tokenId;
        uint32 depositTime;
        uint32 lastRewardTime;
        uint32 maxWorkingTime;
        uint256 pendingPaw;
        uint256 pendingGem;
    }

    struct Reward {
        uint32 lastRewardTime;
        uint256 pendingPaw;
        uint256 pendingGem;
    }
}