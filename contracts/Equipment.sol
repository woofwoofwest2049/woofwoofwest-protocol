// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./interfaces/IEquipment.sol";
import "./interfaces/ITraits.sol";
import "./library/SafeERC20.sol";
import "./library/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

interface IRandomseeds {
    function randomseed(uint256 _seed) external view returns (uint256);
    function multiRandomSeeds(uint256 _seed, uint256 _count) external view returns (uint256[] memory);
}

contract Equipment is IEquipment, ERC721EnumerableUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    ITraits public traits;
    mapping(uint256 => sEquipment) public tokenTraits;
    mapping(address => bool) public authControllers;
    uint32 public minted;
    uint256 public burned;

    IEquipmentConfig public config;
    IRandomseeds public randomseeds;

    function initialize(
        address _traits,
        address _config,
        address _randomseeds
    ) external initializer {
        require(_traits != address(0));
        require(_config != address(0));
        require(_randomseeds != address(0));

        __ERC721_init("Woof Woof West Gears", "WWG");
        __ERC721Enumerable_init();
        __Ownable_init();

        traits = ITraits(_traits);
        config = IEquipmentConfig(_config);
        randomseeds = IRandomseeds(_randomseeds);
    }

    function setAuthControllers(address _controller, bool _enable) external onlyOwner {
        authControllers[_controller] = _enable;
    }

    function mint(address _to, uint8 _type) external override returns(sEquipment memory) {
        require(authControllers[_msgSender()], "no auth");
        minted += 1;
        uint256[] memory seeds = randomseeds.multiRandomSeeds(minted, 5);
        sEquipment memory e = config.randomEquipment(seeds, _type);
        e.tokenId = minted;
        tokenTraits[minted] = e;
        _safeMint(_to, e.tokenId);
        return e;
    }

    function burn(uint256 _tokenId) external override {
        require(authControllers[_msgSender()], "no auth");
        _burn(_tokenId);
        burned += 1;
    }

    function updateTokenTraits(sEquipment memory _e) external override {
        require(authControllers[_msgSender()], "no auth");
        tokenTraits[_e.tokenId] = _e;
    }

    function getTokenTraits(uint256 _tokenId) public override view returns (sEquipment memory) {
        return tokenTraits[_tokenId];
    }

    function getConfig(uint16 _cid) external override view returns(IEquipmentConfig.sEquipmentConfig memory) {
        return config.getConfig(_cid);
    }

    function getLevelConfig(uint8 _type, uint8 _level) external override view returns(IEquipmentConfig.sEquipmentLevelConfig memory) {
        return config.getLevelConfig(_type, _level);
    }

    function getEquipmentBoxConfig(uint8 _type) external override view returns(IEquipmentConfig.sEquipmentBoxConfig memory) {
        return config.getEquipmentBoxConfig(_type);
    }

    function getQualityConfig(uint8 _quality) external override view returns(IEquipmentConfig.sEquipmentQualityConfig memory) {
        return config.getQualityConfig(_quality);
    }

    function randomEquipmentBattleAttributes(uint256 _hpSeed, uint256 _attackSeed, uint256 _hitRateSeed, sEquipment memory e) external override view returns(sEquipment memory) {
        return config.randomEquipmentBattleAttributes(_hpSeed, _attackSeed, _hitRateSeed, e);
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

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        require(_exists(_tokenId));
        return traits.tokenURI(_tokenId);
    }

    function getUserTokenTraits(address _user, uint256 _index, uint8 _len) public view returns(
        sEquipment[] memory nfts, 
        uint8 len
    ) {
        require(_len <= 100 && _len != 0);
        nfts = new sEquipment[](_len);
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

    function getTokenDetails(uint32 _tokenId) public view returns(sEquipment memory equip, address owner) {
        equip = getTokenTraits(_tokenId);
        owner = ownerOf(_tokenId);
    }
}


