// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

interface IUserDashboard {
    //_scene: 0 PublicMine, 1 PrivateMine, 2 Loot, 3 Wanted, 4 Explore, 5 PVP, 6 TradeFee, 7 Rank
    function rewardFromScene(address _user, uint32 _scene, uint256 _pawReward, uint256 _gemReward, uint256 _busdReward) external;
}