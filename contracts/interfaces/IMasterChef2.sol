// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMasterChef2 {
    function cakePerBlock(bool _isRegular) view external returns (uint256 amount);
    function totalRegularAllocPoint() view external returns(uint256);
    function totalSpecialAllocPoint() view external returns(uint256);

    function pendingCake(uint256 _pid, address _user) view external returns (uint256);
    function poolInfo(uint256 _pid) view external returns(uint256 accCakePerShare, uint256 lastRewardBlock, uint256 allocPoint, uint256 totalBoostedShare, bool isRegular);
    function userInfo(uint256 _pid, address _account) view external returns(uint256 amount, uint256 rewardDebt, uint256 boostMultiplier);
    function poolLength() view external returns(uint256);

    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount) external;
    function emergencyWithdraw(uint256 _pid) external;
}
