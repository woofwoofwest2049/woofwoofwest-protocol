// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./library/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IERC20Approve {
    function approveFromHelper(address owner_, address spender_, uint256 amount_) external;
}

contract ApproveHelper is OwnableUpgradeable {
    using SafeERC20 for IERC20;

    address public gem;
    address public paw;

    function initialize(
        address _gem,
        address _paw
    ) external initializer {
        require(_gem != address(0));
        require(_paw != address(0));

        __Ownable_init();

        gem = _gem;
        paw = _paw;
    }

    function approve(address spender) external {
        require(tx.origin == _msgSender(), "Not EOA");
        IERC20Approve(gem).approveFromHelper(_msgSender(), spender, type(uint256).max);
        IERC20Approve(paw).approveFromHelper(_msgSender(), spender, type(uint256).max);
    }
}

