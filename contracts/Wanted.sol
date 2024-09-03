// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./library/SafeERC20.sol";
import "./library/SafeMath.sol";
import "./interfaces/IWoofEnumerable.sol";
import "./interfaces/IPVP.sol";
import "./interfaces/IUserDashboard.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

interface IRandom {
    function getRandom(uint256 _seed) external view returns (uint256);
    function multiRandomSeeds(uint256 _seed, uint256 _count) external view returns (uint256[] memory);
    function addNonce() external;
}

contract Wanted is OwnableUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    event PayForHunter(address indexed owner, uint256 indexed banditId, uint256 taxPawAmount, uint256 taxGemAmount);
    event WantedBandit(address indexed owner, uint256 indexed hunterId, uint256 indexed banditId);
    event FreeWantedBandit(address indexed owner, uint256 indexed hunterId, uint256 indexed banditId, uint256 pawRewards, uint256 gemRewards);
    event Claim(address indexed owner, uint256 indexed hunterId, uint256 pawRewards, uint256 gemRewards);
    event FreeAllBandit(address indexed owner, uint256 indexed hunterId);

    struct BanditPayInfo {
        uint32[] hunters;
        uint256 totalMiningPower;
        uint256 accGemPerMiningPower;
        uint256 accPawPerMiningPower;
    }
    struct WantedBanditInfo {
        uint32 banditId;
        uint256 pendingPaw;
        uint256 rewardPaidPaw;
        uint256 accRewardPaw;
        uint256 pendingGem;
        uint256 rewardPaidGem;
        uint256 accRewardGem;
    }

    struct WantedVesting {
        uint32 lastClaimTime;
        uint256 pendingPaw;
        uint256 rewardPaidPaw;
        uint256 pendingGem;
        uint256 rewardPaidGem;
    }

    mapping (uint32=>BanditPayInfo) public banditPayInfo;
    mapping (uint32=>WantedBanditInfo[]) public wantedBanditInfo;
    mapping (uint32=>WantedVesting) public wantedVesting;
    uint8[20] public maxWantedCountOfLevel;
    uint256 public constant UNIT = 1e12;

    IWoofEnumerable public woof;
    IRandom public random;
    address public paw;
    address public gem;

    mapping(address => bool) public authControllers;
    uint8 public banditTax;

    uint8 public costStaminaOfWanted;
    uint8 public costStaminaOfFree;

    uint256 public perPowerMaxClaimPawAmount;
    uint256 public perPowerMaxClaimGemAmount;

    uint256 public claimCD;
    IPVP public pvp;

    IUserDashboard public userDashboard;
    uint256 public maxWantedCountOfBandit;

    function initialize(
        address _woof,
        address _paw,
        address _gem,
        address _random
    ) external initializer {
        require(_woof != address(0));
        require(_paw != address(0));
        require(_gem != address(0));
        require(_random != address(0));

        __Ownable_init();
        __Pausable_init();

        woof = IWoofEnumerable(_woof);
        paw = _paw;
        gem = _gem;
        random = IRandom(_random);
        maxWantedCountOfLevel = [3,3,3,3,3,3,4,4,4,4,4,4,5,5,5,5,5,5,6,6];
        costStaminaOfWanted = 20;
        costStaminaOfFree = 20;
        banditTax = 50;

        perPowerMaxClaimPawAmount = 3 ether;
        perPowerMaxClaimGemAmount = 5e15;

        claimCD = 1 days;
        maxWantedCountOfBandit = 20;
    }

    function setMaxWantedCountOfLevel(uint8[20] memory _maxWantedCountOfLevel) external onlyOwner {
        maxWantedCountOfLevel = _maxWantedCountOfLevel;
    }

    function setCostStamina(uint8 _cost, uint8 _type) external onlyOwner {
        if (_type == 0) {
            costStaminaOfWanted = _cost;
        } else {
            costStaminaOfFree = _cost;
        }
    }

    function setAuthControllers(address _controller, bool _enable) external onlyOwner {
        authControllers[_controller] = _enable;
    }

    function setBanditTax(uint8 _tax) external onlyOwner {
        require(_tax >= 20 && _tax <= 60);
        banditTax = _tax;
    }

    function setPerPowerMaxClaimPawAmount(uint256 _amount) external onlyOwner  {
        perPowerMaxClaimPawAmount = _amount;
    }

    function setPerPowerMaxClaimGemAmount(uint256 _amount) external onlyOwner  {
        perPowerMaxClaimGemAmount = _amount;
    }

    function setClaimCD(uint32 _cd) external onlyOwner {
        claimCD = _cd;
    }

    function setPVP(address _pvp) external onlyOwner {
        pvp = IPVP(_pvp);
    }

    function setUserDashboard(address _userDashboard) external onlyOwner {
        require(_userDashboard != address(0));
        userDashboard = IUserDashboard(_userDashboard);
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function wantedBrief(uint32 _hunterId) public view returns(uint8 wantedCount, uint8 maxWantedCount) {
        IWoof.WoofWoofWest memory hunter = woof.getTokenTraits(_hunterId);
        require(hunter.nftType == 2, "1");
        wantedCount = uint8(wantedBanditInfo[_hunterId].length);
        maxWantedCount = maxWantedCountOfLevel[hunter.level - 1];
    }

    struct Bandit {
        uint8 quality;
        uint8 level;
        uint16 cid;
        uint32 tokenId;
        uint256 accRewardPaw;
        uint256 accRewardGem;
        string name;
    }

    function wantedDetails(uint32 _hunterId) public view returns(
        uint8 wantedCount,
        uint8 maxWantedCount,
        uint32 lastClaimTime, 
        uint256 totalPendingPaw,
        uint256 totalPendingGem,
        uint256 claimablePaw,
        uint256 claimableGem,
        Bandit[] memory bandits
    ) {
        IWoof.WoofWoofWest memory hunter = woof.getTokenTraits(_hunterId);
        require(hunter.nftType == 2, "1");
        maxWantedCount = maxWantedCountOfLevel[hunter.level - 1];
        WantedBanditInfo[] memory wantedBandits = wantedBanditInfo[_hunterId];
        wantedCount = uint8(wantedBandits.length);
        bandits = new Bandit[](wantedCount);
        totalPendingPaw = 0;
        totalPendingGem = 0;
        uint256 miningPower = woof.miningPowerOf(hunter);
        for (uint8 i = 0; i < wantedBandits.length; ++i) {
            WantedBanditInfo memory wantedInfo = wantedBandits[i];
            BanditPayInfo memory payInfo = banditPayInfo[wantedInfo.banditId];
            uint256 pendingPaw = miningPower.mul(payInfo.accPawPerMiningPower).div(UNIT).sub(wantedInfo.rewardPaidPaw);
            pendingPaw = wantedInfo.pendingPaw.add(pendingPaw);
            totalPendingPaw += pendingPaw;
            uint256 pendingGem = miningPower.mul(payInfo.accGemPerMiningPower).div(UNIT).sub(wantedInfo.rewardPaidGem);
            pendingGem = wantedInfo.pendingGem.add(pendingGem);
            totalPendingGem += pendingGem;

            IWoof.WoofWoofWest memory bandit = woof.getTokenTraits(wantedInfo.banditId);
            bandits[i].quality = bandit.quality;
            bandits[i].level = bandit.level;
            bandits[i].cid = bandit.cid;
            bandits[i].name = bandit.name;
            bandits[i].tokenId = bandit.tokenId;
            bandits[i].accRewardPaw = pendingPaw + wantedInfo.accRewardPaw;
            bandits[i].accRewardGem = pendingGem + wantedInfo.accRewardGem;
        }

        WantedVesting memory vesting = wantedVesting[_hunterId];
        lastClaimTime = vesting.lastClaimTime;
        totalPendingPaw += vesting.pendingPaw;
        totalPendingGem += vesting.pendingGem;
        claimablePaw = miningPower * perPowerMaxClaimPawAmount;
        claimableGem = miningPower * perPowerMaxClaimGemAmount;
        if (lastClaimTime + claimCD < block.timestamp) {
            claimablePaw = claimablePaw.min(totalPendingPaw);
            claimableGem = claimableGem.min(totalPendingGem);
        } else {
            claimablePaw = claimablePaw.sub(vesting.rewardPaidPaw);
            claimableGem = claimableGem.sub(vesting.rewardPaidGem);
            claimablePaw = claimablePaw.min(totalPendingPaw);
            claimableGem = claimableGem.min(totalPendingGem);
        }
    }

    function wantedRewards(uint32 _hunterId) public view returns(
        uint256 totalPendingPaw,
        uint256 totalPendingGem
    ) {
        WantedBanditInfo[] memory wantedBandits = wantedBanditInfo[_hunterId];
        totalPendingPaw = 0;
        totalPendingGem = 0;
        uint256 miningPower = woof.miningPowerOf(_hunterId);
        for (uint8 i = 0; i < wantedBandits.length; ++i) {
            WantedBanditInfo memory wantedInfo = wantedBandits[i];
            BanditPayInfo memory payInfo = banditPayInfo[wantedInfo.banditId];
            uint256 pendingPaw = miningPower.mul(payInfo.accPawPerMiningPower).div(UNIT).sub(wantedInfo.rewardPaidPaw);
            pendingPaw = wantedInfo.pendingPaw.add(pendingPaw);
            totalPendingPaw += pendingPaw;
            uint256 pendingGem = miningPower.mul(payInfo.accGemPerMiningPower).div(UNIT).sub(wantedInfo.rewardPaidGem);
            pendingGem = wantedInfo.pendingGem.add(pendingGem);
            totalPendingGem += pendingGem;
        }

        WantedVesting memory vesting = wantedVesting[_hunterId];
        totalPendingPaw += vesting.pendingPaw;
        totalPendingGem += vesting.pendingGem;
    }

    function wantedHuntersOfBandit(uint32 _banditId) external view returns(uint32[] memory) {
        return banditPayInfo[_banditId].hunters;
    }

    function payForHunter(address _user, uint32 _tokenId, uint256 _pawAmount, uint256 _gemAmount, bool _escape) external returns(
        uint256 taxPawAmount, 
        uint256 taxGemAmount
    ) {
        require(authControllers[_msgSender()], "1");
        BanditPayInfo memory payInfo = banditPayInfo[_tokenId];
        if (payInfo.hunters.length == 0) {
            return(0, 0);
        }

        if (_escape) {
            random.addNonce();
            uint256 seed = random.getRandom(_pawAmount + _gemAmount);
            if (seed % 100 < banditTax + 5) {
                taxPawAmount = 0;
                taxGemAmount = 0;
                return (0, 0);
            } else {
                taxPawAmount = _pawAmount;
                taxGemAmount = _gemAmount;
            }
        } else {
            taxPawAmount = _pawAmount * banditTax / 100;
            taxGemAmount = _gemAmount * banditTax / 100;
        }
        if (taxPawAmount > 0) {
            IERC20(paw).safeTransferFrom(_msgSender(), address(this), taxPawAmount);
            payInfo.accPawPerMiningPower = payInfo.accPawPerMiningPower.add(taxPawAmount.mul(UNIT).div(payInfo.totalMiningPower));
        }
        if (taxGemAmount > 0) {
            IERC20(gem).safeTransferFrom(_msgSender(), address(this), taxGemAmount);
            payInfo.accGemPerMiningPower = payInfo.accGemPerMiningPower.add(taxGemAmount.mul(UNIT).div(payInfo.totalMiningPower));
        }
        banditPayInfo[_tokenId] = payInfo;
        emit PayForHunter(_user, _tokenId, taxPawAmount, taxGemAmount);
    }

    function wantedBandit(uint32 _hunterId, uint32 _banditId) external whenNotPaused {
        require(tx.origin == _msgSender(), "1");
        require(woof.ownerOf(_hunterId) == _msgSender(), "2");
        require(woof.ownerOf(_banditId) != _msgSender(), "3");

        IWoof.WoofWoofWest memory hunter = woof.getTokenTraits(_hunterId);
        require(hunter.nftType == 2, "4");
        require(hunter.attributes[0] >= costStaminaOfWanted, "5");
        hunter.attributes[0] -= costStaminaOfWanted;
        woof.updateStamina(_hunterId, hunter.attributes[0]);

        IWoof.WoofWoofWest memory bandit = woof.getTokenTraits(_banditId);
        require(bandit.nftType == 1, "6");

        WantedBanditInfo[] memory wantedBandits = wantedBanditInfo[_hunterId];
        require(wantedBandits.length <= maxWantedCountOfLevel[hunter.level - 1], "7");
        for (uint8 i = 0; i < wantedBandits.length; ++i) {
            require(wantedBandits[i].banditId != _banditId, "8");
        }

        uint256 miningPower = woof.miningPowerOf(hunter);
        BanditPayInfo memory payInfo = banditPayInfo[_banditId];
        require(payInfo.hunters.length <= maxWantedCountOfBandit, "9");
        payInfo.totalMiningPower += miningPower;
        banditPayInfo[_banditId] = payInfo;
        banditPayInfo[_banditId].hunters.push(_hunterId);

        WantedBanditInfo memory wantedInfo;
        wantedInfo.banditId = _banditId;
        wantedInfo.rewardPaidPaw = miningPower.mul(payInfo.accPawPerMiningPower).div(UNIT);
        wantedInfo.rewardPaidGem = miningPower.mul(payInfo.accGemPerMiningPower).div(UNIT);
        wantedBanditInfo[_hunterId].push(wantedInfo);

        emit WantedBandit(_msgSender(), _hunterId, _banditId);
    }

    function freeBandit(uint32 _hunterId, uint8 _pos) external {
        require(tx.origin == _msgSender(), "1");
        require(woof.ownerOf(_hunterId) == _msgSender(), "2");
        
        IWoof.WoofWoofWest memory hunter = woof.getTokenTraits(_hunterId);
        require(hunter.nftType == 2, "3");
        require(hunter.attributes[0] >= costStaminaOfFree, "4");
        hunter.attributes[0] -= costStaminaOfFree;
        woof.updateStamina(_hunterId, hunter.attributes[0]);

        WantedBanditInfo[] memory wantedBandits = wantedBanditInfo[_hunterId];
        require(_pos < wantedBandits.length, "5");
        uint256 miningPower = woof.miningPowerOf(hunter);
        WantedBanditInfo memory wantedInfo = wantedBandits[_pos];
        BanditPayInfo memory payInfo = banditPayInfo[wantedInfo.banditId];
        payInfo.totalMiningPower = payInfo.totalMiningPower.sub(miningPower);
        banditPayInfo[wantedInfo.banditId] = payInfo;
        _removeWanted(wantedInfo.banditId, _hunterId);

        uint256 pendingPaw = miningPower.mul(payInfo.accPawPerMiningPower).div(UNIT).sub(wantedInfo.rewardPaidPaw);
        pendingPaw = wantedInfo.pendingPaw.add(pendingPaw);
        uint256 pendingGem = miningPower.mul(payInfo.accGemPerMiningPower).div(UNIT).sub(wantedInfo.rewardPaidGem);
        pendingGem = wantedInfo.pendingGem.add(pendingGem);
        
        WantedVesting memory vesting = wantedVesting[_hunterId];
        vesting.pendingPaw += pendingPaw;
        vesting.pendingGem += pendingGem;
        wantedVesting[_hunterId] = vesting;

        wantedBanditInfo[_hunterId][_pos] = wantedBandits[wantedBandits.length - 1];
        wantedBanditInfo[_hunterId].pop();
        if (wantedBanditInfo[_hunterId].length == 0) {
            delete wantedBanditInfo[_hunterId];
        }
        emit FreeWantedBandit(_msgSender(), _hunterId, wantedInfo.banditId, pendingPaw, pendingGem);
    }

    function freeAllBandit(uint32 _hunterId) external {
        require(tx.origin == _msgSender(), "1");
        require(woof.ownerOf(_hunterId) == _msgSender(), "2");
        _claimOrFreeAll(_hunterId, true);
    }

    function claim(uint32 _hunterId) external {
        require(tx.origin == _msgSender(), "1");
        require(woof.ownerOf(_hunterId) == _msgSender(), "2");
        _claimOrFreeAll(_hunterId, false);
    }

    function updatePower(uint32 _tokenId, uint256 _miningPower, uint256 _beforeMiningPower) external {
        require(authControllers[_msgSender()], "1");
        WantedBanditInfo[] memory wantedBandits = wantedBanditInfo[_tokenId];
        if (wantedBandits.length == 0) {
            return;
        }

        for (uint8 i = 0; i < wantedBandits.length; ++i) {
            WantedBanditInfo memory wantedInfo = wantedBandits[i];
            BanditPayInfo memory payInfo = banditPayInfo[wantedInfo.banditId];

            uint256 pendingPaw = _beforeMiningPower.mul(payInfo.accPawPerMiningPower).div(UNIT).sub(wantedInfo.rewardPaidPaw);
            wantedInfo.pendingPaw = wantedInfo.pendingPaw.add(pendingPaw);
            wantedInfo.rewardPaidPaw = _miningPower.mul(payInfo.accPawPerMiningPower).div(UNIT);

            uint256 pendingGem = _beforeMiningPower.mul(payInfo.accGemPerMiningPower).div(UNIT).sub(wantedInfo.rewardPaidGem);
            wantedInfo.pendingGem = wantedInfo.pendingGem.add(pendingGem);
            wantedInfo.rewardPaidGem = _miningPower.mul(payInfo.accGemPerMiningPower).div(UNIT);
            wantedBandits[i] = wantedInfo;

            payInfo.totalMiningPower = payInfo.totalMiningPower.add(_miningPower).sub(_beforeMiningPower);
            banditPayInfo[wantedInfo.banditId] = payInfo;
        }
    }

    function _claimOrFreeAll(uint32 _hunterId, bool _free) internal {
        IWoof.WoofWoofWest memory hunter = woof.getTokenTraits(_hunterId);
        require(hunter.nftType == 2, "1");
        uint8 costStamina = _free == true ? costStaminaOfFree : 0;
        require(hunter.attributes[0] >= costStamina, "2");
        hunter.attributes[0] -= costStamina;
        woof.updateStamina(_hunterId, hunter.attributes[0]);

        WantedBanditInfo[] memory wantedBandits = wantedBanditInfo[_hunterId];
        require(wantedBandits.length > 0, "3");
        uint256 miningPower = woof.miningPowerOf(hunter);
        uint256 totalPendingPaw = 0;
        uint256 totalPendingGem = 0;
        for (uint8 i = 0; i < wantedBandits.length; ++i) {
            WantedBanditInfo memory wantedInfo = wantedBandits[i];
            BanditPayInfo memory payInfo = banditPayInfo[wantedInfo.banditId];
            uint256 pendingPaw = miningPower.mul(payInfo.accPawPerMiningPower).div(UNIT).sub(wantedInfo.rewardPaidPaw);
            pendingPaw = wantedInfo.pendingPaw.add(pendingPaw);
            totalPendingPaw += pendingPaw;
            wantedInfo.pendingPaw = 0;
            wantedInfo.rewardPaidPaw = miningPower.mul(payInfo.accPawPerMiningPower).div(UNIT);
            wantedInfo.accRewardPaw += pendingPaw;
            uint256 pendingGem = miningPower.mul(payInfo.accGemPerMiningPower).div(UNIT).sub(wantedInfo.rewardPaidGem);
            pendingGem = wantedInfo.pendingGem.add(pendingGem);
            totalPendingGem += pendingGem;
            wantedInfo.pendingGem = 0;
            wantedInfo.rewardPaidGem = miningPower.mul(payInfo.accGemPerMiningPower).div(UNIT);
            wantedInfo.accRewardGem += pendingGem;
            if (_free) {
                payInfo.totalMiningPower = payInfo.totalMiningPower.sub(miningPower);
                banditPayInfo[wantedInfo.banditId] = payInfo;
                _removeWanted(wantedInfo.banditId, _hunterId);
            } else {
                wantedBanditInfo[_hunterId][i] = wantedInfo;
            }
        }

        WantedVesting memory vesting = wantedVesting[_hunterId];
        vesting.pendingPaw += totalPendingPaw;
        vesting.pendingGem += totalPendingGem;

        if (_free) {
            delete wantedBanditInfo[_hunterId];
            emit FreeAllBandit(_msgSender(), _hunterId);
        } else {
            uint32 power = woof.miningPowerOf(_hunterId);
            uint256 claimablePaw = power * perPowerMaxClaimPawAmount;
            uint256 claimableGem = power * perPowerMaxClaimGemAmount;
            if (vesting.lastClaimTime + claimCD < block.timestamp) {
                claimablePaw = claimablePaw.min(vesting.pendingPaw);
                claimableGem = claimableGem.min(vesting.pendingGem);
                vesting.rewardPaidPaw = claimablePaw;
                vesting.rewardPaidGem = claimableGem;
                vesting.lastClaimTime = uint32(block.timestamp);
            } else {
                claimablePaw = claimablePaw.sub(vesting.rewardPaidPaw);
                claimableGem = claimableGem.sub(vesting.rewardPaidGem);
                claimablePaw = claimablePaw.min(vesting.pendingPaw);
                claimableGem = claimableGem.min(vesting.pendingGem);
                vesting.rewardPaidPaw += claimablePaw;
                vesting.rewardPaidGem += claimableGem;
            }
            vesting.pendingPaw = vesting.pendingPaw.sub(claimablePaw);
            vesting.pendingGem = vesting.pendingGem.sub(claimableGem);

            (claimablePaw, claimableGem) = _payTaxToSlaveOwner(_hunterId, claimablePaw, claimableGem);
            _safeTransfer(paw, _msgSender(), claimablePaw);
            _safeTransfer(gem, _msgSender(), claimableGem);
            userDashboard.rewardFromScene(_msgSender(), 3, claimablePaw, claimableGem, 0);
            emit Claim(_msgSender(), _hunterId, claimablePaw, claimableGem);
        }
        wantedVesting[_hunterId] = vesting;
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

    function _payTaxToSlaveOwner(uint32 _tokenId, uint256 _paw, uint256 _gem) internal returns(uint256, uint256) {
        if (address(pvp) != address(0)) {
            (address slaveOwer, uint256 pawTax, uint256 gemTax) = pvp.slaveOwnerAndPayTax(_tokenId, _paw, _gem);
            if (slaveOwer != address(0)) {
                _safeTransfer(paw, slaveOwer, pawTax);
                _safeTransfer(gem, slaveOwer, gemTax);
                _paw -= pawTax;
                _gem -= gemTax;
            }
        }
        return (_paw, _gem);
    }

    function _removeWanted(uint32 _banditId, uint32 _hunterId) internal {
        uint256 length = banditPayInfo[_banditId].hunters.length;
        for (uint256 i = 0; i < length; ++i) {
            if (banditPayInfo[_banditId].hunters[i] == _hunterId) {
                banditPayInfo[_banditId].hunters[i] = banditPayInfo[_banditId].hunters[length - 1];
                banditPayInfo[_banditId].hunters.pop();
                break;
            }
        }
    }
}