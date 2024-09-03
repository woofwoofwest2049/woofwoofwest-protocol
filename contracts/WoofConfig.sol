// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./interfaces/IWoof.sol";
import "./interfaces/IWoofConfig.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IWoofMintHelper {
    function currentGeneration() external view returns (uint8);
    function minted() external view returns(uint256 totalMinted, uint256[3] memory mintedOfType, uint256[5] memory mintedOfQuality);
}

contract WoofConfig is IWoofConfig, OwnableUpgradeable {

    IWoofMintHelper public mintHelper;
    IWoof public woof;
    uint16[3] public nftTypeProbability;
    uint8[][3] public mintCid;
    mapping (uint16=>WoofWoofWestConfig) public cidToConfig;

    uint16[5] public qualityProbability;
    WoofWoofWestQualityConfig[5] public qualityConfig;
    WoofWoofWestLevelConfig[20][3] public levelConfig;
    LevelUpCost[20] private q0LevelUpCost;
    LevelUpCost[20] private q1LevelUpCost;
    LevelUpCost[20] private q2LevelUpCost;
    LevelUpCost[20] private q3LevelUpCost;
    LevelUpCost[20] private q4LevelUpCost;

    LevelUpCost private q0SyntheticCost;
    LevelUpCost private q1SyntheticCost;

    mapping (uint16=>uint16) public levelToStealIndex;
    uint16[] public stealBuf;
    bool public strict;

    mapping (uint256 => uint16[]) public mintCid2;

    function initialize(
    ) external initializer {
        __Ownable_init();

        nftTypeProbability = [900, 70, 30];
        qualityProbability = [640, 250, 90, 15, 5];
        strict = false;
        uint8[20] memory _index = [0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4];
        uint8[5] memory _stealBuf = [1,2,4,8,16];
        for (uint16 i = 0; i < 20; ++i) {
            levelToStealIndex[i+1] = _index[i];
        }
        stealBuf = _stealBuf;
        mintCid[0] = [1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,6,6,6,6,7,7,7,7,8,8,8,8,9,9,9,9,10,10,10,10,11,11,11,11,12,12,12,12,13,13,13,13,14,14,14,14,15,15,15,15,16,17];
        mintCid[1] = [18,18,18,18,19,19,19,19,20,20,20,20,21,21,21,21,22,22,22,22,23,23,23,23,24,24,24,24,25,25,25,25,26,26,26,26,27,27,27,27,28,29,42];
        mintCid[2] = [30,30,30,30,31,31,31,31,32,32,32,32,33,33,33,33,34,34,34,34,35,35,35,35,36,36,36,36,37,37,37,37,38,38,38,38,39,39,39,39,40,41];
    }

    function setNftTypeProbability(uint16[3] memory _nftTypeProbability) external onlyOwner {
        require(_nftTypeProbability[0] + _nftTypeProbability[1] + _nftTypeProbability[2] == 1000);
        nftTypeProbability = _nftTypeProbability;
    }

    function setMintCid(uint8 _nftType, uint8[] memory _cid) external onlyOwner {
        require(_nftType < 3);
        mintCid[_nftType] = _cid;
    }

    function setQualityProbability(uint16[5] memory _qualityProbability) external onlyOwner {
        require(_qualityProbability[0] + _qualityProbability[1] + _qualityProbability[2] + _qualityProbability[3] + _qualityProbability[4] == 1000);
        qualityProbability = _qualityProbability;
    }

    function setConfigs(WoofWoofWestConfig[] memory _configs) external onlyOwner {
        clearMintCid2();
        for (uint256 i = 0; i < _configs.length; ++i) {
            WoofWoofWestConfig memory c = _configs[i];
            cidToConfig[c.cid] = c;
            uint256 key = getKey(c.nftType, c.race, c.gender);
            mintCid2[key].push(c.cid);
        }
    }

    function setQualityConfig(WoofWoofWestQualityConfig[5] memory _config) external onlyOwner {
        for (uint8 i = 0; i < 5; ++i) {
            qualityConfig[i] = _config[i];
        }
    }

    function setLevelConfig(WoofWoofWestLevelConfig[20][3] memory _config) external onlyOwner {
        for (uint8 i = 0; i < 3; ++i) {
            for (uint8 j = 0; j < 20; ++j) {
                levelConfig[i][j] = _config[i][j];
            }
        }
    }

    function setLevelUpCost(LevelUpCost[20] memory _qCost, uint8 _quality) external onlyOwner {
        if (_quality == 0) {
            for (uint8 i = 0; i < 20; ++i) {
                q0LevelUpCost[i].nftCost = _qCost[i].nftCost;
                q0LevelUpCost[i].pawCost = _qCost[i].pawCost;
            }
        } else if (_quality == 1) {
            for (uint8 i = 0; i < 20; ++i) {
                q1LevelUpCost[i].nftCost = _qCost[i].nftCost;
                q1LevelUpCost[i].pawCost = _qCost[i].pawCost;
            }
        } else if (_quality == 2) {
            for (uint8 i = 0; i < 20; ++i) {
                q2LevelUpCost[i].nftCost = _qCost[i].nftCost;
                q2LevelUpCost[i].pawCost = _qCost[i].pawCost;
            }
        } else if (_quality == 3) {
            for (uint8 i = 0; i < 20; ++i) {
                q3LevelUpCost[i].nftCost = _qCost[i].nftCost;
                q3LevelUpCost[i].pawCost = _qCost[i].pawCost;
            }
        } else {
            for (uint8 i = 0; i < 20; ++i) {
                q4LevelUpCost[i].nftCost = _qCost[i].nftCost;
                q4LevelUpCost[i].pawCost = _qCost[i].pawCost;
            }
        }
    }

    function setSyntheticCost(LevelUpCost memory _q0Cost, LevelUpCost memory _q1Cost) external onlyOwner {
        q0SyntheticCost = _q0Cost;
        q1SyntheticCost = _q1Cost;
    }

    function setMintHelper(address _woofMintHelper) external onlyOwner {
        require(_woofMintHelper != address(0));
        mintHelper = IWoofMintHelper(_woofMintHelper);
    }

    function setWoof(address _woof) external onlyOwner {
        require(_woof != address(0));
        woof = IWoof(_woof);
    }

    function setStealBuf(uint16[] memory _index, uint16[] memory _stealBuf) external onlyOwner {
        require(_index.length == 20);
        require(_stealBuf.length <= 10);
        for (uint16 i = 0; i < 20; ++i) {
            levelToStealIndex[i+1] = _index[i];
        }
        stealBuf = _stealBuf;
    }

    function setStrict(bool _strict) public onlyOwner {
        strict = _strict;
    }

    function clearMintCid2() public onlyOwner {
        for (uint8 i = 0; i < 2; ++i) {
            uint256 key = getKey(i, 0, 0);
            delete mintCid2[key];

            key = getKey(i, 1, 0);
            delete mintCid2[key];

            key = getKey(i, 0, 1);
            delete mintCid2[key];

            key = getKey(i, 1, 1);
            delete mintCid2[key];
        }
    }

    function mintCidLengthOf(uint8 _nftType) public view returns(uint256) {
        return mintCid[_nftType].length;
    }

    function mintCid2LengthOf(uint256 _key) public view returns(uint256) {
        return mintCid2[_key].length;
    }

    function getKey(uint8 _nftType, uint8 _race, uint8 _gender) public pure returns(uint256) {
        return _nftType * 100 + _race * 10 + _gender;
    }

    function getConfig(uint16 _cid) public override view returns (WoofWoofWestConfig memory) {
        return cidToConfig[_cid];
    }

    function getLevelConfig(uint8 _nftType, uint8 _level) public override view returns(WoofWoofWestLevelConfig memory) {
        return levelConfig[_nftType][_level-1];
    }

    function getLevelUpCost(uint8 _quality, uint8 _level) public override view returns(LevelUpCost memory) {
        if (_quality == 0) {
            return q0LevelUpCost[_level - 1];
        } else if (_quality == 1) {
            return q1LevelUpCost[_level - 1];
        } else if (_quality == 2) {
            return q2LevelUpCost[_level - 1];
        } else if (_quality == 3) {
            return q3LevelUpCost[_level - 1];
        } else {
            return q4LevelUpCost[_level - 1];
        }
    }

    function getQualityConfig(uint8 _quality) public override view returns(WoofWoofWestQualityConfig memory) {
        return qualityConfig[_quality];
    }

    function stealInfoOfBandit(uint16 _level) external override view returns (uint16 buf, uint16 index) {
        index = levelToStealIndex[_level];
        buf = stealBuf[index];
    }

    function stealBufOfBandit() external override view returns (uint16[] memory) {
        return stealBuf;
    }

    function randomWoofWoofWest(uint256[] memory _seeds) public override view returns (IWoof.WoofWoofWest memory) {
        require(_seeds.length >= 4, "1");
        (uint16 cid, uint8 quality) = randomCidAndQuality(_seeds); 
        return _randomWoofWoofWest(cid, quality, mintHelper.currentGeneration(), _seeds[3]);
    }

    function randomWoofWoofWest2(uint256[] memory _seeds, uint8 _quality) public override view returns (IWoof.WoofWoofWest memory) {
        require(_seeds.length >= 4, "1");
        (uint16 cid, uint8 quality) = randomCidAndQuality(_seeds); 
        quality = _quality;
        return _randomWoofWoofWest(cid, quality, mintHelper.currentGeneration(), _seeds[3]);
    }

    function randomWoofWoofWest(uint256[] memory _seeds, uint8 _nftType) public override view returns(IWoof.WoofWoofWest memory) {
        require(_seeds.length >= 4, "1");
        (uint16 cid, uint8 quality) = randomCidAndQuality(_seeds, _nftType); 
        return _randomWoofWoofWest(cid, quality, mintHelper.currentGeneration(), _seeds[3]);
    } 

    function randomWoofWoofWest(uint256[] memory _seeds, uint8 _nftType, uint8 _quality, uint8 _race, uint8 _gender) public override view returns(IWoof.WoofWoofWest memory) {
        require(_seeds.length >= 2, "1");
        uint256 key = getKey(_nftType, _race, _gender);
        uint256 index = _seeds[0] % mintCid2[key].length;
        uint16 cid = mintCid2[key][index];
        return _randomWoofWoofWest(cid, _quality, 2, _seeds[1]);
    }

    function levelUpWoofWoofWest(uint32 _tokenId, uint256 _seed) public override view returns(IWoof.WoofWoofWest memory w, LevelUpCost memory cost) {
        w = woof.getTokenTraits(_tokenId);
        IWoofConfig.WoofWoofWestQualityConfig memory _qualityConfig = getQualityConfig(w.quality);
        require(w.level + 1 <= _qualityConfig.maxLevelCap, "1");
        cost = getLevelUpCost(w.quality, w.level);
        w.level += 1;
        IWoofConfig.WoofWoofWestLevelConfig memory _levelConfig = getLevelConfig(w.nftType, w.level);
        w.attributes[1] = _levelConfig.stamina;
        w.attributes[3] = _randomPower(_seed, _levelConfig.maxDynamicPower[w.quality], _levelConfig.minDynamicPower[w.quality]);
    }

    function syntheticWoofWoofWest(uint32 _tokenId, uint256 _seed) public override view returns(IWoof.WoofWoofWest memory w, LevelUpCost memory cost) {
        w = woof.getTokenTraits(_tokenId);
        require(w.quality <= 1, "1");
        IWoofConfig.WoofWoofWestQualityConfig memory _qualityConfig = getQualityConfig(w.quality);
        require(w.level == _qualityConfig.maxLevelCap, "2");
        cost = (w.quality == 0) ? q0SyntheticCost : q1SyntheticCost;
        w.quality += 1;
        w.level += 1;
        _qualityConfig = getQualityConfig(w.quality);
        IWoofConfig.WoofWoofWestLevelConfig memory _levelConfig = getLevelConfig(w.nftType, w.level);
        w.attributes[1] = _levelConfig.stamina;
        w.attributes[3] = _randomPower(_seed, _levelConfig.maxDynamicPower[w.quality], _levelConfig.minDynamicPower[w.quality]);
    }

    function randomCidAndQuality(uint256[] memory _seeds) public view returns(uint16 cid, uint8 quality) {
        uint256 r = _seeds[0] % 1000;
        (uint256 totalMinted, uint256[3] memory mintedOfType, uint256[5] memory mintedOfQuality) = mintHelper.minted();
        uint16 probability = 0;
        uint8 nftType = 0;
        for (uint8 i = 0; i < 3; ++i) {
            probability += nftTypeProbability[i];
            if (r < probability) {
                nftType = i;
                break;
            }
        }
        if (strict && nftType > 0 && _mintProportion(totalMinted, mintedOfType[nftType]) >= nftTypeProbability[nftType]) {
            nftType = 0;
        }
        uint256 index = _seeds[1] % mintCid[nftType].length;
        cid = mintCid[nftType][index];

        quality = 0;
        probability = 0;
        r = _seeds[2] % 1000;
        for (uint8 i = 0; i < 5; ++i) {
            probability += qualityProbability[i];
            if (r < probability) {
                quality = i;
                break;
            }
        }
        if (strict && quality > 0 && _mintProportion(totalMinted, mintedOfQuality[quality]) >= qualityProbability[quality]) {
            quality = 0;
        }
    }

    function randomCidAndQuality(uint256[] memory _seeds, uint8 _nftType) public view returns(uint16 cid, uint8 quality) {
        uint256 index = _seeds[1] % mintCid[_nftType].length;
        cid = mintCid[_nftType][index];

        quality = 0;
        uint16 probability = 0;
        uint256 r = _seeds[2] % 1000;
        for (uint8 i = 0; i < 5; ++i) {
            probability += qualityProbability[i];
            if (r < probability) {
                quality = i;
                break;
            }
        }
        (uint256 totalMinted,,uint256[5] memory mintedOfQuality) = mintHelper.minted();
        if (strict && quality > 0 && _mintProportion(totalMinted, mintedOfQuality[quality]) >= qualityProbability[quality]) {
            quality = 0;
        }
    }

    function _mintProportion(uint256 _totalMinted, uint256 _minted) internal pure returns(uint256) {
        if (_totalMinted == 0) {
            return 0;
        }
        return _minted * 1000 / _totalMinted;
    }

    function _randomPower(uint256 _seed, uint32 _maxPower, uint32 _minPower) public pure returns (uint32) {
        uint256 r = _seed % (_maxPower - _minPower + 1);
        uint32 buf = uint32(r + _minPower);
        return buf;
    }

    function _randomWoofWoofWest(uint16 _cid, uint8 _quality, uint8 _gen, uint256 _seed) internal view returns(IWoof.WoofWoofWest memory) {
        WoofWoofWestConfig memory config = cidToConfig[_cid];
        require(config.cid > 0, "1");

        WoofWoofWestLevelConfig memory _levelConfig = getLevelConfig(config.nftType, 1);
        WoofWoofWestQualityConfig memory _qualityConfig = getQualityConfig(_quality);
        IWoof.WoofWoofWest memory w;
        w.generation = _gen;
        w.nftType = config.nftType;
        w.quality = _quality;
        w.level = 1;
        w.cid = config.cid;
        w.race = config.race;
        w.gender = config.gender;
        w.attributes[0] = _levelConfig.stamina;
        w.attributes[1] = w.attributes[0];
        w.attributes[2] = config.basicPower * _qualityConfig.basicPowerBuf / 100;
        w.attributes[3] = _randomPower(_seed, _levelConfig.maxDynamicPower[_quality], _levelConfig.minDynamicPower[_quality]);
        w.attributes[4] = _levelConfig.hp * _qualityConfig.battleBuf / 100;
        w.attributes[5] = _levelConfig.attack * _qualityConfig.battleBuf / 100;
        w.attributes[6] = _levelConfig.hitRate * _qualityConfig.battleBuf / 100;
        w.name = config.name;
        return w;
    }
}
