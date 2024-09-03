// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./interfaces/IWoofEnumerable.sol";
import "./interfaces/IUserDashboard.sol";
import "./library/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

interface IGemMintHelper {
    function mint(address _account, uint256 _amount) external;
    function gem() external view returns(address);
}

contract RankReward is OwnableUpgradeable, PausableUpgradeable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event Claim(address indexed account, uint32 indexed nft, uint256 reward);

    IWoofEnumerable public woof;
    IGemMintHelper public gemMintHelper;
    address public gem;
    IUserDashboard public userDashboard;

    uint32 public rankAmount;
    uint256[] public rewardAmount;
    uint256 public totalRewardAmount;
    uint256 public accRewardedAmount;
    mapping(uint32 => uint256) public nftRankReward;

    mapping(address => bool) public authControllers;
    uint256 public lastAirdropTime;
    uint32 public duration;

    function initialize(address _gemMintHelper, address _woof) external initializer {
        require(_gemMintHelper != address(0));
        require(_woof != address(0));
        
        __Ownable_init();
        __Pausable_init();

        gemMintHelper = IGemMintHelper(_gemMintHelper);
        gem = gemMintHelper.gem();
        woof = IWoofEnumerable(_woof);
        authControllers[_msgSender()] = true;
        duration = 7 days;
    }

    function setAuthControllers(address _controller, bool _enable) external onlyOwner {
        authControllers[_controller] = _enable;
    }

    function setRewardAmount(uint256[] memory _rewardAmount, uint32[] memory _count) public onlyOwner {
        _setRewardAmount(_rewardAmount, _count);
    }

    function setUserDashboard(address _userDashboard) external onlyOwner {
        require(_userDashboard != address(0));
        userDashboard = IUserDashboard(_userDashboard);
    }

    function setDuration(uint32 _duration) external onlyOwner {
        duration = _duration;
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function resetLastAirdropTime() external onlyOwner {
        lastAirdropTime = 0;
    }

    function airdrop(uint32[] memory _nfts) external whenNotPaused {
        require (lastAirdropTime + duration + 300 <= block.timestamp, "No time!");
        require(authControllers[_msgSender()] == true, "No auth");
        require(_nfts.length == rankAmount);
        uint256 bal = balanceOf(gem);
        if (bal < totalRewardAmount) {
            gemMintHelper.mint(address(this), totalRewardAmount - bal);
        }
        uint256[] memory _rewardAmount = rewardAmount;
        for (uint256 i = 0; i < _nfts.length; ++i) {
            nftRankReward[_nfts[i]] += _rewardAmount[i];
        }
        accRewardedAmount += totalRewardAmount;
        lastAirdropTime = block.timestamp;
    }

    function balanceOf(address _token) public view returns(uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    function pendingReward(uint32 _nft) public view returns(uint256) {
        return nftRankReward[_nft];
    }

    function claim(uint32 _nft) external {
        require(woof.ownerOf(_nft) == _msgSender(), "Not owner");
        uint256 reward = nftRankReward[_nft];
        if (reward == 0) {
            return;
        }

        _safeTransfer(gem, _msgSender(), reward);
        userDashboard.rewardFromScene(_msgSender(), 7, 0, reward, 0);
        nftRankReward[_nft] = 0;
        emit Claim(_msgSender(), _nft, reward);
    }

    function _setRewardAmount(uint256[] memory _rewardAmount, uint32[] memory _count) private {
        require(_rewardAmount.length == _count.length);
        totalRewardAmount = 0;
        rankAmount = 0;
        for (uint256 i = 0; i < _rewardAmount.length; ++i) {
            _rewardAmount[i] = _rewardAmount[i] * 1e18;
            totalRewardAmount += _rewardAmount[i] * _count[i];
            rankAmount += _count[i];
        }
        rewardAmount = new uint256[](rankAmount);
        uint256 index = 0;
        for (uint256 i = 0; i < _rewardAmount.length; ++i) {
            for (uint256 j = 0; j < _count[i]; ++j) {
                rewardAmount[index] = _rewardAmount[i];
                index += 1;
            }
        }
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