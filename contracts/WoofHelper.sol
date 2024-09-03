// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./library/SafeERC20.sol";
import "./library/SafeMath.sol";
import "./interfaces/IWoofEnumerable.sol";
import "./interfaces/IWoofConfig.sol";
import "./interfaces/IItem.sol";
import "./interfaces/IWETH.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

interface IRandom {
    function getRandom(uint256 _seed) external view returns (uint256);
    function multiRandomSeeds(uint256 _seed, uint256 _count) external view returns (uint256[] memory);
    function rewardWoofMineSeed(uint256 _seed) external view returns(uint256);
    function addNonce() external;
}

interface IDiscount {
    function discount(address _user) external returns (uint256);
    function discountOff (address _user) external view returns (uint256);
    function freeUser(address _user) external returns (bool);
}

interface ITreasury {
    function deposit(address _token, uint256 _amount) external;
}

interface IVestingPool {
    function balanceOf(address _user) external view returns(uint256);
    function transferFrom(address _from, address _to, uint256 _amount) external;
}

interface IBarn {
    function randomBanditOwner(uint256 _seed) external view returns (address owner, uint32 tokenId);
}

interface IWoofMine {
    function mint(address _to) external;
}

contract WoofHelper is  OwnableUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    event Mint(address indexed account, IWoof.WoofWoofWest w, uint256 banditId);
    event BatchMint(address indexed account, IWoof.WoofWoofWest[10] w);
    event UpdateName(address indexed account, uint256 indexed tokenId, string name);
    event RecoverStamina(address indexed account, uint256 indexed tokenId, uint256 stamina);

    uint256 public mintPrice;
    uint256 public G0_MAX_MINT_AMOUNT;
    address public paidToken;
    bool public startG1Mint;

    IRandom public random;
    IDiscount public discount;
    IWoofConfig public config;
    ITreasury public treasury;
    IWoofEnumerable public woof;
    IBarn public barn;
    address public gem;

    uint256 public maxMintDiscountAmountOfEachUser;
    mapping(address => uint256) public mintDiscountAmountOfUser;

    uint256 private _minted;
    uint256[3][5] private _mintedDetails; 

    struct StolenInfo {
        uint32 stolenId;
        uint32 banditId;
        uint32 stolenTime;
    }

    uint8 public stolenProbability;
    StolenInfo[] public stolenInfo;
    mapping(uint256 => uint256[]) public banditStolenInfo;

    uint256 public nameCost;
    address public item;
    mapping(address => bool) public authControllers;
    IVestingPool public gemVestingPool;

    uint32[3] public genMinted;

    uint256 public batchMintBanditProbability;
    address public woofMine;
    uint32 public rewardMineCount;
    mapping(address=>bool) public rewardMineUsers;
    bool public strictRewardMine;

    uint32 public mineMintProbability;
    address public WBTC; 

    function initialize(
        address _paidToken,
        address _random,
        address _discount,
        address _config,
        address _treasury,
        address _woof,
        address _barn,
        address _gem,
        address _WBTC
    ) external initializer {
        require(_paidToken != address(0));
        require(_random != address(0));
        require(_discount != address(0));
        require(_config != address(0));
        require(_treasury != address(0));
        require(_woof != address(0));
        require(_barn != address(0));
        require(_gem != address(0));
        require(_WBTC != address(0));

        __Ownable_init();
        __Pausable_init();

        mintPrice = 30 * 1e6; //30 u
        paidToken = _paidToken;
        random = IRandom(_random);
        discount = IDiscount(_discount);
        config = IWoofConfig(_config);
        treasury = ITreasury(_treasury);
        woof = IWoofEnumerable(_woof);
        barn = IBarn(_barn);
        gem = _gem;
        WBTC = _WBTC;

        G0_MAX_MINT_AMOUNT = 5000;
        maxMintDiscountAmountOfEachUser = 10;
        startG1Mint = false;
        stolenProbability = 10;
        nameCost = 1e18;
        batchMintBanditProbability = 90;
        strictRewardMine = true;
        mineMintProbability = 5;
        _safeApprove(_paidToken, _treasury);
        _safeApprove(_gem, _treasury);
    }

    function setMintPrice(uint256 _price) external onlyOwner {
        mintPrice = _price;
    }

    function setG0MaxMintAmount(uint256 _amount) external onlyOwner {
        G0_MAX_MINT_AMOUNT = _amount;
    }

    function setPaidToken(address _token) external onlyOwner {
        require(_token != address(0));
        paidToken = _token;
        _safeApprove(_token, address(treasury));
    }

    function setMaxMintDiscountAmountOfEachUser(uint256 _amount) external onlyOwner {
        require(_amount >= 10);
        maxMintDiscountAmountOfEachUser = _amount;
    }

    function setGemVestingPool(address _pool) external onlyOwner {
        require(_pool != address(0));
        gemVestingPool = IVestingPool(_pool);
    }

    function setStolenProbability(uint8 _stolenProbability) external onlyOwner {
        require(_stolenProbability >= 5);
        stolenProbability = _stolenProbability;
    }

    function startG1MintNft(address _paidToken, uint256 _price) external onlyOwner {
        require(startG1Mint == false);
        require(_paidToken != address(0));
        require(_price >= 10 ether);
        startG1Mint = true;
        paidToken = _paidToken;
        mintPrice = _price;
        _safeApprove(_paidToken, address(treasury));
    }

    function setNameCost(uint256 _cost) external onlyOwner {
        nameCost = _cost;
    }

    function setDiscount(address _discount) external onlyOwner {
        require(_discount != address(0));
        discount = IDiscount(_discount);
    }

    function setItem(address _item) external onlyOwner {
        require(_item != address(0));
        item = _item;
    }

    function setAuthControllers(address _controller, bool _enable) external onlyOwner {
        authControllers[_controller] = _enable;
    }

    function setBatchMintBanditProbability(uint256 _probability) external onlyOwner {
        batchMintBanditProbability = _probability;
    }

    function setWoofMine(address _mine) external onlyOwner {
        woofMine = _mine;
    }

    function setStrictRewardMine(bool _strict) external onlyOwner {
        strictRewardMine = _strict;
    }

    function setMineMintProbability(uint32 _probability) external onlyOwner {
        mineMintProbability = _probability;
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function mint(address _referrer) external payable whenNotPaused {
        require(tx.origin == _msgSender(), "Not EOA");
        require(_msgSender() != _referrer, "Referrer can't be self");
        uint256 paymentAmount = mintPrice;
        if (startG1Mint == false) {
            uint256 off = discount.discount(_msgSender());
            if (off < 100) {
                if (mintDiscountAmountOfUser[_msgSender()] >= maxMintDiscountAmountOfEachUser) {
                    off = 100;
                } else {
                    mintDiscountAmountOfUser[_msgSender()] += 1;
                }
            }
            paymentAmount = paymentAmount * off / 100;
        }
        _deposit(paymentAmount, _referrer);
        _mint(false);
        _mintWoofMine();
    }

    /*function freeMint() external whenNotPaused {
        bool free = discount.freeUser(_msgSender());
        require(free == true);
        _mint(true);
    }*/

    /*function batchMint(address _referrer) external payable whenNotPaused {
        require(tx.origin == _msgSender(), "Not EOA");
        uint256 paymentAmount = mintPrice;
        if (startG1Mint == false) {
            require(_minted + 10 <= G0_MAX_MINT_AMOUNT, "All G0 NFT minted");
        }

        uint256 off = discount.discount(_msgSender());
        if (off < 100) {
            if (mintDiscountAmountOfUser[_msgSender()] >= maxMintDiscountAmountOfEachUser) {
                paymentAmount = paymentAmount * 10;
            } else {
                uint256 discountAmt = maxMintDiscountAmountOfEachUser - mintDiscountAmountOfUser[_msgSender()];
                if (discountAmt < 10) {
                    mintDiscountAmountOfUser[_msgSender()] += discountAmt;
                    paymentAmount = discountAmt * paymentAmount * off / 100 + (10 - discountAmt) * paymentAmount;
                } else {
                    mintDiscountAmountOfUser[_msgSender()] += 10;
                    paymentAmount = 10 * paymentAmount * off / 100;
                }
            }
        } else {
            paymentAmount = paymentAmount * 10;
        }

        paymentAmount = paymentAmount * 9 / 10;
        _deposit(paymentAmount, _referrer);

        bool mintBanditOrHunter = false;
        IWoof.WoofWoofWest[10] memory arr;
        for (uint8 i = 0; i < 10; ++i) {
            _minted++;
            random.addNonce();
            IWoof.WoofWoofWest memory w;
            uint256[] memory seeds = random.multiRandomSeeds(_minted, 4);
            if (i == 9 && mintBanditOrHunter == false) {
                uint8 nftType = uint8((seeds[0] % 100 < batchMintBanditProbability) ? 1 : 2);
                w = config.randomWoofWoofWest(seeds, nftType);
            } else {
                w = config.randomWoofWoofWest(seeds);
            }
            w.tokenId = uint32(_minted);
            w.generation = (startG1Mint == false) ? 0 : 1;
            genMinted[w.generation] += 1;
            _mintedDetails[w.quality][w.nftType] += 1;
            if (mintBanditOrHunter == false) {
                mintBanditOrHunter = (w.nftType > 0) ? true : false;
            }
            arr[i] = w;
        }
        woof.batchMint(_msgSender(), arr);
        emit BatchMint(_msgSender(), arr);
        _mintWoofMine();
    }*/

    receive() external payable {
        assert(msg.sender == WBTC); // only accept ETH via fallback from the WETH contract
    }

    function mint(address _user, uint256[] memory _seeds, uint8 _nftType, uint8 _quality, uint8 _race, uint8 _gender) external returns(uint256){
        require(authControllers[_msgSender()], "no auth");
        _minted++;
        IWoof.WoofWoofWest memory w = config.randomWoofWoofWest(_seeds, _nftType, _quality, _race, _gender);
        w.tokenId = uint32(_minted);
        w.generation = 2;
        _mintedDetails[w.quality][w.nftType] += 1;
        genMinted[2] += 1;
        woof.mint(_user, w);
        emit Mint(_user, w, 0);
        return w.tokenId;
    }

    function name(uint256 _tokenId, string memory _name) external {
        require(bytes(_name).length <= 100, "Invalid name");
        require(woof.ownerOf(_tokenId) == _msgSender(), "Not owner");

        uint256 _gemCost = nameCost;
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
        woof.updateName(_tokenId, _name);
        emit UpdateName(_msgSender(), _tokenId, _name);
    }

    function recoverStamina(uint32 _tokenId, uint32[] memory _itemIds, uint32[] memory _amount) external {
        require(tx.origin == _msgSender(), "Not EOA");
        require(woof.ownerOf(_tokenId) == _msgSender(), "Not owner");
        require(_itemIds.length <= 4 && _itemIds.length == _amount.length, "Invalid items");
        uint32 stamina = _consumeStaminaItem(_itemIds, _amount);
        IWoof.WoofWoofWest memory w = woof.getTokenTraits(_tokenId);
        stamina += w.attributes[0];
        woof.updateStamina(_tokenId, stamina);
        emit RecoverStamina(_msgSender(), _tokenId, stamina);
    }

    function _deposit(uint256 _amount, address _referrer) internal {
        _referrer;
        address _paidToken = paidToken;
        if (_paidToken != gem) {
            if (_paidToken == WBTC) {
                require(_amount == msg.value, "amount != msg.value");
                IWETH(_paidToken).deposit{value: msg.value}();
            } else {
                require(IERC20(_paidToken).balanceOf(_msgSender()) >= _amount, "Invalid balance");
                IERC20(_paidToken).safeTransferFrom(_msgSender(), address(this), _amount);
            }
            /*if (_referrer != address(0)) {
                uint256 refAmount = _amount / 10;
                _amount -= refAmount;
                IERC20(_paidToken).safeTransfer(_referrer, refAmount);
            }*/
        } else {
            uint256 bal1 = IERC20(_paidToken).balanceOf(_msgSender());
            uint256 bal2 = gemVestingPool.balanceOf(_msgSender());
            require(bal1 + bal2 >= _amount, "Invalid balance");
            if (bal2 >= _amount) {
                gemVestingPool.transferFrom(_msgSender(), address(this), _amount);
            } else {
                if (bal2 > 0) {
                    gemVestingPool.transferFrom(_msgSender(), address(this), bal2);
                }
                IERC20(_paidToken).safeTransferFrom(_msgSender(), address(this), _amount - bal2);
            }
        }
        treasury.deposit(_paidToken, _amount);
    }

    function _mint(bool _free) internal {
        _minted++;
        if (startG1Mint == false) {
            require(_minted <= G0_MAX_MINT_AMOUNT, "All G0 NFT minted");
        }
        random.addNonce();
        uint256[] memory seeds = random.multiRandomSeeds(_minted, 5);
        IWoof.WoofWoofWest memory w = config.randomWoofWoofWest(seeds);
        w.tokenId = uint32(_minted);
        w.generation = (startG1Mint == false) ? 0 : 1;
        genMinted[w.generation] += 1;
        _mintedDetails[w.quality][w.nftType] += 1;

        (address recipent, uint32 banditId) = _selectRecipient(seeds[4]);
        woof.mint(recipent, w);
        if (banditId  > 0) {
            StolenInfo memory info;
            info.stolenId = w.tokenId;
            info.banditId = banditId;
            info.stolenTime = uint32(block.timestamp);
            stolenInfo.push(info);
            banditStolenInfo[banditId].push(stolenInfo.length - 1);
            emit Mint(_msgSender(), w, banditId);
        } else {
            if (_free) {
                emit Mint(_msgSender(), w, 0);
            } else {
                emit Mint(_msgSender(), w, 0);
            }
        }
    }

    function _mintWoofMine() internal {
        if (strictRewardMine && rewardMineUsers[_msgSender()]) {
            return;
        }

        if (mineMintProbability == 0) {
            return;
        }

        if (startG1Mint == false && rewardMineCount <= G0_MAX_MINT_AMOUNT / 50 && woofMine != address(0)) {
            rewardMineCount += 1;
            uint256 seed = random.rewardWoofMineSeed(_minted + rewardMineCount);
            if (seed % mineMintProbability == 0) {
                IWoofMine(woofMine).mint(_msgSender());
                rewardMineUsers[_msgSender()] = true;
            }
        }
    }

    function _selectRecipient(uint256 _seed) internal view returns (address, uint32) {
        if (startG1Mint == false) {
            return (_msgSender(),  0);
        }

        if ((_seed % stolenProbability) != 0) {
            return (_msgSender(), 0);
        }

        (address bandit, uint32 banditId)= barn.randomBanditOwner(_seed); 
        if (bandit == address(0)) {
            return (_msgSender(), 0);
        }
        return (bandit, banditId);
    }

    function _safeApprove(address _token, address _spender) internal {
        if (_token != address(0) && IERC20(_token).allowance(address(this), _spender) == 0) {
            IERC20(_token).safeApprove(_spender, type(uint256).max);
        }
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

    function currentGeneration() public view returns (uint8) {
        if (_minted <= G0_MAX_MINT_AMOUNT) return 0;
        return 1;
    }

    function minted() public view returns(uint256 totalMinted, uint256[3] memory mintedOfType, uint256[5] memory mintedOfQuality) {
        totalMinted = _minted;
        uint256[3][5] memory details = _mintedDetails;
        for (uint256 i = 0; i < 5; ++i) {
            mintedOfType[0] += details[i][0];
            mintedOfType[1] += details[i][1];
            mintedOfType[2] += details[i][2];
            mintedOfQuality[i] = details[i][0] + details[i][1] + details[i][2];
        }
    }

    function mintDashboard(address _user) public view returns(
        uint256 mintPrice_,
        uint256 G0MinMaxAmount_,
        uint256 minted_,
        uint256 discount_,
        uint256 discountMinted_,
        uint256 balanceOf_,
        bool startG1Mint_
    ) {
        mintPrice_ = mintPrice;
        G0MinMaxAmount_ = G0_MAX_MINT_AMOUNT;
        minted_ = _minted;
        startG1Mint_ = startG1Mint;
        if (_user != address(0)) {
            if (startG1Mint_ == false) {
                discount_ = discount.discountOff(_user);
                discountMinted_ = mintDiscountAmountOfUser[_user];
            } else {
                discount_ = 100;
                discountMinted_ = 0;
            }
            balanceOf_ = IERC20(paidToken).balanceOf(_user);
        } else {
            discount_ = 0;
            discountMinted_ = 0;
            balanceOf_ = 0;
        }
    }

    function stolenRecodesCount() public view returns(uint32) {
        return uint32(stolenInfo.length);
    }

    function stolenRecordsCountOfBandit(uint32 _banditId) public view returns(uint32) {
        return uint32(banditStolenInfo[_banditId].length);
    }

    struct WoofBrief {
        uint8 nftType;
        uint8 quality;
        uint8 level;
        uint16 cid;
        string name;
    }

    struct StolenRecord {
        WoofBrief bandit;
        WoofBrief stolenNft;
        uint32 stolenTime;
    }

    function getBanditStolenRecords(uint256 _index, uint8 _len, uint8 _sort) public view returns(
        StolenRecord[] memory nfts, 
        uint8 len
    ) {
        require(_len <= 10 && _len != 0);
        nfts = new StolenRecord[](_len);
        len = 0;

        uint256 bal = stolenInfo.length;
        if (bal == 0 || _index >= bal) {
            return (nfts, len);
        }

        for (uint8 i = 0; i < _len; ++i) {
            uint256 index = (_sort == 0) ? _index : (bal - _index - 1);
            nfts[i] = stolenRecordByIndex(index);
            ++_index;
            ++len;
            if (_index >= bal) {
                return (nfts, len);
            }
        }
    }

    function getBanditStolenRecords(uint32 _tokenId, uint256 _index, uint8 _len, uint8 _sort) public view returns(
        StolenRecord[] memory nfts, 
        uint8 len
    ) {
        require(_len <= 10 && _len != 0);
        nfts = new StolenRecord[](_len);
        len = 0;

        uint256 bal = banditStolenInfo[_tokenId].length;
        if (bal == 0 || _index >= bal) {
            return (nfts, len);
        }

        for (uint8 i = 0; i < _len; ++i) {
            uint256 index = (_sort == 0) ? _index : (bal - _index - 1);
            uint256 recordId = banditStolenInfo[_tokenId][index];
            nfts[i] = stolenRecordByIndex(recordId);
            ++_index;
            ++len;
            if (_index >= bal) {
                return (nfts, len);
            }
        }
    }

    function stolenRecordByIndex(uint256 _index) public view returns(StolenRecord memory) {
        StolenRecord memory record;
        StolenInfo memory info = stolenInfo[_index];
        IWoof.WoofWoofWest memory ww = woof.getTokenTraits(info.banditId);
        record.bandit.nftType = ww.nftType;
        record.bandit.quality = ww.quality;
        record.bandit.level = ww.level;
        record.bandit.cid = ww.cid;
        record.bandit.name = ww.name;
        ww = woof.getTokenTraits(info.stolenId);
        record.stolenNft.nftType = ww.nftType;
        record.stolenNft.quality = ww.quality;
        record.stolenNft.level = ww.level;
        record.stolenNft.cid = ww.cid;
        record.stolenNft.name = ww.name;
        record.stolenTime = info.stolenTime;
        return record;
    }
}