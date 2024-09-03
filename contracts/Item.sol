// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;
import "./library/SafeERC20.sol";
import "./library/SafeMath.sol";
import "./library/Strings.sol";
import "./interfaces/IItem.sol";
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

contract Item is IItem, ERC1155Upgradeable, OwnableUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using Strings for uint256;

    event Buy(address indexed account, uint256 indexed itemId, uint256 amount);
    event Mint(address indexed account, uint256[] itemId, uint256[] amount);
    event Mint2(address indexed account, uint256 itemId, uint256 amount);

    string public name;
    string public symbol;
    uint256 public minted;
    mapping (uint256 => uint256) public tokenSupply;

    address public paw;
    address public gem;
    address public BUSD;
    address public treasury;
    mapping (uint256 => ItemConfig) public configs;
    mapping(address => bool) public authControllers;

    IVestingPool public gemVestingPool;
    IVestingPool public pawVestingPool;

    function initialize(
        address _paw,
        address _gem,
        address _busd,
        address _treasury,
        address _gemVestingPool,
        address _pawVestingPool
    ) external initializer {
        require(_paw != address(0));
        require(_gem != address(0));
        require(_busd != address(0));
        require(_treasury != address(0));
        require(_gemVestingPool != address(0));
        require(_pawVestingPool != address(0));
        __ERC1155_init("");
        __Ownable_init();
        __Pausable_init();
        paw = _paw;
        gem = _gem;
        BUSD = _busd;
        treasury = _treasury;
        gemVestingPool = IVestingPool(_gemVestingPool);
        pawVestingPool = IVestingPool(_pawVestingPool);
        name = "Woof Woof West Item";
        symbol = "WWI";

        _safeApprove(_paw, _treasury);
        _safeApprove(_gem, _treasury);
        _safeApprove(_busd, _treasury);
    }

    function setAuthControllers(address _controller, bool _enable) external onlyOwner {
        authControllers[_controller] = _enable;
    }

    function setConfigs(ItemConfig[] memory _configs) external onlyOwner {
        for (uint256 i = 0; i < _configs.length; ++i) {
            configs[_configs[i].itemId] = _configs[i];
        }
    }

    function setVestingPool(address _gemVestingPool, address _pawVestingPool) external onlyOwner {
        require(_gemVestingPool != address(0));
        require(_pawVestingPool != address(0));
        gemVestingPool = IVestingPool(_gemVestingPool);
        pawVestingPool = IVestingPool(_pawVestingPool);
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function buy(uint256 _itemId, uint256 _amount) external whenNotPaused {
        require(tx.origin == _msgSender(), "Not EOA");
        ItemConfig memory config = configs[_itemId];
        require(_itemId == config.itemId, "Item does not exist");
        require(config.price > 0, "Not sale");

        uint256 amount = _amount.mul(config.price);
        address payToken;
        if (config.payToken == 0) {
            payToken = paw;
            _cost(amount, 0);
        } else if (config.payToken == 1) {
            payToken = gem;
            _cost(0, amount);
        } else {
            payToken = BUSD;
            IERC20(payToken).safeTransferFrom(_msgSender(), address(this), amount);
            ITreasury(treasury).deposit(payToken, amount);
        }

        minted = minted.add(_amount);
        tokenSupply[_itemId] = tokenSupply[_itemId].add(_amount);
        _mint(_msgSender(), _itemId, _amount, "");
        emit Buy(_msgSender(), _itemId, _amount);
    } 

    function burn(address _account, uint256 _itemId, uint256 _amount) public override {
        require(
            authControllers[_msgSender()] == true ||
            _account == _msgSender() || isApprovedForAll(_account, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        _burn(_account, _itemId, _amount);
    }

    function mint(address _account, uint256[] memory _itemId, uint256[] memory _amount) external {
        require(authControllers[_msgSender()] == true, "no auth");
        for (uint256 i = 0; i < _itemId.length; ++i) {
            minted = minted.add(_amount[i]);
            tokenSupply[_itemId[i]] = tokenSupply[_itemId[i]].add(_amount[i]);
            _mint(_account, _itemId[i], _amount[i], "");
        }
        emit Mint(_account, _itemId, _amount);
    }

    function mint(address _account, uint256 _itemId, uint256 _amount) external {
        require(authControllers[_msgSender()] == true, "no auth");
        minted = minted.add(_amount);
        tokenSupply[_itemId] = tokenSupply[_itemId].add(_amount);
        _mint(_account, _itemId, _amount, "");
        emit Mint2(_account, _itemId, _amount);
    }

    function uri(uint256 _itemId) public view override returns (string memory) {
        ItemConfig memory config = configs[_itemId];
        string memory imageUrl = nftUrl(config.itemId);
        string memory metadata = string(abi.encodePacked(
        '{"name": "',
        config.name,
        ' #',
        _itemId.toString(),
        '", "description": "Consumable NFTs to enrich the experience of cats and dogs in Woof Woof West. All the metadata are generated and stored 100% on-chain.", ',
        imageUrl,
        ', "attributes":',
        compileAttributes(config),
        "}"
        ));

        return string(abi.encodePacked(
            "data:application/json;base64,",
            base64(bytes(metadata))
        ));
    }

    function attributeForTypeAndValue(string memory traitType, string memory value) internal pure returns (string memory) {
        return string(abi.encodePacked(
            '{"trait_type":"',
            traitType,
            '","value":"',
            value,
            '"}'
        ));
    }

    function compileAttributes(ItemConfig memory _config) public pure returns (string memory) {
        string memory traits = string(abi.encodePacked(
            attributeForTypeAndValue("Type", uint256(_config.itemType).toString()),',',
            attributeForTypeAndValue("Value", uint256(_config.value).toString()), ',',
            attributeForTypeAndValue("Description", _config.des)
        ));
    
        return string(abi.encodePacked(
            '[',
            traits,
            ']'
        ));
    }

    function nftUrl(uint256 _itemId) public pure returns(string memory) {
        string memory ipfsHash = "QmU4UNjm1tjGvmhjMQjaZMEnDpDJRwLAabeD8odMm4Vn2g";
        return string(abi.encodePacked('"image": "https://woofwoofwest.mypinata.cloud/ipfs/',
            ipfsHash,
            '/',
            _itemId.toString(),
            '.png"'
        ));
    }

    /** BASE 64 - Written by Brech Devos */
    string public constant TABLE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    function base64(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return '';
    
        // load the table into memory
        string memory table = TABLE;

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((data.length + 2) / 3);

        // add some extra buffer at the end required for the writing
        string memory result = new string(encodedLen + 32);

        assembly {
            // set the actual output length
            mstore(result, encodedLen)
      
            // prepare the lookup table
            let tablePtr := add(table, 1)
      
            // input ptr
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))
      
            // result ptr, jump over length
            let resultPtr := add(result, 32)
      
            // run over the input, 3 bytes at a time
            for {} lt(dataPtr, endPtr) {}
            {
                dataPtr := add(dataPtr, 3)
          
                // read 3 bytes
                let input := mload(dataPtr)
          
                // write 4 characters
                mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr(18, input), 0x3F)))))
                resultPtr := add(resultPtr, 1)
                mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr(12, input), 0x3F)))))
                resultPtr := add(resultPtr, 1)
                mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr( 6, input), 0x3F)))))
                resultPtr := add(resultPtr, 1)
                mstore(resultPtr, shl(248, mload(add(tablePtr, and(        input,  0x3F)))))
                resultPtr := add(resultPtr, 1)
            }
      
            // padding with '='
            switch mod(mload(data), 3)
                case 1 { mstore(sub(resultPtr, 2), shl(240, 0x3d3d)) }
                case 2 { mstore(sub(resultPtr, 1), shl(248, 0x3d)) }
        }
    
        return result;
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

    function getConfig(uint256 _itemId) external override view returns(ItemConfig memory) {
        return configs[_itemId];
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
            ITreasury(treasury).deposit(paw, _pawCost);
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
            ITreasury(treasury).deposit(gem, _gemCost);
        }
    }
}