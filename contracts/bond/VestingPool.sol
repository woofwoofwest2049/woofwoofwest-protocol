// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "../library/SafeERC20.sol";
import "../library/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

interface IFarmPool {
    function payoutToken() external view returns(address);
}

struct UserInfo {
    uint256 vestingTerm;
    uint256 pending;
    uint256 lastRewardTime;
    uint256 amount;
}

contract VestingPool is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event Stake(address indexed _user, uint256 _amount);
    event Reedem(address indexed _user, uint256 _amount);
    event TransferFrom(address indexed _sender, address indexed _from, address _to, uint256 _amount);

    address public farmPool;
    address public stakingToken;
    uint256 public vestingTerm;

    mapping (address=>UserInfo) public userInfo;
    mapping (address=>bool) public approvedController;

    function initialize(
    ) external initializer {
        __Ownable_init();
        __ReentrancyGuard_init();

        vestingTerm = 5 days;
    }

    modifier onlyFarmPool {
        require(farmPool == msg.sender, "caller is not the farm pool");
        _;
    }

    modifier onlyApprovedController {
        require(approvedController[msg.sender] == true, "caller is not approved");
        _;
    }

    function setFarmPool(address _farmPool) external onlyOwner {
        require(_farmPool != address(0));
        farmPool = _farmPool;
        stakingToken = IFarmPool(_farmPool).payoutToken();
    }

    function setVestingTerm(uint256 _vestingTerm) external onlyOwner {
        require( _vestingTerm >= 5 days, "Vesting must be longer than 5 days" );
        vestingTerm = _vestingTerm;
    }

    function setApprovedController(address _controller, bool _enable) external onlyOwner {
        require(_controller != address(0));
        approvedController[_controller] = _enable;
    }

    function getUserInfo(address _user) public view returns(
        uint256 claimableAmount_,
        uint256 lockAmount_,
        uint256 vestingTerm_,
        uint256 lastRewardTime_
    ) {
        UserInfo memory user = userInfo[_user];
        uint256 pending = pendingReward(user);
        claimableAmount_ = pending.add(user.pending);
        lockAmount_ = user.amount.sub(pending);
        vestingTerm_ = user.vestingTerm;
        lastRewardTime_ = user.lastRewardTime;
    }

    function balanceOf(address _user) public view returns(uint256) {
        UserInfo memory user = userInfo[_user];
        return user.pending + user.amount;
    }

    function pendingReward(UserInfo memory user) public view returns(uint256) {
        if (user.amount == 0) {
            return 0;
        }
        if (user.vestingTerm == 0) {
            return user.amount;
        }
        uint256 percent = block.timestamp.sub(user.lastRewardTime).mul(1e12).div(user.vestingTerm);
        if (percent >= 1e12) {
            return user.amount;
        }
        return user.amount.mul(percent).div(1e12);
    }

    function stake(address _user, uint256 _amount) external onlyFarmPool {
        require(_amount > 0, "Invalid amount");
        IERC20(stakingToken).safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        UserInfo memory user = userInfo[_user];
        uint256 pending = pendingReward(user);
        user.pending = user.pending.add(pending);
        user.amount = user.amount.sub(pending).add(_amount);
        user.vestingTerm = vestingTerm;
        user.lastRewardTime = block.timestamp;
        userInfo[_user] = user;
        emit Stake(_user, _amount);
    }

    function reedem() external nonReentrant {
        UserInfo memory user = userInfo[msg.sender];
        uint256 pending = pendingReward(user);
        uint256 claimableAmount = user.pending.add(pending);
        require(claimableAmount > 0, "claimableAmount == 0");
        _safeTransfer(stakingToken, msg.sender, claimableAmount);
        user.pending = 0;
        user.amount = user.amount.sub(pending);
        user.vestingTerm = vestingTerm;
        user.lastRewardTime = block.timestamp;
        userInfo[msg.sender] = user;
        emit Reedem(msg.sender, claimableAmount);
    }

    function transferFrom(address _from, address _to, uint256 _amount) external onlyApprovedController {
        UserInfo memory user = userInfo[_from];
        uint256 pending = pendingReward(user);
        user.pending = user.pending.add(pending);
        user.amount = user.amount.sub(pending);
        user.vestingTerm = vestingTerm;
        user.lastRewardTime = block.timestamp;
        require(user.pending + user.amount >= _amount, "transfer amount exceeds balance");
        if (user.amount >= _amount) {
            user.amount -= _amount;
        } else {
            user.pending = user.pending + user.amount - _amount;
            user.amount = 0;
        }
        _safeTransfer(stakingToken, _to, _amount);
        userInfo[_from] = user;
        emit TransferFrom(msg.sender, _from, _to, _amount);
    }   

    function withdrawBNB(address _to) public onlyOwner {
        payable(_to).transfer(address(this).balance);
    }

    function withdrawBEP20(address _tokenAddress, address _to, uint256 _amount) public onlyOwner {
        require(_tokenAddress != stakingToken, "no auth");
        uint256 tokenBal = IERC20(_tokenAddress).balanceOf(address(this));
        if (_amount == 0 || _amount >= tokenBal) {
            _amount = tokenBal;
        }
        IERC20(_tokenAddress).transfer(_to, _amount);
    }

    function _safeTransfer(address _token, address _to, uint256 _amount) internal {
        uint256 bal = IERC20(_token).balanceOf(address(this));
        if (_amount > bal) {
            _amount = bal;
        }
        if (_amount == 0) {
            return;
        }
        IERC20(_token).safeTransfer(_to, _amount);
    }
}