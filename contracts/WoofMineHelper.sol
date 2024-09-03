// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./library/SafeERC20.sol";
import "./library/SafeMath.sol";
import "./interfaces/IWoofMineEnumerable.sol";
import "./interfaces/IWoofMineConfig.sol";
import "./interfaces/IItem.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

interface IRandom {
    function getRandom(uint256 _seed) external view returns (uint256);
    function multiRandomSeeds(uint256 _seed, uint256 _count) external view returns (uint256[] memory);
    function addNonce() external;
}

interface ITreasury {
    function deposit(address _token, uint256 _amount) external;
}

interface IVestingPool {
    function balanceOf(address _user) external view returns(uint256);
    function transferFrom(address _from, address _to, uint256 _amount) external;
}

interface IWoofMinePool {
    function recoverStaminaOfMiner(uint32 _tokenId, uint32 _pos, uint32 _stamina) external;
    function recoverStaminaOfHunter(uint32 _tokenId, uint32 _stamina) external;
}

contract WoofMineHelper is  OwnableUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    event Mint(address indexed account, IWoofMine.WoofWoofMine w);
    event RecoverStaminaOfMiner(address indexed account, uint256 indexed mineId, uint256 indexOfMiner, uint256 stamina);
    event RecoverStaminaOfHunter(address indexed account, uint256 indexed mineId, uint256 stamina);

    uint256 public mintPrice;
    address public paidToken;

    IRandom public random;
    IWoofMineConfig public config;
    ITreasury public treasury;
    IVestingPool public vestingPool;
    IWoofMineEnumerable public woofMine;

    uint256 private _minted;
    uint256[5] private _mintedDetails; 

    IWoofMinePool public woofMinePool;
    address public item;

    mapping(address => bool) public authControllers;

    function initialize(
        address _paidToken,
        address _random,
        address _config,
        address _treasury,
        address _woofMine
    ) external initializer {
        require(_paidToken != address(0));
        require(_random != address(0));
        require(_config != address(0));
        require(_treasury != address(0));
        require(_woofMine != address(0));

        __Ownable_init();
        __Pausable_init();

        mintPrice = 500 * 1e18;
        paidToken = _paidToken;
        random = IRandom(_random);
        config = IWoofMineConfig(_config);
        treasury = ITreasury(_treasury);
        woofMine = IWoofMineEnumerable(_woofMine);
        _safeApprove(_paidToken, _treasury);
    }

    function setMintPrice(uint256 _price) external onlyOwner {
        mintPrice = _price;
    }

    function setPaidToken(address _token) external onlyOwner {
        require(_token != address(0));
        paidToken = _token;
        _safeApprove(_token, address(treasury));
    }

    function setVestingPool(address _pool) external onlyOwner {
        require(_pool != address(0));
        vestingPool = IVestingPool(_pool);
    }

    function setWoofMinePool(address _minePool) external onlyOwner {
        require(_minePool != address(0));
        woofMinePool = IWoofMinePool(_minePool);
    }

    function setItem(address _item) external onlyOwner {
        require(_item != address(0));
        item = _item;
    }

    function setAuthControllers(address _controller, bool _enable) external onlyOwner {
        authControllers[_controller] = _enable;
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function mint() external whenNotPaused {
        require(tx.origin == _msgSender(), "Not EOA");
        _deposit(mintPrice);
        _mint(_msgSender());
    }

    function mint(address _to) external whenNotPaused {
        require(authControllers[_msgSender()], "no auth");
        _mint(_to);
    }

    function recoverStaminaOfMiner(uint32 _mineId, uint32 _indexOfMiner, uint32[] memory _itemIds, uint32[] memory _amount) external {
        require(tx.origin == _msgSender(), "Not EOA");
        require(woofMine.ownerOf(_mineId) == _msgSender(), "Not owner");
        require(_itemIds.length <= 4 && _itemIds.length == _amount.length, "Invalid items");
        uint32 stamina = _consumeStaminaItem(_itemIds, _amount);
        woofMinePool.recoverStaminaOfMiner(_mineId, _indexOfMiner, stamina);
        emit RecoverStaminaOfMiner(_msgSender(), _mineId, _indexOfMiner, stamina);
    }

    function recoverStaminaOfHunter(uint32 _mineId, uint32[] memory _itemIds, uint32[] memory _amount) external {
        require(tx.origin == _msgSender(), "Not EOA");
        require(woofMine.ownerOf(_mineId) == _msgSender(),  "Not owner");
        require(_itemIds.length <= 4 && _itemIds.length == _amount.length, "Invalid items");
        uint32 stamina = _consumeStaminaItem(_itemIds, _amount);
        woofMinePool.recoverStaminaOfHunter(_mineId, stamina);
        emit RecoverStaminaOfHunter(_msgSender(), _mineId, stamina);
    }

    function _consumeStaminaItem(uint32[] memory _itemIds, uint32[] memory _amount) internal returns(uint32) {
        uint32 stamina = 0;
        for (uint32 i = 0; i < _itemIds.length; ++i) {
            if (_itemIds[i] == 0) {
                continue;
            }
            if (_amount[i] == 0) {
                continue;
            }
            IItem.ItemConfig memory itemConfig = IItem(item).getConfig(_itemIds[i]);
            require(itemConfig.itemId == _itemIds[i], "Invalid itemId");
            require(itemConfig.itemType == 6, "Invalid itemId");
            IItem(item).burn(_msgSender(), _itemIds[i], _amount[i]);
            stamina += itemConfig.value * _amount[i];
        }
        return stamina;
    }

    function _deposit(uint256 _amount) internal {
        address _paidToken = paidToken;
        uint256 bal1 = IERC20(_paidToken).balanceOf(_msgSender());
        uint256 bal2 = vestingPool.balanceOf(_msgSender());
        require(bal1 + bal2 >= _amount);
        if (bal2 >= _amount) {
            vestingPool.transferFrom(_msgSender(), address(this), _amount);
        } else {
            if (bal2 > 0) {
                vestingPool.transferFrom(_msgSender(), address(this), bal2);
            }
            IERC20(_paidToken).safeTransferFrom(_msgSender(), address(this), _amount - bal2);
        }
        treasury.deposit(_paidToken, _amount);
    }

    function _mint(address _to) internal {
        _minted++;
        random.addNonce();
        uint256[] memory seeds = random.multiRandomSeeds(_minted, 1);
        IWoofMine.WoofWoofMine memory w = config.randomWoofWoofMine(seeds);
        w.tokenId = uint32(_minted);
        _mintedDetails[w.quality] += 1;
        woofMine.mint(_to, w);
        emit Mint(_to, w);
    }

    function _safeApprove(address _token, address _spender) internal {
        if (_token != address(0) && IERC20(_token).allowance(address(this), _spender) == 0) {
            IERC20(_token).safeApprove(_spender, type(uint256).max);
        }
    }

    function minted() public view returns(uint256 totalMinted, uint256[5] memory mintedOfQuality) {
        totalMinted = _minted;
        mintedOfQuality = _mintedDetails;
    }

    function mintDashboard(address _user) public view returns(
        uint256 mintPrice_,
        uint256 minted_,
        uint256 balanceOf_
    ) {
        mintPrice_ = mintPrice;
        minted_ = _minted;
        balanceOf_ = 0;
        if (_user != address(0)) {
            balanceOf_ = IERC20(paidToken).balanceOf(_user);
        }
    }
}