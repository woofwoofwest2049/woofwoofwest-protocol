// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;
import "./library/SafeERC20.sol";
import "./library/SafeMath.sol";
import "./interfaces/ITraits.sol";
import "./interfaces/IEquipment.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

interface ITreasury {
    function deposit(address _token, uint256 _amount) external;
}

interface IVestingPool {
    function balanceOf(address _user) external view returns(uint256);
    function transferFrom(address _from, address _to, uint256 _amount) external;
}

contract EquipmentBlindBox is ERC1155Upgradeable, OwnableUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct BuyInfo {
        uint32 accAmountOfBuy;
        uint32 firstTimeOfBuy;
    }

    event Buy(address indexed account, uint256 indexed eType, uint256 amount);
    event Open(address indexed account, uint256 indexed eType, uint256 amount, IEquipment.sEquipment[] equipments);
    event Mint(address indexed account, uint32 indexed eType, uint256 amount);

    ITraits public traits;
    mapping(address => bool) public authControllers;

    string public name;
    string public symbol;
    uint256 public minted;
    mapping (uint256 => uint256) public tokenSupply;
    mapping (uint256 => BuyInfo) public buyInfo;

    IEquipmentEnumerable public equipment;
    ITreasury public treasury;
    IVestingPool public pawVestingPool;
    IVestingPool public gemVestingPool;
    address public gem;
    address public paw;

    function initialize(
        address _traits,
        address _equipment,
        address _treasury,
        address _pawVestingPool,
        address _gemVestingPool,
        address _paw,
        address _gem
    ) external initializer {
        require(_traits != address(0));
        require(_equipment != address(0));
        require(_treasury != address(0));
        require(_pawVestingPool != address(0));
        require(_gemVestingPool != address(0));
        require(_paw != address(0));
        require(_gem != address(0));

        __ERC1155_init("");
        __Ownable_init();
        __Pausable_init();

        traits = ITraits(_traits);
        equipment = IEquipmentEnumerable(_equipment);
        treasury = ITreasury(_treasury);
        pawVestingPool = IVestingPool(_pawVestingPool);
        gemVestingPool = IVestingPool(_gemVestingPool);
        paw = _paw;
        gem = _gem;
        name = "Woof Woof West Gear Mystery Box";
        symbol = "WWGB";

        _safeApprove(_gem, _treasury);
        _safeApprove(_paw, _treasury);
    }

    function setAuthControllers(address _controller, bool _enable) external onlyOwner {
        authControllers[_controller] = _enable;
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

    function buy(uint8 _type, uint32 _amount) external whenNotPaused {
        require(tx.origin == _msgSender(), "Not EOA");
        IEquipmentConfig.sEquipmentBoxConfig memory config = equipment.getEquipmentBoxConfig(_type);
        require(config.eType == _type, "BlindBox does not exist");
        BuyInfo memory info = buyInfo[_type];
        if (info.firstTimeOfBuy + 1 days <= block.timestamp) {
            info.firstTimeOfBuy = uint32(block.timestamp);
            info.accAmountOfBuy = 0;
        }
        require(info.accAmountOfBuy + _amount <= config.dailyLimit, "Reach daily limit");
        info.accAmountOfBuy += _amount;

        uint256 amount = uint256(_amount).mul(config.price);
        _buyCost(config.payToken, amount);

        minted = minted.add(_amount);
        tokenSupply[_type] = tokenSupply[_type].add(_amount);
        _mint(_msgSender(), _type, _amount, "");
        buyInfo[_type] = info;
        emit Buy(_msgSender(), _type, _amount);
    }

    function open(uint8 _type, uint8 _amount) external whenNotPaused {
        require(tx.origin == _msgSender(), "Not EOA");
        require(_amount <= 10, "_amount more than 10");
        IEquipmentConfig.sEquipmentBoxConfig memory config = equipment.getEquipmentBoxConfig(_type);
        require(config.eType == _type, "BlindBox does not exist");
        require(balanceOf(msg.sender, _type) >= _amount, "Not enough blind box");
        _burn(msg.sender, _type, _amount);

        IEquipment.sEquipment[] memory equipments = new IEquipment.sEquipment[](_amount);
        for (uint8 i = 0; i < _amount; ++i) {
            equipments[i] = equipment.mint(msg.sender, _type);
        }
        emit Open(msg.sender, _type, _amount, equipments);
    }

    function mint(address _to, uint8 _type, uint8 _amount) external whenNotPaused {
        require(authControllers[_msgSender()], "no auth");
        minted = minted.add(_amount);
        tokenSupply[_type] = tokenSupply[_type].add(_amount);
        _mint(_to, _type, _amount, "");
        emit Mint(_to, _type, _amount);
    }

    function getBuyInfo() public view returns(BuyInfo[3] memory info) {
        info[0] = buyInfo[0];
        info[1] = buyInfo[1];
        info[2] = buyInfo[2];
    }

    function balanceOfBatch(address _account, uint32[] memory _itemIds)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory batchBalances = new uint256[](_itemIds.length);
        for (uint256 i = 0; i < _itemIds.length; ++i) {
            batchBalances[i] = balanceOf(_account, _itemIds[i]);
        }
        return batchBalances;
    }

    function uri(uint256 _itemId) public view override returns (string memory) {
        return traits.tokenURI(_itemId);
    }


    function _buyCost(uint8 _costToken, uint256 _cost) internal {
        if (_cost == 0) {
            return;
        }

        if (_costToken == 0) {
            uint256 bal1 = IERC20(paw).balanceOf(_msgSender());
            uint256 bal2 = pawVestingPool.balanceOf(_msgSender());
            require(bal1 + bal2 >= _cost, "pawCost exceeds balance");
            if (bal2 >= _cost) {
                pawVestingPool.transferFrom(_msgSender(), address(this), _cost);
            } else {
                if (bal2  > 0) {
                    pawVestingPool.transferFrom(_msgSender(), address(this), bal2);
                }
                IERC20(paw).safeTransferFrom(_msgSender(), address(this), _cost - bal2);
            }
            treasury.deposit(paw, _cost);
        } else {
            uint256 bal1 = IERC20(gem).balanceOf(_msgSender());
            uint256 bal2 = gemVestingPool.balanceOf(_msgSender());
            require(bal1 + bal2 >= _cost, "gemCost exceeds balance");
            if (bal2 >= _cost) {
                gemVestingPool.transferFrom(_msgSender(), address(this), _cost);
            } else {
                if (bal2  > 0) {
                    gemVestingPool.transferFrom(_msgSender(), address(this), bal2);
                }
                IERC20(gem).safeTransferFrom(_msgSender(), address(this), _cost - bal2);
            }
            treasury.deposit(gem, _cost);
        }
    }

    function _safeApprove(address _token, address _spender) internal {
        if (_token != address(0) && IERC20(_token).allowance(address(this), _spender) == 0) {
            IERC20(_token).safeApprove(_spender, type(uint256).max);
        }
    } 
}