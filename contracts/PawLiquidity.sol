// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./library/SafeERC20.sol";
import "./interfaces/IPancakeRouter02.sol";
import "./interfaces/IPancakeFactory.sol";
import "./interfaces/IPancakePair.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IPaw {
    function mint(address to, uint256 amount) external;
}

contract PawLiquidity is OwnableUpgradeable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public paw;
    address public pairToken;
    address public router;
    address public treasury;

    address public lp;
    uint256 public initPairTokenAmount;
    uint256 public initPawAmount;
    bool public addedLP;

    function initialize(
        address _pairToken,
        address _paw,
        address _router
    ) external initializer {
        require(_pairToken != address(0));
        require(_paw != address(0));
        require(_router != address(0));

        __Ownable_init();

        pairToken = _pairToken;
        paw = _paw;
        router = _router;

        address factory = IPancakeRouter02(_router).factory();
        address lpToken = IPancakeFactory(factory).getPair(_pairToken, _paw);
        if (lpToken == address(0)) {
            lpToken = IPancakeFactory(factory).createPair(_pairToken, _paw);
            require(lpToken != address(0), "lpToken == address(0)");    
        }
        lp = lpToken;
        initPairTokenAmount = 50000 * 1e6;
        initPawAmount = 50000 * 1e18 * 100;
        addedLP = false;

        _safeApprove(_pairToken, _router);
        _safeApprove(_paw, _router);
    }

    function setInitAmount(uint256 _pairTokenAmount, uint256 _pawAmount) external onlyOwner {
        initPairTokenAmount = _pairTokenAmount;
        initPawAmount = _pawAmount;
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0));
        treasury = _treasury;
    }

    function balanceOf(address _token) public view returns(uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    function initLP() external {
        require(treasury == msg.sender, "No auth");
        require(addedLP == false, "addedLP == true");
        IERC20(pairToken).safeTransferFrom(msg.sender, address(this), initPairTokenAmount);
        IPaw(paw).mint(address(this), initPawAmount);
        IPancakeRouter02(router).addLiquidity(
            pairToken,
            paw,
            initPairTokenAmount,
            initPawAmount,
            0,
            0,
            treasury,
            block.timestamp + 60
        );
        addedLP = true;
    }

    function withdrawBEP20(address _tokenAddress, address _to, uint256 _amount) public onlyOwner {
        uint256 tokenBal = IERC20(_tokenAddress).balanceOf(address(this));
        if (_amount == 0 || _amount >= tokenBal) {
            _amount = tokenBal;
        }
        IERC20(_tokenAddress).transfer(_to, _amount);
    }

    function _safeApprove(address _token, address _spender) internal {
        if (_token != address(0) && IERC20(_token).allowance(address(this), _spender) == 0) {
            IERC20(_token).safeApprove(_spender, type(uint256).max);
        }
    }
}