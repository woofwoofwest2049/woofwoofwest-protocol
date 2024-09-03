// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./library/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface ILiquidity {
    function initLP() external;
}

interface IWoof {
    function dividendU(uint256 _amount) external;
}

interface IBurnToken {
    function burn(uint256 amount_) external;
}

contract Treasury is OwnableUpgradeable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    address public gem;
    address public paw;
    address public pairToken;
    address public gemLiquidity;
    address public pawLiquidity;
    address public dao;
    address public woof;
    address public team;
    mapping(address => bool) public authControllers;
    uint8 public woofRatioOfU;
    uint8 public daoRatioOfU;
    uint8 public teamRatioOfU;
    uint8 public daoRatioOfGem;
    uint256 public rebaseTime;
    uint256 public rebaseLength;
    uint256 public pendingURewards;

    function initialize(
        address _gem,
        address _paw,
        address _pairToken,
        address _gemLiquidity,
        address _pawLiquidity,
        address _dao,
        address _team
    ) external initializer {
        require(_gem != address(0));
        require(_paw != address(0));
        require(_pairToken != address(0));
        require(_gemLiquidity != address(0));
        require(_pawLiquidity != address(0));
        require(_dao != address(0));
        require(_team != address(0));

        __Ownable_init();

        gem = _gem;
        paw = _paw;
        pairToken = _pairToken;
        gemLiquidity = _gemLiquidity;
        pawLiquidity = _pawLiquidity;
        dao = _dao;
        team = _team;
        woofRatioOfU = 30;
        daoRatioOfU = 30;
        teamRatioOfU = 40;
        daoRatioOfGem = 50;
        rebaseLength = 1 days;

        _safeApprove(_gem, _gemLiquidity);
        _safeApprove(_pairToken, _gemLiquidity);
        _safeApprove(_paw, _pawLiquidity);
        _safeApprove(_pairToken, _pawLiquidity);
    }

    function setRatioOfU(uint8 _woofRatioOfU, uint8 _daoRatioOfU, uint8 _teamRatioOfU) external onlyOwner {
        require(_woofRatioOfU + _daoRatioOfU + _teamRatioOfU == 100);
        woofRatioOfU = _woofRatioOfU;
        daoRatioOfU = _daoRatioOfU;
        teamRatioOfU = _teamRatioOfU;
    }

    function setAuthControllers(address _controller, bool _enable) external onlyOwner {
        authControllers[_controller] = _enable;
    }

    function setDao(address _dao) external onlyOwner {
        require(_dao != address(0));
        dao = _dao;
    }

    function setWoof(address _woof) external onlyOwner {
        require(_woof != address(0));
        woof = _woof;
        _safeApprove(pairToken, _woof);
    }

    function setTeam(address _team) external onlyOwner {
        require(_team != address(0));
        team = _team;
    }

    function startRebase() external onlyOwner {
        require(rebaseTime == 0);
        rebaseTime = block.timestamp + rebaseLength;
    }

    function setRebaseLength(uint256 _length) external onlyOwner {
        require(_length >= 8 hours);
        rebaseLength = _length;
    }

    function balanceOf(address _token) public view returns(uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    function initGemLP() external onlyOwner {
        ILiquidity(gemLiquidity).initLP();
    }

    function initPawLP() external onlyOwner {
        ILiquidity(pawLiquidity).initLP();
    }

    function deposit(address _token, uint256 _amount) external {
        require(authControllers[msg.sender] == true, "No auth");
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
    }

    function depoistMarketFee(uint256 _amount) external {
        require(authControllers[msg.sender] == true, "No auth");
        pendingURewards += _amount;
    }
    
    function rebase() external {
        require(authControllers[msg.sender] == true, "No auth");
        if (rebaseTime == 0 || rebaseTime > block.timestamp) {
            return;
        }

        uint256 pawAmt = IERC20(paw).balanceOf(address(this));
        if (pawAmt > 0) {
            IBurnToken(paw).burn(pawAmt);
        }

        uint256 gemAmt = IERC20(gem).balanceOf(address(this));
        if (gemAmt > 0) {
            uint256 daoGemAmt = gemAmt * daoRatioOfGem / 100;
            IERC20(gem).safeTransfer(dao, daoGemAmt);
            uint256 burnAmt = gemAmt - daoGemAmt;
            IBurnToken(gem).burn(burnAmt);
        }

        uint256 uAmt = IERC20(pairToken).balanceOf(address(this));
        if (uAmt >= pendingURewards) {
            uAmt = pendingURewards;
        } 
        if (uAmt == 0) {
            pendingURewards = 0;
            rebaseTime = rebaseTime + rebaseLength;
            return;
        }

        uint256 woofAmt = uAmt * woofRatioOfU / 100;
        uint256 daoAmt = uAmt * daoRatioOfU / 100;
        uint256 teamAmt = uAmt - woofAmt - daoAmt;
        IWoof(woof).dividendU(woofAmt);
        IERC20(pairToken).safeTransfer(dao, daoAmt);
        IERC20(pairToken).safeTransfer(team, teamAmt);
        pendingURewards = 0;
        rebaseTime = rebaseTime + rebaseLength;
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