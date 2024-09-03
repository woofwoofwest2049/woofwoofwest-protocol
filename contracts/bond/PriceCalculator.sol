// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "../interfaces/IERC20.sol";
import "../interfaces/IPancakePair.sol";
import "../interfaces/IPancakeFactory.sol";
import "../interfaces/IPancakeRouter02.sol";
import "../interfaces/AggregatorV3Interface.sol";
import "../interfaces/IPriceCalculator.sol";
import "../library/HomoraMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract PriceCalculator is IPriceCalculator, OwnableUpgradeable {
    using SafeMath for uint256;
    using HomoraMath for uint256;

    mapping(address => address) public pairTokens;
    mapping(address => address) public tokenFeeds;

    IPancakeFactory public factory;
    bytes32 public constant Cake_LP = keccak256("MacaronLP");
    address private WBNB;

    /* ========== INITIALIZER ========== */

    function initialize(
        address _WBNB,
        address _factory
    ) external initializer {
        require(_WBNB != address(0));
        require(_factory != address(0));

        __Ownable_init();

        WBNB = _WBNB;
        factory = IPancakeFactory(_factory);
    }

    /* ========== Restricted Operation ========== */
    function setPairToken(address _asset, address _pairToken) external onlyOwner {
        require(_asset != address(0) && _pairToken != address(0), "PriceCalculator: invalid address");
        pairTokens[_asset] = _pairToken;
    }

    function setTokenFeed(address _asset, address _feed) external onlyOwner {
        require(_asset != address(0) && _feed != address(0), "PriceCalculator: invalid address");
        tokenFeeds[_asset] = _feed;
    }

    function priceOfWBNB() public view  override returns (uint256) {
        (, int price, , ,) = AggregatorV3Interface(tokenFeeds[WBNB]).latestRoundData();
        return uint256(price).mul(1e10);
    }

    function priceOfToken(address token) public view override returns(uint256) {
        return valueOfAsset(token, 1e18);
    }

    function valueOfAsset(address asset, uint256 amount) public view returns (uint256) {
        if (asset == address(0) || asset == WBNB) {
            return _oracleValueOf(WBNB, amount);
        } else {
            bytes32 symbol = keccak256(abi.encodePacked(IPancakePair(asset).symbol()));
            if (symbol == Cake_LP) {
                return _getPairPrice(asset, amount);
            } else {
                return _oracleValueOf(asset, amount);
            }
        }
    }

    function _oracleValueOf(address asset, uint256 amount) private view returns (uint256) {
        if (tokenFeeds[asset] != address(0)) {
            (, int price, , ,) = AggregatorV3Interface(tokenFeeds[asset]).latestRoundData();
            return uint256(price).mul(1e10).mul(amount).div(1e18);
        } else {
            address pairToken = pairTokens[asset] == address(0) ? WBNB : pairTokens[asset];
            address pair = factory.getPair(asset, pairToken);
            if (IERC20(asset).balanceOf(pair) == 0) return (0);

            (uint256 r0, uint256 r1, ) = IPancakePair(pair).getReserves();
            (uint256 rAsset, uint256 rPairToken) = (IPancakePair(pair).token0() == asset) ? (r0, r1) : (r1, r0);

            uint256 pairAmount = amount.mul(rPairToken).div(rAsset);           

            if (tokenFeeds[pairToken] != address(0)) {
                (, int price, , ,) = AggregatorV3Interface(tokenFeeds[pairToken]).latestRoundData();
                uint256 valueInUSD = uint256(price).mul(1e10).mul(pairAmount).div(1e18);
                return valueInUSD;
            }

            return pairAmount;
        }
    }

    function _getPairPrice(address pair, uint256 amount) private view returns (uint256 valueInUSD) {
        uint256 totalSupply = IPancakePair(pair).totalSupply();
        if (totalSupply == 0) {
            return 0;
        }

        address token0 = IPancakePair(pair).token0();
        address token1 = IPancakePair(pair).token1();
        (uint256 r0, uint256 r1, ) = IPancakePair(pair).getReserves();

        if (tokenFeeds[token0] != address(0)) {
            (, int price, , ,) = AggregatorV3Interface(tokenFeeds[token0]).latestRoundData();
            uint256 rAmount = r0.mul(amount).div(totalSupply);
            valueInUSD = uint256(price).mul(1e10).mul(rAmount).div(1e18);
            return valueInUSD.mul(2);
        } else if (tokenFeeds[token1] != address(0)) {
            (, int price, , ,) = AggregatorV3Interface(tokenFeeds[token1]).latestRoundData();
            uint256 rAmount = r1.mul(amount).div(totalSupply);
            valueInUSD = uint256(price).mul(1e10).mul(rAmount).div(1e18);
            return valueInUSD.mul(2);
        } else if (token0 == WBNB || token1 == WBNB) {
            (, uint256 rWETH) = (token0 == WBNB) ? (r1, r0) : (r0, r1);
            uint256 wethAmount = amount.mul(rWETH).div(totalSupply);   
            return wethAmount.mul(2);
        } else {
            return 0;
        }
    }
}