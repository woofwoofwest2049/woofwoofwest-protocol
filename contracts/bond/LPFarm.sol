// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "../library/SafeERC20.sol";
import "../library/SafeMath.sol";
import "../interfaces/IWoofEnumerable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

interface IGemMintHelper {
    function mint(address _account, uint256 _amount) external;
    function gem() external view returns(address);
}

contract LPFarm is OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint32 nftId;
        uint32 depositedAt;
        uint256 power;
        uint256 depositAmt;
        uint256 shares;
        uint256 pending; 
        uint256 rewardPaid;
    }

    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 amount, uint256 shares);
    event WithdrawAll(address indexed user, uint256 amount, uint256 earnedAmt, uint256 shares, uint256 nftId);
    event EmergencyWithdrawAll(address indexed user, uint256 amount, uint256 shares, uint256 nftId);
    event Claim(address indexed user, uint256 earnedAmt);
    event Stake(address indexed user, uint256 nftId);
    event UnStake(address indexed user, uint256 nftId);

    address public stakingToken;
    address public daoAddress;
    uint256 public minDepositTimeWithNoFee;
    uint256 public withdrawFeeFactor; // 0.5% fee for withdrawals within 7 days
    IGemMintHelper public gemMintHelper;
    IWoofEnumerable public woof;

    uint256 public gemPerBlock;
    uint256 public lastRewardBlock;
    uint256 public sharesTotal;
    uint256 public totalDepositAmount;
    uint256 public maxPower;
    uint256 public accPerShare;
    uint256 public MAX_REWARD_AMOUNT;
    uint256 public totalRewardAmount;
    uint256 public unitPower;

    mapping(address=>UserInfo) public users;

    function initialize (
        address _stakingToken,
        address _daoAddress,
        address _gemMintHelper,
        address _woof
    ) 
        external initializer
    {
        require(_stakingToken != address(0));
        require(_daoAddress != address(0));
        require(_gemMintHelper != address(0));
        require(_woof != address(0));

        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        stakingToken = _stakingToken;
        daoAddress = _daoAddress;
        gemMintHelper = IGemMintHelper(_gemMintHelper);
        woof = IWoofEnumerable(_woof);
        minDepositTimeWithNoFee = 7 days;
        withdrawFeeFactor = 50;
        gemPerBlock = 1e17;
        MAX_REWARD_AMOUNT = 50000000 ether;
        unitPower = 100;
    }

    function setMaxRewardAmount(uint256 _amount) public onlyOwner {
        require(_amount > 10000000);
        MAX_REWARD_AMOUNT = _amount;
    }

    function setDaoAddress(address _daoAddress) public onlyOwner {
        require(_daoAddress != address(0));
        daoAddress = _daoAddress;
    }

    function setGemPerBlock(uint256 _perBlock) public onlyOwner {
        gemPerBlock = _perBlock;
    }

    function setMinDepositTimeWithNoFee(uint256 _minTime) public onlyOwner {
        minDepositTimeWithNoFee = _minTime;
    }
 
    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function farmInfo() public view returns(
        address stakingToken_, 
        address earnedToken_, 
        uint256 totalDepositAmount_, 
        uint256 sharesTotal_,
        uint256 maxRewardAmount_, 
        uint256 totalRewardAmount_, 
        uint256 dailyReward_,
        uint256 maxPower_
    ) {
        stakingToken_ = stakingToken;
        earnedToken_ = gemMintHelper.gem();
        totalDepositAmount_ = totalDepositAmount;
        sharesTotal_ = sharesTotal;
        (maxRewardAmount_, totalRewardAmount_) = rewardAmountInfo();
        dailyReward_ = gemPerBlock * 28800;
        maxPower_ = (maxPower == 0) ? unitPower : maxPower;
    }

    function userInfo(address _user) public view returns(uint32 nftId_, uint32 depositedAt_, uint256 depostAmt_, uint256 power_, uint256 pendingReward_) {
        UserInfo memory user = users[_user];
        nftId_ = user.nftId;
        depositedAt_ = user.depositedAt;
        depostAmt_ = user.depositAmt;
        power_ = user.power;
        pendingReward_ = pendingGem(_user);
    }

    function pendingGem(address _user) public view returns (uint256) {
        if (lastRewardBlock == 0) {
            return 0;
        }
        UserInfo memory user = users[_user];
        uint256 supply = sharesTotal;
        uint256 tempAccPerShare = accPerShare;
        if (block.number > lastRewardBlock && supply != 0) {
            uint256 multiplier = getMultiplier(lastRewardBlock, block.number);
            uint256 gemReward = multiplier.mul(gemPerBlock);
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
        if (lastRewardBlock != 0 && block.number > lastRewardBlock) {
            uint256 multiplier = getMultiplier(lastRewardBlock, block.number);
            uint256 gemReward = multiplier.mul(gemPerBlock);
            totalRewardAmount_ += gemReward;
            if (totalRewardAmount_ > maxRewardAmount_) {
                totalRewardAmount_ = maxRewardAmount_;
            }
        }
    }

    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        return _to.sub(_from);
    }

    function deposit(uint256 _amount) external whenNotPaused nonReentrant {
        require(_amount > 0, "_amount == 0");
        _updatePool();

        IERC20(stakingToken).safeTransferFrom(msg.sender, address(this), _amount);
        UserInfo memory user = users[msg.sender];
        if (user.power == 0) {
            user.power = unitPower;
        }
        uint256 addShares = _amount.mul(user.power).div(unitPower);
        uint256 pending = user.shares.mul(accPerShare).div(1e12).sub(user.rewardPaid);
        user.pending = user.pending.add(pending);
        user.depositAmt = user.depositAmt.add(_amount);
        user.shares = user.shares.add(addShares);
        user.rewardPaid = user.shares.mul(accPerShare).div(1e12);
        user.depositedAt = uint32(block.timestamp);
        users[msg.sender] = user;

        totalDepositAmount = totalDepositAmount.add(_amount);
        sharesTotal = sharesTotal.add(addShares);
        emit Deposit(msg.sender, _amount, addShares);
    }

    function withdraw(uint256 _amount) external nonReentrant {
        require(_amount > 0, "_amount == 0");

        UserInfo memory user = users[msg.sender];
        require(user.depositAmt >= _amount, "user deposit amount < amount");

        _updatePool();
        uint256 delShares = _amount.mul(user.power).div(unitPower);
        uint256 pending = user.shares.mul(accPerShare).div(1e12).sub(user.rewardPaid);
        user.pending = user.pending.add(pending);
        user.depositAmt = user.depositAmt.sub(_amount);
        user.shares = user.shares.sub(delShares);
        user.rewardPaid = user.shares.mul(accPerShare).div(1e12);
        users[msg.sender] = user;

        totalDepositAmount = totalDepositAmount.sub(_amount);
        sharesTotal = sharesTotal.sub(delShares);
        _amount = _payWithdrawFee(user.depositedAt, _amount);
        _safeTransfer(stakingToken, msg.sender, _amount);
        emit Withdraw(msg.sender, _amount, delShares);
    }

    function withdrawAll() external nonReentrant {
        UserInfo memory user = users[msg.sender];
        require(user.shares > 0, "user shares == 0");

        _updatePool();
        uint256 pending = user.shares.mul(accPerShare).div(1e12).sub(user.rewardPaid);
        uint256 earned = user.pending.add(pending);
        _safeTransfer(gemMintHelper.gem(), msg.sender, earned);

        uint256 amount = _payWithdrawFee(user.depositedAt, user.depositAmt);
        _safeTransfer(stakingToken, msg.sender, amount);
        if (user.nftId > 0) {
            woof.transferFrom(address(this), msg.sender, user.nftId);
        }

        totalDepositAmount = totalDepositAmount.sub(user.depositAmt);
        sharesTotal = sharesTotal.sub(user.shares);
        delete users[msg.sender];
        emit WithdrawAll(msg.sender, amount, earned, user.shares, user.nftId);
    }

    function emergencyWithdrawAll() external nonReentrant {
        UserInfo memory user = users[msg.sender];
        require(user.shares > 0, "user shares == 0");

        uint256 amount = _payWithdrawFee(user.depositedAt, user.depositAmt);
        _safeTransfer(stakingToken, msg.sender, amount);
        if (user.nftId > 0) {
            woof.transferFrom(address(this), msg.sender, user.nftId);
        }

        totalDepositAmount = totalDepositAmount.sub(user.depositAmt);
        sharesTotal = sharesTotal.sub(user.shares);
        delete users[msg.sender];
        emit EmergencyWithdrawAll(msg.sender, amount, user.shares, user.nftId);
    }

    function claim() external whenNotPaused nonReentrant {
        _updatePool();
        UserInfo memory user = users[msg.sender];
        uint256 pending = user.shares.mul(accPerShare).div(1e12).sub(user.rewardPaid);
        uint256 earned = user.pending.add(pending);
        user.pending = 0;
        user.rewardPaid = user.shares.mul(accPerShare).div(1e12);
        _safeTransfer(gemMintHelper.gem(), msg.sender, earned);
        users[msg.sender] = user;
        emit Claim(msg.sender, earned);
    }

    function stake(uint32 _nftId) external whenNotPaused nonReentrant {
        require(woof.ownerOf(_nftId) == msg.sender, "Not owner");
        _updatePool();
        woof.transferFrom(msg.sender, address(this), _nftId);

        uint256 power = getPower(_nftId);
        UserInfo memory user = users[msg.sender];
        if (user.nftId > 0) {
            woof.transferFrom(address(this), msg.sender, user.nftId);
        }

        uint256 pending = user.shares.mul(accPerShare).div(1e12).sub(user.rewardPaid);
        user.pending = user.pending.add(pending);
        sharesTotal = sharesTotal.sub(user.shares);
        user.shares = user.depositAmt.mul(power).div(unitPower);
        user.rewardPaid = user.shares.mul(accPerShare).div(1e12);
        sharesTotal = sharesTotal.add(user.shares);
        user.nftId = _nftId;
        user.power = power;
        users[msg.sender] = user;
        if (power > maxPower) {
            maxPower = power;
        }
        emit Stake(msg.sender, _nftId);
    }

    function unstake() external nonReentrant {
        UserInfo memory user = users[msg.sender];
        uint32 nftId = user.nftId;
        require(user.nftId > 0, "No staked nft");
        _updatePool();

        woof.transferFrom(address(this), msg.sender, user.nftId);
        uint256 power = unitPower;
        uint256 pending = user.shares.mul(accPerShare).div(1e12).sub(user.rewardPaid);
        user.pending = user.pending.add(pending);
        sharesTotal = sharesTotal.sub(user.shares);
        user.shares = user.depositAmt.mul(power).div(unitPower);
        user.rewardPaid = user.shares.mul(accPerShare).div(1e12);
        sharesTotal = sharesTotal.add(user.shares);
        user.nftId = 0;
        user.power = power;
        users[msg.sender] = user;
        emit UnStake(msg.sender, nftId);
    }

    function withdrawBEP20(address _token, address _to, uint256 _amount) public onlyOwner {
        require(_token != stakingToken);
        uint256 bal = IERC20(_token).balanceOf(address(this));
        if (_amount == 0 || _amount >= bal) {
            _amount = bal;
        }
        IERC20(_token).transfer(_to, _amount);
    }

    function getPower(uint32 _tokenId) public view returns(uint256) {
        if (_tokenId == 0) {
            return unitPower;
        }

        return woof.miningPowerOf(_tokenId);
    }

    function _safeTransfer(address _token, address _to, uint256 _amount) internal {
        uint256 bal = IERC20(_token).balanceOf(address(this));
        if (_amount > bal) {
            IERC20(_token).safeTransfer(_to, bal);
        } else {
            IERC20(_token).safeTransfer(_to, _amount);
        }
    }

    function _payWithdrawFee(uint256 _depositedAt, uint256 _amount) internal returns(uint256) {
        bool hasFee = (_depositedAt.add(minDepositTimeWithNoFee) > block.timestamp) ? true : false;
        if (hasFee) {
            uint256 fee = _amount * withdrawFeeFactor / 10000;
            _safeTransfer(stakingToken, daoAddress, fee);
            _amount = _amount.sub(fee);
        }
        return _amount;
    }

    function _updatePool() internal {
        if (sharesTotal <= 0) {
            lastRewardBlock = block.number;
            return;
        }

        if (lastRewardBlock == 0) {
            lastRewardBlock = block.number;
            return;
        }

        if (block.number <= lastRewardBlock) {
            return;
        }

        if (totalRewardAmount >= MAX_REWARD_AMOUNT) {
            lastRewardBlock = block.number;
            return;
        }

        uint256 multiplier = getMultiplier(lastRewardBlock, block.number);
        uint256 gemReward = multiplier.mul(gemPerBlock);
        if (totalRewardAmount + gemReward > MAX_REWARD_AMOUNT) {
            gemReward = MAX_REWARD_AMOUNT - totalRewardAmount;
        }
        accPerShare = accPerShare.add(gemReward.mul(1e12).div(sharesTotal));
        totalRewardAmount += gemReward;
        lastRewardBlock = block.number;
        if (gemReward > 0) {
            gemMintHelper.mint(address(this), gemReward);
        }
    }
}