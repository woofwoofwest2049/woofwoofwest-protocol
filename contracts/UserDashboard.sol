// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IUserDashboard.sol";
import "./library/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

struct UserRewardInfo {
    uint256 accRewardPaw;
    uint256 accRewardGem;
    uint256 accRewardBUSD;
}

contract UserDashboard is IUserDashboard, OwnableUpgradeable {
    mapping(address => bool) public authControllers;
    mapping(address => mapping(uint32=>UserRewardInfo)) public userRewardInfo;
    uint32 public sceneAmount;

    function initialize() external initializer {
        __Ownable_init();
        sceneAmount = 8;
    }

    function setSceneAmount(uint32 _amount) external onlyOwner {
        sceneAmount = _amount;
    }

    function setAuthControllers(address _controller, bool _enable) external onlyOwner {
        authControllers[_controller] = _enable;
    }

    //_scene: 0 PublicMine, 1 PrivateMine, 2 Loot, 3 Wanted, 4 Explore, 5 PVP, 6 TradeFee, 7 Rank
    function rewardFromScene(address _user, uint32 _scene, uint256 _pawReward, uint256 _gemReward, uint256 _busdReward) external override {
        require(authControllers[msg.sender] == true, "No auth");
        UserRewardInfo memory info = userRewardInfo[_user][_scene];
        info.accRewardPaw += _pawReward;
        info.accRewardGem += _gemReward;
        info.accRewardBUSD += _busdReward;
        userRewardInfo[_user][_scene] = info;
    }

    function rewardInfoOf(address _user) public view returns(UserRewardInfo[] memory rewards) {
        rewards = new UserRewardInfo[](sceneAmount);
        for (uint32 i = 0; i < sceneAmount; ++i) {
            rewards[i] = userRewardInfo[_user][i];
        }
    }
}