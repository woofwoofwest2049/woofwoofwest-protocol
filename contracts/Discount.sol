// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Discount is OwnableUpgradeable {

    mapping (address=>uint256) public userDiscount;
    mapping (address=>bool) private _freeUser;
    address public mintHelper;

    function initialize(
    ) external initializer {
        __Ownable_init();
    }

    function setUserDiscount(address[] memory _users, uint256[] memory _off) external onlyOwner {
        require(_users.length == _off.length);
        for (uint256 i = 0; i < _users.length; ++i) {
            userDiscount[_users[i]] = _off[i];
        }
    }

    function setMintHelper(address _minHelper) public onlyOwner {
        require(_minHelper != address(0));
        mintHelper = _minHelper;
    }

    function setFreeUser(address[] memory _users, bool _free) external onlyOwner {
        for (uint256 i = 0; i < _users.length; ++i) {
            _freeUser[_users[i]] = _free;
        }
    } 

    function discount(address _user) external returns (uint256) {
        uint256 off = userDiscount[_user];
        if (off == 0) {
            return 100;
        }
        userDiscount[_user] = 0;
        return off;
    }

    function freeUser(address _user) external returns(bool) {
        require(msg.sender == mintHelper, "no auth");
        bool free = _freeUser[_user];
        if (free) {
            _freeUser[_user] = false;
        }
        return free;
    }

    function isFreeUser(address _user) public view returns(bool) {
        return _freeUser[_user];
    }

    function discountOff(address _user) external view returns (uint256) {
        uint256 off = userDiscount[_user];
        if (off == 0) {
            return 100;
        }
        return off;
    }
}