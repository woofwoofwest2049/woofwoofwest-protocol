// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./library/SafeERC20.sol";
import "./library/SafeMath.sol";
import "./interfaces/IWoofEnumerable.sol";
import "./interfaces/IEquipment.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract WoofEquipment is  OwnableUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    event Wear(address indexed user, uint32 indexed woofId, uint32[3] equipmentIds);
    event UnWear(address indexed user, uint32 indexed woofId, uint32[3] equipmentPos);

    IWoofEnumerable public woof;
    IEquipmentEnumerable public equipment;

    mapping(uint32 => uint32[3]) public woofEquipments;

    function initialize(
        address _woof,
        address _equipment
    ) external initializer {
        require(_woof != address(0));
        require(_equipment != address(0));

        __Ownable_init();
        __Pausable_init();

        woof = IWoofEnumerable(_woof);
        equipment = IEquipmentEnumerable(_equipment);
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function wear(uint32 _woofId, uint32[3] memory _equipmentIds) external whenNotPaused {
        require(tx.origin == _msgSender(), "Not EOA");
        require(woof.ownerOf(_woofId) == _msgSender(), "Not owner");

        for (uint8 i = 0; i < 3; ++i) {
            uint32 equipmentId = _equipmentIds[i];
            if (equipmentId == 0) {
                continue;
            }
            require(equipment.ownerOf(equipmentId) == _msgSender(), "Not owner");
            IEquipment.sEquipment memory s = equipment.getTokenTraits(equipmentId);
            require(s.eType == i, "Invalid equipment");
            equipment.transferFrom(_msgSender(), address(this), equipmentId);
            if (woofEquipments[_woofId][i] > 0) {
                equipment.transferFrom(address(this), _msgSender(), woofEquipments[_woofId][i]);
            }
            woofEquipments[_woofId][i] = equipmentId;
        }
        emit Wear(_msgSender(), _woofId, _equipmentIds);
    }   

    function unwear(uint32 _woofId, uint32[3] memory _equipmentPos) external {
        require(tx.origin == _msgSender(), "Not EOA");
        require(woof.ownerOf(_woofId) == _msgSender(), "Not owner");
        for (uint8 i = 0; i < 3; ++i) {
            if (_equipmentPos[i] == 0) {
                continue;
            }
            uint32 equipmentId = woofEquipments[_woofId][i];
            require(equipmentId > 0, "Not exist equipment");
            equipment.transferFrom(address(this), _msgSender(), equipmentId);
            woofEquipments[_woofId][i] = 0;
        }
        emit UnWear(_msgSender(), _woofId, _equipmentPos);
    }

    function getWearEquipments(uint32 _woofId) public view returns(IEquipment.sEquipment[3] memory) {
        IEquipment.sEquipment[3] memory arrEquipments;
        for (uint8 i = 0; i < 3; ++i) {
            uint32 eid = woofEquipments[_woofId][i];
            if (eid > 0) {
                arrEquipments[i] = equipment.getTokenTraits(eid);
            }
        }
        return arrEquipments;
    }

    function isWearEquipments(uint32 _woofId) public view returns(bool) {
        for (uint8 i = 0; i < 3; ++i) {
            if (woofEquipments[_woofId][i] > 0) {
                return true;
            }
        }
        return false;
    }

    function getWearEqipmentsBattleAttributes(uint32 _woofId) public view returns(uint32 hp, uint32 attack, uint32 hitRate) {
        uint32[3] memory equipmentIds = woofEquipments[_woofId];
        hp = 0;
        attack = 0;
        hitRate = 0;
        for (uint8 i = 0; i < 3; ++i) {
            if (equipmentIds[i] == 0) {
                continue;
            }
            IEquipment.sEquipment memory s = equipment.getTokenTraits(equipmentIds[i]);
            hp += s.hp;
            attack += s.attack;
            hitRate += s.hitRate;
        }
    }
}