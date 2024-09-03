// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;
import "./library/SafeERC20.sol";
import "./library/SafeMath.sol";
import "./interfaces/IWETH.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

interface IGemMintHelper {
    function mint(address _account, uint256 _amount) external;
    function gem() external view returns(address);
}

contract Staking is OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct UserInfo {
        uint256 shares;
        uint256 pending; 
        uint256 rewardPaid;
    }

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event WithdrawAll(address indexed user, uint256 amount, uint256 earned);
    event ClaimGem(address indexed user, uint256 earned);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    address public WBTC;
    IGemMintHelper public gemMintHelper;

    uint256 public gemPerSec;
    uint256 public lastRewardTimestamp;
    uint256 public accPerShare;
    uint256 public MAX_REWARD_AMOUNT;
    uint256 public totalRewardAmount;
    bool public enableClaim;

    mapping (address=>UserInfo) public users;
    address public vestingPool;


    function initialize(
        address _wbtc,
        address _gemMintHelper,
        uint256 _startTimestamp
    ) external initializer {
        require(_wbtc != address(0), "Invalid wbtc");
        require(_gemMintHelper != address(0));

        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        WBTC = _wbtc;
        gemMintHelper = IGemMintHelper(_gemMintHelper);
        lastRewardTimestamp = (_startTimestamp > 0) ? _startTimestamp : block.timestamp;
        accPerShare = 0;
        gemPerSec = 1e17;
        MAX_REWARD_AMOUNT = 500000 ether;
        totalRewardAmount = 0;
        enableClaim = false;
    }

    function setGemPerSec(uint256 _perSec) external onlyOwner {
        updatePool();
        gemPerSec = _perSec;
    }

    function setMaxRewardAmount(uint256 _maxRewardAmount) external onlyOwner {
        MAX_REWARD_AMOUNT = _maxRewardAmount;
        updatePool();
    }

    function setEnableClaim(bool _enable) external onlyOwner {
        enableClaim = _enable;
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function farmInfo() public view returns(uint256 totalStakingAmount_, uint256 maxRewardAmount_, uint256 totalRewardAmount_, uint256 dailyReward_) {
        totalStakingAmount_ = IERC20(WBTC).balanceOf(address(this));
        (maxRewardAmount_, totalRewardAmount_) = rewardAmountInfo();
        dailyReward_ = gemPerSec * 86400;
    }

    function userInfo(address _user) public view returns(uint256 stakingAmount_, uint256 pendingGem_) {
        UserInfo memory user = users[_user];
        stakingAmount_ = user.shares;
        pendingGem_ = pendingGem(_user);
    }

    function pendingGem(address _user) public view returns (uint256) {
        UserInfo memory user = users[_user];
        uint256 supply = IERC20(WBTC).balanceOf(address(this));
        uint256 tempAccPerShare = accPerShare;
        if (block.timestamp > lastRewardTimestamp && supply != 0) {
            uint256 multiplier = getMultiplier(lastRewardTimestamp, block.timestamp);
            uint256 gemReward = multiplier.mul(gemPerSec);
            if (totalRewardAmount + gemReward > MAX_REWARD_AMOUNT) {
                gemReward = MAX_REWARD_AMOUNT - totalRewardAmount;
            }
            tempAccPerShare = tempAccPerShare.add(gemReward.mul(1e12).div(supply));
        }

        uint256 pending = user.pending.add(user.shares.mul(tempAccPerShare).div(1e12).sub(user.rewardPaid));
        return pending;
    }

    function rewardAmountInfo() public view returns(uint256 maxRewardAmount_, uint256 totalRewardAmount_) {
        maxRewardAmount_ = MAX_REWARD_AMOUNT;
        totalRewardAmount_ = totalRewardAmount;
        if (block.timestamp > lastRewardTimestamp) {
            uint256 multiplier = getMultiplier(lastRewardTimestamp, block.timestamp);
            uint256 gemReward = multiplier.mul(gemPerSec);
            totalRewardAmount_ += gemReward;
            if (totalRewardAmount_ > maxRewardAmount_) {
                totalRewardAmount_ = maxRewardAmount_;
            }
        }
    }

    function updatePool() public {
        if (block.timestamp <= lastRewardTimestamp) {
            return;
        }

        if (totalRewardAmount >= MAX_REWARD_AMOUNT) {
            lastRewardTimestamp = block.timestamp;
            return;
        }

        uint256 supply = IERC20(WBTC).balanceOf(address(this));
        if (supply <= 0) {
            lastRewardTimestamp = block.timestamp;
            return;
        }

        uint256 multiplier = getMultiplier(lastRewardTimestamp, block.timestamp);
        uint256 gemReward = multiplier.mul(gemPerSec);
        if (totalRewardAmount + gemReward > MAX_REWARD_AMOUNT) {
            gemReward = MAX_REWARD_AMOUNT - totalRewardAmount;
        }
        accPerShare = accPerShare.add(gemReward.mul(1e12).div(supply));
        totalRewardAmount += gemReward;
        lastRewardTimestamp = block.timestamp;
    }

    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        return _to.sub(_from);
    }

    function deposit(uint256 _amount) external payable whenNotPaused nonReentrant {
        require(_amount > 0, "_amount == 0");
        require(_amount == msg.value, "amount != msg.value");
        updatePool();
        IWETH(WBTC).deposit{value: msg.value}();
        UserInfo storage user = users[msg.sender];
        uint256 pending = user.shares.mul(accPerShare).div(1e12).sub(user.rewardPaid);
        user.pending = user.pending.add(pending);
        user.shares = user.shares.add(_amount);
        user.rewardPaid = user.shares.mul(accPerShare).div(1e12);

        emit Deposit(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external nonReentrant {
        require(_amount > 0, "_amount == 0");

        UserInfo storage user = users[msg.sender];
        require(user.shares >= _amount, "user shares < amount");

        updatePool();
        uint256 pending = user.shares.mul(accPerShare).div(1e12).sub(user.rewardPaid);
        user.pending = user.pending.add(pending);
        user.shares = user.shares.sub(_amount);
        user.rewardPaid = user.shares.mul(accPerShare).div(1e12);

        IWETH(WBTC).withdraw(_amount);
        SafeERC20.safeTransferETH(msg.sender, _amount);

        emit Withdraw(msg.sender, _amount);
    }

    function withdrawAll() external nonReentrant {
        require(enableClaim == true, "disable claim");
        UserInfo memory user = users[msg.sender];
        require(user.shares > 0, "user shares == 0");

        updatePool();
        IWETH(WBTC).withdraw(user.shares);
        SafeERC20.safeTransferETH(msg.sender, user.shares);

        uint256 pending = user.shares.mul(accPerShare).div(1e12).sub(user.rewardPaid);
        uint256 earnedGem = user.pending.add(pending);
        gemMintHelper.mint(msg.sender, earnedGem);

        delete users[msg.sender];
        emit WithdrawAll(msg.sender, user.shares, earnedGem);
    }

    function claimGem() external whenNotPaused nonReentrant {
        require(enableClaim == true, "disable claim");
        updatePool();
        UserInfo storage user = users[msg.sender];
        uint256 pending = user.shares.mul(accPerShare).div(1e12).sub(user.rewardPaid);
        uint256 earnedGem = user.pending.add(pending);
        user.pending = 0;
        user.rewardPaid = user.shares.mul(accPerShare).div(1e12);
        gemMintHelper.mint(msg.sender, earnedGem);
        emit ClaimGem(msg.sender, earnedGem);
    }

    function emergencyWithdraw() public nonReentrant {
        UserInfo memory user = users[msg.sender];
        require(user.shares > 0, "user shares == 0");
        IWETH(WBTC).withdraw(user.shares);
        SafeERC20.safeTransferETH(msg.sender, user.shares);
        delete users[msg.sender];
        emit EmergencyWithdraw(msg.sender, user.shares);
    }

    function withdrawBEP20(address _tokenAddress, address _to, uint256 _amount) public onlyOwner {
        require(_tokenAddress != WBTC);
        uint256 tokenBal = IERC20(_tokenAddress).balanceOf(address(this));
        if (_amount == 0 || _amount >= tokenBal) {
            _amount = tokenBal;
        }
        IERC20(_tokenAddress).transfer(_to, _amount);
    }

    receive() external payable {
        assert(msg.sender == WBTC); // only accept ETH via fallback from the WETH contract
    }
}