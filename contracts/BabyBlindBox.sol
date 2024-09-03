// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./interfaces/IBaby.sol";
import "./interfaces/IERC721Enumerable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IRandomseeds {
    function randomseed(uint256 _seed) external view returns (uint256);
    function multiRandomSeeds(uint256 _seed, uint256 _count) external view returns (uint256[] memory);
}

interface IWoofHelper {
    function mint(address _user, uint256[] memory _seeds, uint8 _nftType, uint8 _quality, uint8 _race, uint8 _gender) external returns(uint256);
}

interface IBaby2 is IBaby, IERC721Enumerable {
    function feedReqiuredCount() external returns(uint8);
    function freeFeedCount(uint32 _tokenId) external view returns(uint256);
}

struct BlindBoxConfig {
    uint16[5] qualityMintProbability;
}

contract BabyBlindBox is OwnableUpgradeable {

    event OpenBlindBox(address indexed account, uint256 indexed babyTokenId, uint256 indexed woofTokenId);

    IBaby2 public baby;
    IRandomseeds public randomseeds;
    IWoofHelper public woofHelper;
    BlindBoxConfig[5] private _blindBoxConfig;
    uint256 public freeFeedRequiredCount;
    bool public enableOpen;

    function initialize(
        address _baby,
        address _randomseeds,
        address _woofHelper
    ) external initializer {
        require(_baby != address(0));
        require(_randomseeds != address(0));
        require(_woofHelper != address(0));

        __Ownable_init();

        baby = IBaby2(_baby);
        randomseeds = IRandomseeds(_randomseeds);
        woofHelper = IWoofHelper(_woofHelper);
        freeFeedRequiredCount = 7;
        enableOpen = false;
    }

    function setBlindBoxConfig(BlindBoxConfig[5] memory _config) external onlyOwner {
        for (uint8 i = 0; i < 5; ++i) {
            _blindBoxConfig[i] = _config[i];
        }
    }

    function blindBoxConfig() public view returns(BlindBoxConfig[5] memory) {
        return _blindBoxConfig;
    }

    function setFreeFeedRequiredCount(uint256 _count) external onlyOwner {
        freeFeedRequiredCount = _count;
    }

    function setEnableOpen(bool _enable) external onlyOwner {
        enableOpen = _enable;
    }

    function openBlindBox(uint32 _tokenId) external {
        require(tx.origin == _msgSender(), "Not EOA");
        require(baby.ownerOf(_tokenId) == _msgSender(), "Not Owner");
        require(enableOpen == true, "Not enable");

        IBaby.WoofBaby memory w = baby.getTokenTraits(_tokenId); 
        require(w.feedCount >= baby.feedReqiuredCount() || baby.freeFeedCount(_tokenId) >= freeFeedRequiredCount, "Not reach the feed required count");

        uint256[] memory seeds = randomseeds.multiRandomSeeds(block.timestamp + _tokenId, 2);
        BlindBoxConfig memory config = _blindBoxConfig[w.quality];
        uint256 seed = seeds[0] % 1000;
        uint8 nftType = 0;
        for (uint8 i = 0; i < 3; ++i) {
            if (seed < w.woofMintProbability[i]) {
                nftType = i;
                break;
            }
        }

        seed = seeds[1] % 1000;
        uint8 quality = 0;
        for (uint8 i = 0; i < 5; ++i) {
            if (seed < config.qualityMintProbability[i]) {
                quality = i;
                break;
            }
        }

        seeds = randomseeds.multiRandomSeeds(block.timestamp + nftType + quality, 2);
        uint256 woofTokenId = woofHelper.mint(_msgSender(), seeds, nftType, quality, w.race, w.gender);
        baby.burn(_tokenId);
        emit OpenBlindBox(_msgSender(), _tokenId, woofTokenId);
    }
}

