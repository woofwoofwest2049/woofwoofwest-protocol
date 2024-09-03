// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./interfaces/IWoofEnumerable.sol";
import "./interfaces/IPVP.sol";
import "./library/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IRandomseeds {
    function randomseed(uint256 _seed) external view returns (uint256);
    function multiRandomSeeds(uint256 _seed, uint256 _count) external view returns (uint256[] memory);
}

contract PVPLogic is IPVPLogic, OwnableUpgradeable {
    using SafeMath for uint256;

    IWoofEnumerable public woof;
    IRandomseeds public randomseeds;
    uint32 public maxHitRate;

    function initialize(address _woof, address _randomseeds) external initializer {
        require(_woof != address(0));
        require(_randomseeds != address(0));

        __Ownable_init();

        woof = IWoofEnumerable(_woof);
        randomseeds = IRandomseeds(_randomseeds);
        maxHitRate = 95;
    }

    function setMaxHitRate(uint32 _maxHitRate) external onlyOwner {
        maxHitRate = _maxHitRate;
    }

    function pvp(uint32 _attackTokenId, uint32 _defensiveTokenId) external override view returns(IPVP.Report memory) {
        uint32[4] memory _attackAttr = woof.getBattleAttributes(_attackTokenId);
        uint32[4] memory _defensiveAttr = woof.getBattleAttributes(_defensiveTokenId);
        uint256[] memory seeds = randomseeds.multiRandomSeeds(block.timestamp + _attackTokenId + _defensiveTokenId, 10);

        IPVP.Report memory r;
        r.pvpTime = uint32(block.timestamp);
        r.attackId = _attackTokenId;
        r.defensiveId = _defensiveTokenId;
        for (uint8 i = 0; i < 5; ++i) {
            r.attackFormation[i] = uint8(seeds[i] % 3);
        }
        for (uint8 i = 0; i < 5; ++i) {
            r.defensiveFormation[i] = uint8(seeds[i+5] % 3);
        }
        /*0: hp, 1: attack, 2: hitRate, 3: equipmentHitRate*/
        uint32 attackHP = _attackAttr[0];
        uint32 defensiveHP = _defensiveAttr[0];
        uint32 attackHitRate = _attackAttr[2] * 100 / (_attackAttr[2] + _defensiveAttr[2]) + _attackAttr[3];
        if (attackHitRate >= maxHitRate) {
            attackHitRate = maxHitRate;
        }

        uint32 defensiveHitRate = _defensiveAttr[2] * 100 / (_attackAttr[2] + _defensiveAttr[2]) + _defensiveAttr[3];
        if (defensiveHitRate >= maxHitRate) {
            defensiveHitRate = maxHitRate;
        }

        uint8 index = 0;
        for (uint8 i = 0; i < 5; ++i) {
            if (r.attackFormation[i] == r.defensiveFormation[i]) {
                //attack <-> defensive
                if (seeds[index] % 100 <= attackHitRate) {
                    r.attackHit[i] = _attackAttr[1];
                    if (_attackAttr[1] >= defensiveHP) {
                        defensiveHP = 0;
                    } else {
                        defensiveHP -= _attackAttr[1];
                    }
                }
                if (seeds[index+1] % 100 <= defensiveHitRate) {
                    r.defensiveHit[i] = _defensiveAttr[1];
                    if (_defensiveAttr[1] >= attackHP) {
                        attackHP = 0;
                    } else {
                        attackHP -= _defensiveAttr[1];
                    }
                }
                index += 2;
            } else {
                if (r.attackFormation[i] == 0) {
                    if (r.defensiveFormation[i] == 1) {
                        //attack -> defensive
                        if (seeds[index] % 100 <= attackHitRate) {
                            r.attackHit[i] = _attackAttr[1];
                            if (_attackAttr[1] >= defensiveHP) {
                                defensiveHP = 0;
                             } else {
                                defensiveHP -= _attackAttr[1];
                            }
                        }
                    } else {
                        //defensive -> attack
                        if (seeds[index] % 100 <= defensiveHitRate) {
                            r.defensiveHit[i] = _defensiveAttr[1];
                            if (_defensiveAttr[1] >= attackHP) {
                                attackHP = 0;
                            } else {
                                attackHP -= _defensiveAttr[1];
                            }
                        }
                    }
                } else if (r.attackFormation[i] == 1) {
                    if (r.defensiveFormation[i] == 0) {
                        //defensive -> attack
                        if (seeds[index] % 100 <= defensiveHitRate) {
                            r.defensiveHit[i] = _defensiveAttr[1];
                            if (_defensiveAttr[1] >= attackHP) {
                                attackHP = 0;
                            } else {
                                attackHP -= _defensiveAttr[1];
                            }
                        }
                    } else {
                        //attack -> defensive
                        if (seeds[index] % 100 <= attackHitRate) {
                            r.attackHit[i] = _attackAttr[1];
                            if (_attackAttr[1] >= defensiveHP) {
                                defensiveHP = 0;
                             } else {
                                defensiveHP -= _attackAttr[1];
                            }
                        }
                    }
                } else {
                    if (r.defensiveFormation[i] == 0) {
                        //attack -> defensive
                        if (seeds[index] % 100 <= attackHitRate) {
                            r.attackHit[i] = _attackAttr[1];
                            if (_attackAttr[1] >= defensiveHP) {
                                defensiveHP = 0;
                             } else {
                                defensiveHP -= _attackAttr[1];
                            }
                        }
                    } else {
                        //defensive -> attack
                        if (seeds[index] % 100 <= defensiveHitRate) {
                            r.defensiveHit[i] = _defensiveAttr[1];
                            if (_defensiveAttr[1] >= attackHP) {
                                attackHP = 0;
                            } else {
                                attackHP -= _defensiveAttr[1];
                            }
                        }
                    }
                }
                index += 1;
            }
            r.attackHP[i] = attackHP;
            r.defensiveHP[i] = defensiveHP;
            if (attackHP == 0 || defensiveHP == 0) {
                break;
            }
        }

        r.attackWin = (attackHP > defensiveHP) ? true : false;
        return r;
    }
}
