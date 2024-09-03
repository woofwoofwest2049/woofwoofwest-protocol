// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract RandomSeeds is OwnableUpgradeable {
    uint256[] public randomseeds;

    function initialize() external initializer {
        __Ownable_init();
    }

    function setRandomSeeds(uint256[] memory _seeds) public onlyOwner {
        for (uint256 i = 0; i < _seeds.length; ++i) {
            for (uint256 j = 0; j < 20; ++j) {
                uint256 seed = uint256(keccak256(abi.encode(_seeds[i], j)));
                randomseeds.push(seed);
            }
        }
    }

    function setRandomSeed(uint256 _seed) public onlyOwner {
        for (uint256 j = 0; j < 200; ++j) {
            uint256 seed = uint256(keccak256(abi.encode(_seed, j)));
            randomseeds.push(seed);
        }
    }

    function randomseedsLength() public view returns (uint256) {
        return randomseeds.length;
    }

    function getRandomSeeds(uint256 _index, uint256 _len) public view returns(uint256[] memory seeds, uint256 len) {
        seeds = new uint256[](_len);
        len = 0;

        uint256 bal = randomseeds.length;
        if (bal == 0 || _index >= bal) {
            return (seeds, len);
        }

        for (uint8 i = 0; i < _len; ++i) {
            seeds[i] = randomseeds[_index];
            ++_index;
            ++len;
            if (_index >= bal) {
                return (seeds, len);
            }
        }
    }

    function randomseed(uint256 _seed) public view returns (uint256) {
        uint256 random = randomseeds[_seed % randomseeds.length];
        random = uint256(keccak256(abi.encodePacked(
            random,
            block.timestamp + block.number + _seed
        )));
        return random;
    }

    function multiRandomSeeds(uint256 _seed, uint256 _count) public view returns (uint256[] memory) {
        uint256[] memory seeds = new uint256[](_count);
        for (uint256 i = 0; i < _count; ++i) {
            uint256 tempSeed = _seed + i;
            uint256 random = randomseeds[tempSeed % randomseeds.length];
            seeds[i] = uint256(keccak256(abi.encodePacked(
                random,
                block.timestamp + block.number + tempSeed
            )));
        }
        return seeds;
    }
}