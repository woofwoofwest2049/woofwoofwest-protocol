// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./interfaces/IBaby.sol";
import "./interfaces/IBabyConfig.sol";
import "./interfaces/IWoofEnumerable.sol";
import "./library/SafeERC20.sol";
import "./library/SafeMath.sol";
import "./interfaces/ITraits.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IRandomseeds {
    function randomseed(uint256 _seed) external view returns (uint256);
    function multiRandomSeeds(uint256 _seed, uint256 _count) external view returns (uint256[] memory);
}

interface ITreasury {
    function deposit(address _token, uint256 _amount) external;
}

interface IVestingPool {
    function balanceOf(address _user) external view returns(uint256);
    function transferFrom(address _from, address _to, uint256 _amount) external;
}

interface IItem {
    function mint(address _account, uint256 _itemId, uint256 _amount) external;
    function burn(address _account, uint256 _itemId, uint256 _amount) external;
}

contract Baby is IBaby, ERC721EnumerableUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    event UpdateTraits(WoofBaby w);
    event Feed(address indexed account, uint256 indexed tokenId);

    ITraits public traits;
    IWoofEnumerable public woof;
    IRandomseeds public randomseeds;
    IVestingPool public pawVestingPool;
    ITreasury public treasury;
    IItem public item;
    address public paw;
    IBabyConfig public babyConfig;

    mapping(uint256 => WoofBaby) public tokenTraits;
    mapping(address => bool) public authControllers;
    mapping(uint32 => uint32) public woofAccRewardBabyAmount;

    uint16 public scope;
    uint16[3] public woofMintProbability;
    uint8 public feedReqiuredCount;
    uint32 public feedCountdown;
    

    uint256 private _minted;
    uint256[5] private _mintedDetails;
    uint256 private _burned;
    mapping(address => uint) public freeMintAccount;
    uint256 public maxFreeMint;
    struct FreeFeedInfo {
        uint256 count;
        uint256 lastFeedTime;
    }
    mapping(uint => FreeFeedInfo) public freeFeedNft;
    bool public enableFreeFeed;

    function initialize(
        address _traits,
        address _woof,
        address _randomseeds,
        address _pawVestingPool,
        address _treasury,
        address _item,
        address _paw,
        address _babyConfig
    ) external initializer {
        require(_traits != address(0));
        require(_woof != address(0));
        require(_randomseeds != address(0));
        require(_pawVestingPool != address(0));
        require(_treasury != address(0));
        require(_item != address(0));
        require(_paw != address(0));
        require(_babyConfig != address(0));

        __ERC721_init("Woof Woof West Baby", "WWB");
        __ERC721Enumerable_init();
        __Ownable_init();

        traits = ITraits(_traits);
        woof = IWoofEnumerable(_woof);
        randomseeds = IRandomseeds(_randomseeds);
        pawVestingPool = IVestingPool(_pawVestingPool);
        treasury = ITreasury(_treasury);
        item = IItem(_item);
        paw = _paw;
        babyConfig = IBabyConfig(_babyConfig);
        scope = 100;
        woofMintProbability = [900,70,30];
        feedReqiuredCount= 5;
        feedCountdown = 1 days;
        maxFreeMint = 1000;
        enableFreeFeed = true;

        _safeApprove(_paw, _treasury);
    }

    function setAuthControllers(address _controller, bool _enable) external onlyOwner {
        authControllers[_controller] = _enable;
    }

    function setFeedRequiredCount(uint8 _count) external onlyOwner {
        feedReqiuredCount = _count;
    }

    function setFeedCountdown(uint32 _countdown) external onlyOwner {
        feedCountdown = _countdown;
    }

    function setScope(uint16 _scope) external onlyOwner {
        require(_scope <= 500);
        scope = _scope;
    }

    function setWoofMintProbability(uint16[3] memory _probability) external onlyOwner {
        require(_probability[0] + _probability[1] + _probability[2] == 1000);
        woofMintProbability = _probability;
    }

    function setPawVestingPool(address _pool) external onlyOwner {
        pawVestingPool = IVestingPool(_pool);
    }

    function setFreeMintAccount(address[] memory _accounts, uint _type) external onlyOwner {
        for (uint256 i = 0; i < _accounts.length; ++i) {
            freeMintAccount[_accounts[i]] = _type;
        }
    }

    function setMaxFreeMint(uint256 _maxAmount) external onlyOwner {
        maxFreeMint = _maxAmount;
    }

    function setFreeFeedEnable(bool _enable) external onlyOwner {
        enableFreeFeed = _enable;
    }

    function freeMintInfo() external view returns(uint256 maxMint_, uint256 minted_) {
        maxMint_ = maxFreeMint;
        minted_ = _minted;
    }

    function freeMint() external {
        require(freeMintAccount[msg.sender] != 2, "1");
        require(_minted < maxFreeMint, "2");
        uint256[] memory seeds = randomseeds.multiRandomSeeds(_minted, 6);
 
        uint256 seed = seeds[1] % 100;
        uint8[5] memory qualityConfig = babyConfig.getExploreBabyQualityConfig(0, 0);
        uint8 quality = 0;
        for (uint8 i = 0; i < 5; ++i) {
            if (seed < qualityConfig[i]) {
                quality = i;
                break;
            }
        }

        _minted++;
        WoofBaby memory baby;
        baby.tokenId = uint32(_minted);
        baby.gender = uint8(seeds[2] % 2);
        baby.race = uint8(seeds[3] % 2);
        baby.quality = quality;
        baby.woofMintProbability = woofMintProbability;

        uint8 t = uint8(seeds[4] % 3);
        uint16 s = uint16(seeds[5] % scope);
        if (t == 0) {
            if (s + baby.woofMintProbability[0] >= 1000) {
                baby.woofMintProbability[0] = 1000;
                baby.woofMintProbability[1] = 0;
                baby.woofMintProbability[2] = 0;
            } else {
                baby.woofMintProbability[0] += s;
                if (s >= baby.woofMintProbability[2]) {
                    baby.woofMintProbability[1] = 1000 - baby.woofMintProbability[0];
                    baby.woofMintProbability[2] = 0;
                } else {
                    baby.woofMintProbability[2] -= s;
                }
            }
        } else {
            baby.woofMintProbability[0] -= s;
            baby.woofMintProbability[t] += s;
        }

        _safeMint(msg.sender, baby.tokenId);
        _mintedDetails[baby.quality] += 1;
        tokenTraits[baby.tokenId] = baby;
        freeMintAccount[msg.sender] = 2;
        return;
    }

    function freeFeed(uint32 _tokenId) external {
        require(tx.origin == _msgSender(), "1");
        require(ownerOf(_tokenId) == _msgSender(), "2");
        require(enableFreeFeed == true, "3");
        require(freeFeedNft[_tokenId].lastFeedTime + feedCountdown < block.timestamp, "3");
        freeFeedNft[_tokenId].count += 1;
        freeFeedNft[_tokenId].lastFeedTime = block.timestamp;
    }

    function freeFeedCount(uint32 _tokenId) public view returns(uint256) {
        return freeFeedNft[_tokenId].count;
    }

    function mint(address _account, uint32 _woofTokenId) external override returns(uint32 _babyTokenId) {
        require(authControllers[_msgSender()], "1");
        IWoof.WoofWoofWest memory w = woof.getTokenTraits(_woofTokenId);
        (uint16 maxRewardAmount, uint16 probability) = babyConfig.getExploreBabyProbability(w.generation, w.quality, woofAccRewardBabyAmount[_woofTokenId]);
        if (woofAccRewardBabyAmount[_woofTokenId] >= maxRewardAmount) {
            return 0;
        }

        uint256[] memory seeds = randomseeds.multiRandomSeeds(_minted, 6);
        if (seeds[0] % 1000 >= probability) {
            return 0;
        }

        uint256 seed = seeds[1] % 100;
        uint8[5] memory qualityConfig = babyConfig.getExploreBabyQualityConfig(w.quality, woofAccRewardBabyAmount[_woofTokenId]);
        bool find = false;
        uint8 quality = 0;
        for (uint8 i = 0; i < 5; ++i) {
            if (seed < qualityConfig[i]) {
                find = true;
                quality = i;
                break;
            }
        }

        if (find == false) {
            return 0;
        }

        _minted++;
        WoofBaby memory baby;
        baby.tokenId = uint32(_minted);
        baby.gender = uint8(seeds[2] % 2);
        baby.race = uint8(seeds[3] % 2);
        baby.quality = quality;
        baby.woofMintProbability = woofMintProbability;

        uint8 t = uint8(seeds[4] % 3);
        uint16 s = uint16(seeds[5] % scope);
        if (t == 0) {
            if (s + baby.woofMintProbability[0] >= 1000) {
                baby.woofMintProbability[0] = 1000;
                baby.woofMintProbability[1] = 0;
                baby.woofMintProbability[2] = 0;
            } else {
                baby.woofMintProbability[0] += s;
                if (s >= baby.woofMintProbability[2]) {
                    baby.woofMintProbability[1] = 1000 - baby.woofMintProbability[0];
                    baby.woofMintProbability[2] = 0;
                } else {
                    baby.woofMintProbability[2] -= s;
                }
            }
        } else {
            baby.woofMintProbability[0] -= s;
            baby.woofMintProbability[t] += s;
        }

        _safeMint(_account, baby.tokenId);
        _mintedDetails[baby.quality] += 1;
        tokenTraits[baby.tokenId] = baby;
        woofAccRewardBabyAmount[_woofTokenId] += 1;
        return baby.tokenId;
    }

    function burn(uint32 _tokenId) external override {
        require(authControllers[_msgSender()], "1");
        _burn(_tokenId);
        _burned += 1;
    }

    function updateTokenTraits(WoofBaby memory _w) external override {
        require(authControllers[_msgSender()], "1");
        tokenTraits[_w.tokenId] = _w;
        emit UpdateTraits(_w);
    }

    function feed(uint32 _tokenId, uint16 _cid) external {
        require(tx.origin == _msgSender(), "1");
        require(ownerOf(_tokenId) == _msgSender(), "2");
        WoofBaby memory baby = getTokenTraits(_tokenId);
        require(baby.feedCount < feedReqiuredCount, "3");
        require(baby.lastFeedTime + feedCountdown < block.timestamp, "4");

        IBabyConfig.BabyFeedConfig memory config = babyConfig.getBabyFeedConfig(_cid);
        require(config.cid == _cid, "5");

        uint8 index = (baby.feedCount < 5) ? baby.feedCount : 4;
        _pawCost(baby.quality, config.qualityPawCost);
        _itemsCost(baby.quality, index, config.itemCost, config.qualityItemCostAmount);

        if (baby.quality < 4) {
            uint256[] memory seeds = randomseeds.multiRandomSeeds(block.timestamp + _tokenId, 1);
            uint256 seed = seeds[0] % 100;
            if (seed < config.qualityProbability[baby.quality]) {
                baby.quality += 1;
            }
        }
        
        uint16 addBanditProbability = config.addBanditProbability[index];
        uint16 addHunterProbability = config.addHunterProbability[index];
        if (addBanditProbability > 0) {
            if (baby.woofMintProbability[1] + addBanditProbability >= 1000) {
                baby.woofMintProbability[1] = 1000;
                baby.woofMintProbability[0] = 0;
                baby.woofMintProbability[2] = 0;
            } else {
                baby.woofMintProbability[1] += addBanditProbability;
                if (addBanditProbability >= baby.woofMintProbability[0]) {
                    baby.woofMintProbability[0] = 0;
                    baby.woofMintProbability[2] = 1000 - baby.woofMintProbability[1];
                } else {
                    baby.woofMintProbability[0] -= addBanditProbability;
                }
            }
        }

        if (addHunterProbability > 0) {
            if (baby.woofMintProbability[2] + addHunterProbability >= 1000) {
                baby.woofMintProbability[2] = 1000;
                baby.woofMintProbability[0] = 0;
                baby.woofMintProbability[1] = 0;
            } else {
                baby.woofMintProbability[2] += addHunterProbability;
                if (addHunterProbability >= baby.woofMintProbability[0]) {
                    baby.woofMintProbability[0] = 0;
                    baby.woofMintProbability[1] = 1000 - baby.woofMintProbability[2];
                } else {
                    baby.woofMintProbability[0] -= addHunterProbability;
                }
            }
        }

        baby.feedCount += 1;
        baby.lastFeedTime = uint32(block.timestamp);
        tokenTraits[baby.tokenId] = baby;
        emit Feed(_msgSender(), baby.tokenId);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        // Hardcode the Auth controllers's approval so that users don't have to waste gas approving
        if (authControllers[_msgSender()] == false)
            require(_isApprovedOrOwner(_msgSender(), tokenId));
        _transfer(from, to, tokenId);
    }

    function minted() public view returns(uint256 totalMinted, uint256[5] memory mintedDetails, uint256 burned) {
        totalMinted = _minted;
        mintedDetails = _mintedDetails;
        burned = _burned;
    }

    function getTokenTraits(uint256 _tokenId) public view override returns (WoofBaby memory) {
        return tokenTraits[_tokenId];
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        require(_exists(_tokenId));
        return traits.tokenURI(_tokenId);
    }

    function getUserTokenTraits(address _user, uint256 _index, uint8 _len) public view returns(
        WoofBaby[] memory nfts, 
        uint8 len
    ) {
        require(_len <= 100 && _len != 0);
        nfts = new WoofBaby[](_len);
        len = 0;

        uint256 bal = balanceOf(_user);
        if (bal == 0 || _index >= bal) {
            return (nfts, len);
        }

        for (uint8 i = 0; i < _len; ++i) {
            uint256 tokenId = tokenOfOwnerByIndex(_user, _index);
            nfts[i] = getTokenTraits(tokenId);
            ++_index;
            ++len;
            if (_index >= bal) {
                return (nfts, len);
            }
        }
    }

    function getTokenDetails(uint32 _tokenId) public view returns(WoofBaby memory baby, address owner) {
        baby = getTokenTraits(_tokenId);
        owner = ownerOf(_tokenId);
    }

    function _pawCost(uint8 _quality, uint256[5] memory _qualityPawCost) internal {
        uint256 _cost = _qualityPawCost[_quality];
        if (_cost == 0) {
            return;
        }

        uint256 bal1 = IERC20(paw).balanceOf(_msgSender());
        uint256 bal2 = pawVestingPool.balanceOf(_msgSender());
        require(bal1 + bal2 >= _cost, "1");
        if (bal2 >= _cost) {
            pawVestingPool.transferFrom(_msgSender(), address(this), _cost);
        } else {
            if (bal2  > 0) {
                pawVestingPool.transferFrom(_msgSender(), address(this), bal2);
            }
            IERC20(paw).safeTransferFrom(_msgSender(), address(this), _cost - bal2);
        }
        treasury.deposit(paw, _cost);
    }

    function _itemsCost(uint8 _quality, uint8 _index, uint32[5] memory _itemCost, uint8[5] memory _qualityItemCostAmount) internal {
        uint32 itemId = _itemCost[_index];
        uint32 amt = _qualityItemCostAmount[_quality];
        if (itemId > 0 && amt > 0) {
            item.burn(_msgSender(), itemId, amt);
        }
    }

    function _safeApprove(address _token, address _spender) internal {
        if (_token != address(0) && IERC20(_token).allowance(address(this), _spender) == 0) {
            IERC20(_token).safeApprove(_spender, type(uint256).max);
        }
    }
}