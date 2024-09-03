// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./interfaces/IWoofMineEnumerable.sol";
import "./interfaces/IWoofMineConfig.sol";
import "./library/SafeERC20.sol";
import "./library/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

interface ITreasury {
    function deposit(address _token, uint256 _amount) external;
}

interface IVestingPool {
    function balanceOf(address _user) external view returns(uint256);
    function transferFrom(address _from, address _to, uint256 _amount) external;
}

interface IWoofMinePool {
    function checkLevelUp(uint32 _tokenId) external view returns(bool);
}

contract WoofMineUpgrade is OwnableUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    event UpgradeWoofMine(address indexed sender, IWoofMine.WoofWoofMine w);

    IWoofMineEnumerable public woofMine;
    IWoofMinePool public woofMinePool;
    ITreasury public treasury;
    IVestingPool public gemVestingPool;
    IVestingPool public pawVestingPool;
    IWoofMineConfig public config;
    address public gem;
    address public paw;

    function initialize(
        address _woofMine,
        address _woofMinePool,
        address _treasury,
        address _gemVestingPool,
        address _pawVestingPool,
        address _gem,
        address _paw,
        address _config
    ) external initializer {
        require(_woofMine != address(0));
        require(_woofMinePool != address(0));
        require(_treasury != address(0));
        require(_gemVestingPool != address(0));
        require(_pawVestingPool != address(0));
        require(_gem != address(0));
        require(_paw != address(0));
        require(_config != address(0));

        __Ownable_init();
        __Pausable_init();

        woofMine = IWoofMineEnumerable(_woofMine);
        woofMinePool = IWoofMinePool(_woofMinePool);
        treasury = ITreasury(_treasury);
        gemVestingPool = IVestingPool(_gemVestingPool);
        pawVestingPool = IVestingPool(_pawVestingPool);
        config = IWoofMineConfig(_config);
        gem = _gem;
        paw = _paw;

        _safeApprove(_gem, _treasury);
        _safeApprove(_paw, _treasury);
    }

    function setGemVestingPool(address _pool) external onlyOwner {
        gemVestingPool = IVestingPool(_pool);
    }

    function setPawVestingPool(address _pool) external onlyOwner {
        pawVestingPool = IVestingPool(_pool);
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function upgrade(uint32 _tokenId) external whenNotPaused {
        require(tx.origin == _msgSender(), "Not EOA");
        require(woofMine.ownerOf(_tokenId) == _msgSender(), "Not owner");
        require(woofMinePool.checkLevelUp(_tokenId) == true, "Can't level up");
        (IWoofMine.WoofWoofMine memory w, uint256 pawCost, uint256 gemCost) = config.upgradeWoofWoofMine(_tokenId);
        _cost(pawCost, gemCost);
        woofMine.updateTokenTraits(w);
        emit UpgradeWoofMine(_msgSender(), w);
    }

    function _safeApprove(address _token, address _spender) internal {
        if (_token != address(0) && IERC20(_token).allowance(address(this), _spender) == 0) {
            IERC20(_token).safeApprove(_spender, type(uint256).max);
        }
    }

    function _cost(uint256 _pawCost, uint256 _gemCost) internal {
        if (_pawCost > 0) {
            uint256 bal1 = IERC20(paw).balanceOf(_msgSender());
            uint256 bal2 = pawVestingPool.balanceOf(_msgSender());
            require(bal1 + bal2 >= _pawCost, "pawCost exceeds balance");
            if (bal2 >= _pawCost) {
                pawVestingPool.transferFrom(_msgSender(), address(this), _pawCost);
            } else {
                if (bal2 > 0) {
                    pawVestingPool.transferFrom(_msgSender(), address(this), bal2);
                }
                IERC20(paw).safeTransferFrom(_msgSender(), address(this), _pawCost - bal2);
            }
            treasury.deposit(paw, _pawCost);
        }

        if (_gemCost > 0) {
            uint256 bal1 = IERC20(gem).balanceOf(_msgSender());
            uint256 bal2 = gemVestingPool.balanceOf(_msgSender());
            require(bal1 + bal2 >= _gemCost, "gemCost exceeds balance");
            if (bal2 >= _gemCost) {
                gemVestingPool.transferFrom(_msgSender(), address(this), _gemCost);
            } else {
                if (bal2 > 0) {
                    gemVestingPool.transferFrom(_msgSender(), address(this), bal2);
                }
                IERC20(gem).safeTransferFrom(_msgSender(), address(this), _gemCost - bal2);
            }
            treasury.deposit(gem, _gemCost);
        }
    }
}