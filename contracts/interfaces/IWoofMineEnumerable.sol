// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./IWoofMine.sol";
import "./IERC721Enumerable.sol";

interface IWoofMineEnumerable is IWoofMine, IERC721Enumerable {
    struct WoofBrief {
        uint8 nftType;
        uint8 quality;
        uint8 level;
        uint16 cid;
        uint32 stamina;
        uint32 tokenId;
        uint256 pendingGem;
        uint256 pendingPaw;
        string name;
    }

    struct WoofMineBrief {
        uint8 quality;
        uint8 level;
        uint8 dailyLootCount;
        uint16 cid;
        uint32 totalLootCount;
        uint32 tokenId;
        uint32 miningPower;
        uint32 lastRewardTime;
        uint256 perPowerOutputGemOfSec;
        uint256 perPowerOutputPawOfSec;
        uint256 pendingGem;
        uint256 pendingPaw;
        WoofBrief[] miners;
        WoofBrief hunter;
    }
}