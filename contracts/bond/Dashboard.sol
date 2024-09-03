// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "../library/SafeMath.sol";
import "../interfaces/IERC20Metadata.sol";
import "../interfaces/IPriceCalculator.sol";
import "../interfaces/IWoof.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface ILPBondHelper {
    function getPayout(address _bond, address _token, uint256 _amount) external view returns(uint256);
}

interface IVestingPool {
    function getUserInfo(address _user) external view returns(
        uint256 claimableAmount_,
        uint256 lockAmount_,
        uint256 vestingTerm_,
        uint256 lastRewardTime_
    );
}

interface IBondDespository {
    function principle() external view returns(address);
    function payoutToken() external view returns(address);
    function bondPriceInUSD() external view returns(uint256);
    function maxPayout() external view returns (uint256);
    function isLiquidityBond() external view returns (bool);
}

interface IGem {
    function MAX_SUPPLY() external view returns(uint256);
    function totalBurnedAmount() external view returns(uint256);
}

interface IPaw {
    function totalBurnedAmount() external view returns(uint256);
}

interface ILPFarm {
    function farmInfo() external view returns(
        address stakingToken_, 
        address earnedToken_, 
        uint256 totalDepositAmount_, 
        uint256 sharesTotal_,
        uint256 maxRewardAmount_, 
        uint256 totalRewardAmount_, 
        uint256 dailyReward_,
        uint256 maxPower_
    );
    function userInfo(address _user) external view returns(uint32 nftId_, uint32 depositedAt_, uint256 depostAmt_, uint256 power_, uint256 pendingReward_);
}

contract Dashboard is OwnableUpgradeable {
    using SafeMath for uint256;

    address public gemVestingPool;
    address public pawVestingPool;
    address public gem;
    address public paw;
    address public priceCalculator;
    address public treasury;

    bytes32 public constant CAKE_LP = keccak256("Cake-LP");
    bytes32 public constant BSW_LP = keccak256("BSW-LP");

    struct Bonds {
        address bond;
        bool enable;
        bool isLP;
    }

    Bonds[] public bonds;
    address public lpBondHelper;
    address public lpFarm;

    function initialize(
        address _gemVestingPool,
        address _pawVestingPool,
        address _gem,
        address _paw,
        address _priceCalculator,
        address _treasury
    ) external initializer {
        require(_gemVestingPool != address(0));
        require(_pawVestingPool != address(0));
        require(_gem != address(0));
        require(_paw != address(0));
        require(_priceCalculator != address(0));
        require(_treasury != address(0));

        __Ownable_init();

        gemVestingPool = _gemVestingPool;
        pawVestingPool = _pawVestingPool;
        gem = _gem;
        paw = _paw;
        priceCalculator = _priceCalculator;
        treasury = _treasury;
    }

    function setGemVestingPool(address _pool) external onlyOwner {
        gemVestingPool = _pool;
    }

    function setPawVestingPool(address _pool) external onlyOwner {
        pawVestingPool = _pool;
    }

    function setLPBondHelper(address _lpBondHelper) external onlyOwner {
        require(_lpBondHelper != address(0));
        lpBondHelper = _lpBondHelper;
    }

    function bondsLength() external view returns(uint256) {
        return bonds.length;
    }

    function setPriceCalculator(address _priceCalculator) external onlyOwner {
        require(_priceCalculator != address(0));
        priceCalculator = _priceCalculator;
    }

    function setBonds(address _bond, bool _enable) external onlyOwner {
        require( _bond != address(0) );
        uint256 length = bonds.length;
        for (uint256 i = 0; i < length; ++i) {
            if (bonds[i].bond == _bond) {
                bonds[i].enable = _enable;
                return;
            }
        }

        address token = IBondDespository(_bond).principle();
        bytes32 symbol = keccak256(abi.encodePacked(IERC20Metadata(token).symbol()));
        bonds.push( Bonds({
            bond: _bond,
            enable: _enable,
            isLP: (symbol == CAKE_LP || symbol == BSW_LP) ? true : false
        }));
    }

    function setLPFarm(address _lpFarm) external onlyOwner {
        require(_lpFarm != address(0));
        lpFarm = _lpFarm;
    }

    struct BondsInfo {
        address bond;
        uint256 mv;
        uint256 pol;
        uint256 price;
    }

    function bondsInfo() public view returns(BondsInfo[] memory info) {
        Bonds[] memory _bonds = bonds;
        uint256 length = _bonds.length;
        uint256 count = 0;
        for (uint256 i = 0; i < length; ++i) {
            if (_bonds[i].enable == false) {
                continue;
            }
            count++;
        }
        info = new BondsInfo[](count);
        uint256 j = 0;
        for (uint256 i = 0; i < length; ++i) {
            if (_bonds[i].enable == false) {
                continue;
            }

            address bond = _bonds[i].bond;
            address token = IBondDespository(bond).principle();
            uint256 bal = IERC20(token).balanceOf(treasury);
            uint256 value = bal.mul(IPriceCalculator(priceCalculator).priceOfToken(token)).div(1e18);
            info[j].bond = bond;
            info[j].mv = value;
            info[j].price = IBondDespository(bond).bondPriceInUSD();
            if (_bonds[i].isLP) {
                uint256 totalAmount = IERC20(token).totalSupply();
                if (totalAmount > 0) {
                    info[j].pol = bal.mul(1e18).div(totalAmount);
                } else {
                    info[j].pol = 0;
                }
            } else {
                info[j].pol = 0;
            }
            ++j;
        }
    }

    struct tokenInfo {
        uint256 price;
        uint256 totalSupply;
        uint256 totalBurned;
        uint256 maxSupply;
        uint256 balanceOfWallet;
        uint256 balanceOfClaimable;
        uint256 balancefLock;
    }

    function tokenInfoOf(address _user) public view returns(
       tokenInfo memory gemInfo,
       tokenInfo memory pawInfo 
    ) {
        gemInfo.price = IPriceCalculator(priceCalculator).priceOfToken(gem);
        gemInfo.totalSupply = IERC20(gem).totalSupply();
        gemInfo.totalBurned = IGem(gem).totalBurnedAmount();
        gemInfo.maxSupply = IGem(gem).MAX_SUPPLY();

        pawInfo.price = IPriceCalculator(priceCalculator).priceOfToken(paw);
        pawInfo.totalSupply = IERC20(paw).totalSupply();
        pawInfo.totalBurned = IGem(paw).totalBurnedAmount();
        if (_user != address(0)) {
            gemInfo.balanceOfWallet = IERC20(gem).balanceOf(_user);
            (gemInfo.balanceOfClaimable, gemInfo.balancefLock,,) = IVestingPool(gemVestingPool).getUserInfo(_user);

            pawInfo.balanceOfWallet = IERC20(paw).balanceOf(_user);
            (pawInfo.balanceOfClaimable, pawInfo.balancefLock,,) = IVestingPool(pawVestingPool).getUserInfo(_user);
        }
    }

    struct BondInfo {
        uint256 bondPrice;
        uint256 marketPrice;
        uint256 balanceOfPaymentToken;
        uint256 maxPayout;
        uint256 payout;
        uint256 balanceOfWallet;
        uint256 balanceOfClaimable;
        uint256 balancefLock;
    }

    function userQuickBondInfo(address _user, address _bond, address _token, uint256 _amount) public view returns(
        BondInfo memory info
    ) {
        address payoutToken = IBondDespository(_bond).payoutToken();
        info.bondPrice = IBondDespository(_bond).bondPriceInUSD(); 
        info.marketPrice = IPriceCalculator(priceCalculator).priceOfToken(payoutToken);
        info.balanceOfPaymentToken = IERC20(_token).balanceOf(_user); 
        info.maxPayout = IBondDespository(_bond).maxPayout();
        if (_amount > 0) {
            info.payout = ILPBondHelper(lpBondHelper).getPayout(_bond, _token, _amount);
        }

        info.balanceOfWallet = IERC20(payoutToken).balanceOf(_user);
        if (payoutToken == gem) {
            (info.balanceOfClaimable, info.balancefLock,,) = IVestingPool(gemVestingPool).getUserInfo(_user);
        } else if (payoutToken == paw) {
            (info.balanceOfClaimable, info.balancefLock,,) = IVestingPool(pawVestingPool).getUserInfo(_user);
        }
    }

    struct FarmInfo {
        uint256 stakingTokenPrice;
        uint256 earnedTokenPrice;
        uint256 totalDepositAmount;
        uint256 sharesTotal;
        uint256 dailyRewardAmt;
        uint256 maxPower;
    }

    struct FarmUserInfo {
        uint32 nftId;
        uint32 depositedAt;
        uint256 depositAmt;
        uint256 power;
        uint256 pendingReward;
    }

    function farmInfo(address _user) public view returns(FarmInfo memory farmInfo_, FarmUserInfo memory userInfo_) {
        (address stakingToken_, address earnedToken_, uint256 totalDepositAmount_, uint256 sharesTotal_, , , uint256 dailyReward_, uint256 maxPower_) = ILPFarm(lpFarm).farmInfo();
        farmInfo_.stakingTokenPrice = IPriceCalculator(priceCalculator).priceOfToken(stakingToken_);
        farmInfo_.earnedTokenPrice = IPriceCalculator(priceCalculator).priceOfToken(earnedToken_);
        farmInfo_.totalDepositAmount = totalDepositAmount_;
        farmInfo_.sharesTotal = sharesTotal_;
        farmInfo_.dailyRewardAmt = dailyReward_;
        farmInfo_.maxPower = maxPower_;

        if (_user != address(0)) {
            (userInfo_.nftId, userInfo_.depositedAt, userInfo_.depositAmt, userInfo_.power, userInfo_.pendingReward) = ILPFarm(lpFarm).userInfo(_user);
        }
    }
}

