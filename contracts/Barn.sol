// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./interfaces/IWoofEnumerable.sol";
import "./interfaces/IWoofConfig.sol";
import "./interfaces/IUserDashboard.sol";
import "./library/SafeERC20.sol";
import "./library/SafeMath.sol";
import "./interfaces/IPVP.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

interface IPaw {
    function mint(address to, uint256 amount) external;
}

contract Barn is OwnableUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    event StakeWoof(address indexed owner, uint256 indexed tokenId);
    event UnStakeWoof(address indexed owner, uint256 indexed tokenId, uint256 rewardAmount, uint256 taxAmount);
    event Claim(address indexed owner, uint256 indexed tokenId, uint256 rewardAmount,  uint256 taxAmount);
    event UnStakeWoofs(address indexed owner, uint256 totalRewardAmount,  uint256 totalTaxAmount);
    event ClaimWoofs(address indexed owner, uint256 totalRewardAmount,  uint256 totalTaxAmount);

    // struct to store a stake's token, owner, and earning values
    struct Stake {
        uint32 tokenId;
        uint32 depositTime;
        uint32 lastRewardTime;
        uint256 value;
        address owner;
    }

    IWoofEnumerable public woof;
    IWoofConfig public woofConfig;
    IPaw public paw;

    mapping(uint32 => Stake) public barn;
    mapping(uint32 => Stake[]) public pack;
    mapping(uint32 => uint32) public packIndices;

    mapping(address=>uint32[]) public mapUserNfts;
    uint256[3] public stakedAmountOfEachType;

    uint256 public minerPerPowerOutputOfSec;
    uint256 public hunterPerPowerOutputOfSec;
    uint8 public constant MINER_CLAIM_TAX_PERCENTAGE = 20;
    uint8[3] public staminaRecoveryPerHour;

    uint256 public totalStealBufOfBandit;
    uint256 public unaccountedRewards;
    uint256 public totalMiningPowerOfBandit;
    uint256 public pawPerMiningPowerOfBandit;

    bool public rescueEnabled;
    uint8 public maxPerAmount;

    IPVP public pvp;

    IUserDashboard public userDashboard;
    address public rentManager;
    bool public enableClaim;

    function initialize(
        address _woof,
        address _woofConfig, 
        address _paw
    ) external initializer {
        require(_woof != address(0));
        require(_woofConfig != address(0));
        require(_paw != address(0));

        __Ownable_init();
        __Pausable_init();

        woof = IWoofEnumerable(_woof);
        woofConfig = IWoofConfig(_woofConfig);
        paw = IPaw(_paw);

        minerPerPowerOutputOfSec = 5e17;
        minerPerPowerOutputOfSec = minerPerPowerOutputOfSec / 86400;
        hunterPerPowerOutputOfSec = 5e17;
        hunterPerPowerOutputOfSec = hunterPerPowerOutputOfSec / 86400;
        staminaRecoveryPerHour = [5,2,2];

        unaccountedRewards = 0;
        totalStealBufOfBandit = 0;
        totalMiningPowerOfBandit  = 0;
        pawPerMiningPowerOfBandit = 0;

        rescueEnabled = false;
        maxPerAmount = 100;
        enableClaim = false;
    }

    function setMinerPerPowerOutputOfSec(uint256 _output) external onlyOwner {
        minerPerPowerOutputOfSec = _output / 86400;
    }

    function setHunterPerPowerOutputOfSec(uint256 _output) external onlyOwner {
        hunterPerPowerOutputOfSec = _output / 86400;
    }

    function setStaminaRecoveryPerHour(uint8[3] memory _recovery) external onlyOwner {
        staminaRecoveryPerHour = _recovery;
    }

    function setRescueEnabled(bool _rescueEnabled) external onlyOwner {
        rescueEnabled = _rescueEnabled;
    }

    function setClaimEnable(bool _enable) external onlyOwner {
        enableClaim = _enable;
    }

    function setPVP(address _pvp) external onlyOwner {
        pvp = IPVP(_pvp);
    }

    function setUserDashboard(address _userDashboard) external onlyOwner {
        require(_userDashboard != address(0));
        userDashboard = IUserDashboard(_userDashboard);
    }

    function setRentManager(address _rentManager) external onlyOwner {
        require(_rentManager != address(0));
        rentManager = _rentManager;
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function stakeWoof(uint32 _tokenId) external whenNotPaused {
        address user = _msgSender();
        require(tx.origin == user, "1");
        require(_tokenId > 0, "2");
        require(woof.ownerOf(_tokenId) == user, "3");
        
        woof.transferFrom(user, address(this), _tokenId);
        Stake memory staked;
        staked.tokenId = _tokenId;
        staked.depositTime = uint32(block.timestamp);
        staked.lastRewardTime = uint32(block.timestamp);
        staked.owner = user;
        IWoof.WoofWoofWest memory w = woof.getTokenTraits(_tokenId);
        uint256 miningPower = w.attributes[2];
        if (w.nftType == 1) {
            staked.value = pawPerMiningPowerOfBandit;
            totalMiningPowerOfBandit = totalMiningPowerOfBandit.add(miningPower);
            (uint16 stealBuf, uint16 index) = woofConfig.stealInfoOfBandit(w.level);
            totalStealBufOfBandit = totalStealBufOfBandit.add(stealBuf);
            packIndices[_tokenId] = uint32(pack[index].length);
            pack[index].push(staked);
        } else {
            if (w.nftType == 0) {
                staked.value = minerPerPowerOutputOfSec.mul(miningPower);
            } else {
                staked.value = hunterPerPowerOutputOfSec.mul(miningPower);
            }
            barn[_tokenId] = staked;
        }
        mapUserNfts[user].push(_tokenId);
        stakedAmountOfEachType[w.nftType] += 1;
        emit StakeWoof(user, _tokenId);
    }

    function unstakeWoof(uint32 _tokenId) external {
        require(tx.origin == _msgSender(), "1");
        _unstakeWoof(_tokenId, _msgSender());
    }

    function _unstakeWoof(uint32 _tokenId, address _user) internal {
        require(enableClaim, "2");
        IWoof.WoofWoofWest memory w = woof.getTokenTraits(_tokenId);
        uint256 rewardAmount = 0;
        uint256 taxAmount = 0;
        if (w.nftType == 1)  {
            rewardAmount = _unstakeBandit(w, _user);
        } else {
            (rewardAmount, taxAmount) = _unstakeMinerOrHunter(w, _user);
        }
        _removeUserNft(_user, _tokenId);
        if (mapUserNfts[_user].length == 0) {
            delete mapUserNfts[_user];
        }
        woof.transferFrom(address(this), _msgSender(), _tokenId);
        stakedAmountOfEachType[w.nftType] -= 1;
        emit UnStakeWoof(_user, _tokenId, rewardAmount, taxAmount);
    }

    function unstake(uint32 _nftId, address _renter) public {
        require(_msgSender() == rentManager, "1");
        _unstakeWoof(_nftId, _renter);
    }

    function claim(uint32 _tokenId) external {
        address user = _msgSender();
        require(tx.origin == user, "1");
        require(enableClaim, "2");
        IWoof.WoofWoofWest memory w = woof.getTokenTraits(_tokenId);
        uint256 rewardAmount = 0;
        uint256 taxAmount = 0;
        if (w.nftType == 1) {
            rewardAmount = _claimBandit(w, user);
        } else {
            (rewardAmount, taxAmount) = _claimMinerOrHunter(w, user);
        }
        emit Claim(user, _tokenId, rewardAmount, taxAmount);
    }

    function unstakeWoofs(uint32[] calldata _tokenIds) external {
        require(_tokenIds.length <= 10, "1");
        address user = _msgSender();
        require(tx.origin == user, "2");
        require(enableClaim, "3");
        _claimOrUnstakeMany(true, user, _tokenIds);
    }

    function claimWoofs(uint32[] calldata _tokenIds) external {
        require(_tokenIds.length <= 10, "1");
        address user = _msgSender();
        require(tx.origin == user, "2");
        require(enableClaim, "3");
        _claimOrUnstakeMany(false, user, _tokenIds);
    }

    function rescue() external {
        require(tx.origin == _msgSender(), "1");
        require(rescueEnabled, "2");

        uint32[] memory userTokenIds = mapUserNfts[_msgSender()];
        for (uint256 i = 0; i < userTokenIds.length; ++i) {
            uint256 tokenId = userTokenIds[i];
            woof.transferFrom(address(this), _msgSender(), tokenId);
        }

        delete mapUserNfts[_msgSender()];
    }

    function randomBanditOwner(uint256 _seed) external view returns(address owner, uint32 tokenId) {
        if (totalStealBufOfBandit == 0) {
            return (address(0), 0);
        }
        uint256 bucket = (_seed & 0xFFFFFFFF) % totalStealBufOfBandit;
        uint256 cumulative = 0;
        _seed >>= 32;

        uint16[] memory buf = woofConfig.stealBufOfBandit();
        for (uint32 i = 0; i < buf.length; i++) {
            cumulative += pack[i].length * buf[i];
            if (bucket >= cumulative) continue;
            Stake memory staked = pack[i][_seed % pack[i].length];
            return (staked.owner, staked.tokenId);
        }
        return (address(0), 0);
    }

    function balanceOf(address _user) public view returns(uint256) {
        return mapUserNfts[_user].length;
    }

    function ownerOf(uint32 _tokenId) public view returns(address) {
        IWoof.WoofWoofWest memory w = woof.getTokenTraits(_tokenId);
        if (w.nftType == 1) {
            (, uint16 index) = woofConfig.stealInfoOfBandit(w.level);
            if (pack[index].length == 0) {
                return address(0);
            }
            uint32 pos = packIndices[_tokenId];
            Stake memory staked = pack[index][pos];
            if (staked.tokenId == _tokenId) {
                return staked.owner;
            }
            return address(0);
        } else {
            return barn[_tokenId].owner;
        }
    }

    function farmInfo(address _user) public view returns(
        uint256[3] memory stakedAmountOfEachType_,
        uint256 balance_,
        uint256 totalPendingRewards_
    ) {
        stakedAmountOfEachType_ = stakedAmountOfEachType;
        balance_ = 0;
        totalPendingRewards_ = 0;
        if (_user != address(0)) {
            balance_ = balanceOf(_user);
            uint32[] memory userStakedIds = mapUserNfts[_user];
            for (uint256 i = 0; i < userStakedIds.length; ++i) {
                totalPendingRewards_ += _pendingRewards(userStakedIds[i]);
            }
        }
    }

    struct StakedNft {
        uint8 generation;
        uint8 nftType;  //0: Miner, 1: Bandit, 2: Hunter
        uint8 quality;
        uint8 level;
        uint16 cid;
        uint32 stamina;
        uint32 maxStamina;
        uint32 tokenId;
        uint256 pendingRewards;
        string name;
    }

    function getUserTokenTraits(address _user, uint256 _index, uint8 _len) public view returns(
        StakedNft[] memory nfts, 
        uint8 len
    ) {
        require(_len <= maxPerAmount && _len != 0);
        nfts = new StakedNft[](_len);
        len = 0;

        uint256 bal = balanceOf(_user);
        if (bal == 0 || _index >= bal) {
            return (nfts, len);
        }

        uint32[] memory userTokenIds = mapUserNfts[_user];
        for (uint8 i = 0; i < _len; ++i) {
            uint32 tokenId = userTokenIds[_index];
            StakedNft memory stakedNft;
            stakedNft.tokenId = tokenId;
            IWoof.WoofWoofWest memory nft = woof.getTokenTraits(tokenId);
            stakedNft.generation = nft.generation;
            stakedNft.nftType = nft.nftType;
            stakedNft.quality = nft.quality;
            stakedNft.level = nft.level;
            stakedNft.cid = nft.cid;
            (stakedNft.pendingRewards, stakedNft.stamina) = _pendingRewardsAndStamina(nft);
            stakedNft.maxStamina = nft.attributes[1];
            stakedNft.name = nft.name;
            nfts[i] = stakedNft;
            ++_index;
            ++len;
            if (_index >= bal) {
                return (nfts, len);
            }
        }
    }

    function _unstakeMinerOrHunter(IWoof.WoofWoofWest memory _w, address _user) internal returns(uint256,  uint256) {
        Stake memory staked = barn[_w.tokenId];
        require(staked.owner == _user, "5");
        _updateStamina(staked, _w);

        uint256 pendingAmount = _pendingRewards(staked, _w);
        uint256 taxAmount = 0;
        if (pendingAmount > 0) {
            pendingAmount = _paySlaveTax(_w.tokenId, pendingAmount, true);
            paw.mint(address(this), pendingAmount);
            if (_w.nftType == 0) {
                taxAmount = pendingAmount * MINER_CLAIM_TAX_PERCENTAGE / 100;
                _payBanditTax(taxAmount);
                pendingAmount -= taxAmount;
            }
            IERC20(address(paw)).safeTransfer(_user, pendingAmount);
            userDashboard.rewardFromScene(_user, 0, pendingAmount, 0, 0);
        }
        delete barn[_w.tokenId];
        return (pendingAmount, taxAmount);
    }

    function _unstakeBandit(IWoof.WoofWoofWest memory _w, address _user) internal returns(uint256) {
        (uint16 stealBuf, uint16 index) = woofConfig.stealInfoOfBandit(_w.level);
        uint32 pos = packIndices[_w.tokenId];
        Stake memory staked = pack[index][pos];
        require(staked.owner == _user, "5");
        _updateStamina(staked, _w);

        uint256 miningPower = _w.attributes[2];
        uint256 pendingAmount = miningPower * (pawPerMiningPowerOfBandit - staked.value);
        if (pendingAmount > 0) {
            IERC20(address(paw)).safeTransfer(_user, pendingAmount);
            userDashboard.rewardFromScene(_user, 0, pendingAmount, 0, 0);
        }
        totalMiningPowerOfBandit = totalMiningPowerOfBandit.sub(miningPower);
        totalStealBufOfBandit = totalStealBufOfBandit.sub(stealBuf);

        Stake memory lastStake = pack[index][pack[index].length - 1];
        pack[index][pos] = lastStake; 
        packIndices[lastStake.tokenId] = pos;
        pack[index].pop();
        delete packIndices[_w.tokenId];
        return pendingAmount;
    }

    function _claimMinerOrHunter(IWoof.WoofWoofWest memory _w, address _user) internal returns(uint256, uint256) {
        Stake memory staked = barn[_w.tokenId];
        require(staked.owner == _user, "5");
        uint256 pendingAmount = _pendingRewards(staked, _w);
        uint256 taxAmount = 0;
        if (pendingAmount > 0) {
            pendingAmount = _paySlaveTax(_w.tokenId, pendingAmount, true);
            paw.mint(address(this), pendingAmount);
            if (_w.nftType == 0) {
                taxAmount = pendingAmount * MINER_CLAIM_TAX_PERCENTAGE / 100;
                _payBanditTax(taxAmount);
                pendingAmount -= taxAmount;
            }
            IERC20(address(paw)).safeTransfer(_user, pendingAmount);
            userDashboard.rewardFromScene(_user, 0, pendingAmount, 0, 0);
        }
        staked.lastRewardTime = uint32(block.timestamp);
        barn[_w.tokenId] = staked;
        return (pendingAmount, taxAmount);
    }

    function _claimBandit(IWoof.WoofWoofWest memory _w, address _user) internal returns(uint256) {
        (, uint16 index) = woofConfig.stealInfoOfBandit(_w.level);
        uint32 pos = packIndices[_w.tokenId];
        Stake memory staked = pack[index][pos];
        require(staked.owner == _user, "5");
        uint256 pendingAmount = _pendingRewards(staked, _w);
        if (pendingAmount > 0) {
            IERC20(address(paw)).safeTransfer(_user, pendingAmount);
            userDashboard.rewardFromScene(_user, 0, pendingAmount, 0, 0);
        }
        staked.value = pawPerMiningPowerOfBandit;
        staked.lastRewardTime = uint32(block.timestamp);
        pack[index][pos] = staked;
        return pendingAmount;
    }

    function _claimOrUnstakeMany(bool _unstake, address _user, uint32[] calldata _tokenIds) internal {
        require(mapUserNfts[_user].length > 0, "6");
        uint256 totalRewardAmount = 0;
        uint256 totalPendingAmount = 0;
        uint256 totalTaxAmount = 0;
        for (uint32 i = 0; i < _tokenIds.length; ++i) {
            uint32 tokenId = _tokenIds[i];
            if (_unstake) {
                _removeUserNft(_user, tokenId);
            }
            (uint256 rewardAmount, uint256 pendingAmount, uint256 taxAmount) = _claimOrUnstake(_unstake, _user, tokenId);
            totalRewardAmount += rewardAmount;
            totalPendingAmount += pendingAmount;
            totalTaxAmount += taxAmount;
        }

        if (totalPendingAmount > 0) {
            paw.mint(address(this), totalPendingAmount);
        }
        if (totalRewardAmount > 0) {
            IERC20(address(paw)).safeTransfer(_user, totalRewardAmount);
            userDashboard.rewardFromScene(_user, 0, totalRewardAmount, 0, 0);
        }
        if (totalTaxAmount > 0) {
            _payBanditTax(totalTaxAmount);
        }

        if  (_unstake) {
            if (mapUserNfts[_user].length == 0) {
                delete mapUserNfts[_user];
            }
            emit UnStakeWoofs(_user, totalRewardAmount, totalTaxAmount);
        } else {
            emit ClaimWoofs(_user, totalRewardAmount, totalTaxAmount);
        }
    }

    function _claimOrUnstake(bool _unstake, address _user, uint32 _tokenId) internal returns(uint256 rewardAmount, uint256 pendingAmount, uint256 taxAmount){
        rewardAmount = 0;
        pendingAmount = 0;
        taxAmount = 0;
        IWoof.WoofWoofWest memory w = woof.getTokenTraits(_tokenId);
        if (w.nftType == 1) {
            (uint16 stealBuf, uint16 index) = woofConfig.stealInfoOfBandit(w.level);
            uint32 pos = packIndices[w.tokenId];
            Stake memory staked = pack[index][pos];
            require(staked.owner == _user, "5");
            uint32 miningPower = w.attributes[2];
            rewardAmount = miningPower * (pawPerMiningPowerOfBandit - staked.value);
            rewardAmount = _paySlaveTax(w.tokenId, rewardAmount, false);
            if (_unstake) {
                _updateStamina(staked, w);
                totalMiningPowerOfBandit = totalMiningPowerOfBandit.sub(miningPower);
                totalStealBufOfBandit = totalStealBufOfBandit.sub(stealBuf);
                Stake memory lastStake = pack[index][pack[index].length - 1];
                pack[index][pos] = lastStake; 
                packIndices[lastStake.tokenId] = pos;
                pack[index].pop();
                delete packIndices[w.tokenId];
            } else {
                staked.value = pawPerMiningPowerOfBandit;
                staked.lastRewardTime = uint32(block.timestamp);
                pack[index][pos] = staked;
            }
        } else {
            Stake memory staked = barn[w.tokenId];
            require(staked.owner == _user, "5");
            rewardAmount = _pendingRewards(staked, w);
            rewardAmount = _paySlaveTax(w.tokenId, rewardAmount, true);
            pendingAmount = rewardAmount;
            if (w.nftType == 0) {
                taxAmount = rewardAmount * MINER_CLAIM_TAX_PERCENTAGE / 100;
                rewardAmount -= taxAmount;
            }
            if (_unstake) {
                _updateStamina(staked, w);
                delete barn[w.tokenId];
            } else {
                staked.lastRewardTime = uint32(block.timestamp);
                barn[w.tokenId] = staked;
            }
        }
        if (_unstake) {
            woof.transferFrom(address(this), _user, _tokenId);
            stakedAmountOfEachType[w.nftType] -= 1;
        }
    }

    function _removeUserNft(address _user, uint32 _tokenId) internal {
        uint32[] memory userStakedIds = mapUserNfts[_user];
        for (uint256 i = 0; i < userStakedIds.length; ++i) {
            if (userStakedIds[i] == _tokenId) {
                uint32 lastId = userStakedIds[userStakedIds.length - 1];
                mapUserNfts[_user][i] = lastId;
                mapUserNfts[_user].pop();  
                break;
            }
        }
    }

    function _updateStamina(Stake memory _staked,  IWoof.WoofWoofWest memory _w) internal {
        if (_w.attributes[0] >= _w.attributes[1]) {
            return;
        }

        uint32 stamina = staminaRecoveryPerHour[_w.nftType] * (uint32(block.timestamp) - _staked.depositTime) / 3600;
        if (stamina + _w.attributes[0] > _w.attributes[1]) {
            stamina = _w.attributes[1];
        } else {
            stamina = stamina + _w.attributes[0];
        }
        woof.updateStamina(_staked.tokenId, stamina);
    }

    function _payBanditTax(uint256 _amount) internal {
        if (totalMiningPowerOfBandit == 0)  {
            unaccountedRewards += _amount;
            return;
        }
        pawPerMiningPowerOfBandit += (_amount + unaccountedRewards) / totalMiningPowerOfBandit;
        unaccountedRewards = 0;
    }

    function _pendingRewardsAndStamina(IWoof.WoofWoofWest memory _w) internal view returns(uint256 pending, uint32 stamina) {
        Stake memory staked;
        if (_w.nftType == 1) {
            (, uint16 index) = woofConfig.stealInfoOfBandit(_w.level);
            uint32 pos = packIndices[_w.tokenId];
            staked = pack[index][pos];
        } else {
            staked = barn[_w.tokenId];
        }
        pending = _pendingRewards(staked, _w);
        stamina = _currentStamina(staked, _w);
    }

    function _pendingRewards(uint32 _tokenId) internal view returns(uint256) {
        IWoof.WoofWoofWest memory w = woof.getTokenTraits(_tokenId);
        Stake memory staked;
        if (w.nftType == 1) {
            (, uint16 index) = woofConfig.stealInfoOfBandit(w.level);
            uint32 pos = packIndices[w.tokenId];
            staked = pack[index][pos];
        } else {
            staked = barn[w.tokenId];
        }
        return _pendingRewards(staked, w);
    }

    function _pendingRewards(Stake memory _staked, IWoof.WoofWoofWest memory _w) internal view returns(uint256) {
        if (_w.nftType == 1) {
            uint256 miningPower = _w.attributes[2];
            return miningPower * (pawPerMiningPowerOfBandit - _staked.value);
        } else {
            return _staked.value * (block.timestamp - _staked.lastRewardTime);
        }
    }

    function _currentStamina(Stake memory _staked, IWoof.WoofWoofWest memory _w) internal view returns(uint32) {
        if (_w.attributes[0] >= _w.attributes[1]) {
            return _w.attributes[0];
        }

        uint32 stamina = staminaRecoveryPerHour[_w.nftType] * (uint32(block.timestamp) - _staked.depositTime) / 3600;
        if (stamina + _w.attributes[0] > _w.attributes[1]) {
            stamina = _w.attributes[1];
        } else {
            stamina = stamina + _w.attributes[0];
        }
        return stamina;
    }

    function _paySlaveTax(uint32 _tokenId, uint256 _paw, bool _mint) internal returns(uint256) {
        if (address(pvp) != address(0)) {
            if (_mint) {
                (uint256 pawTax,) = pvp.payTax(_tokenId, _paw, 0);
                _paw -= pawTax;
            } else {
                (address slaveOwner, uint256 pawTax,) = pvp.slaveOwnerAndPayTax(_tokenId, _paw, 0);
                if (slaveOwner != address(0) && pawTax > 0) {
                    IERC20(address(paw)).safeTransfer(slaveOwner, pawTax);
                    _paw -= pawTax;
                }
            }
        }
        return _paw;
    }
}