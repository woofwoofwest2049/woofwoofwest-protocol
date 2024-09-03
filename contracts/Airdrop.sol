// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./library/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Airdrop is OwnableUpgradeable {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    address[] public tokens;
    uint256[] public airdropAmount;
    mapping(address => bool) public claimedAccount;

    function initialize() external initializer {
        __Ownable_init();
    }

    function setTokens(address[] memory _tokens, uint256[] memory _airdropAmount) external onlyOwner {
        tokens = _tokens;
        for (uint256 i = 0; i < _airdropAmount.length; ++i) {
            _airdropAmount[i] = _airdropAmount[i] * 1e18;
        }
        airdropAmount = _airdropAmount;
    }

    function airdrop(address[] memory _uesrs) external onlyOwner {
        address[] memory _tokens = tokens;
        uint256[] memory _airdropAmount = airdropAmount;
        for (uint256 i = 0; i < _uesrs.length; ++i) {
            for (uint256 j = 0; j < _tokens.length; ++j) {
                IERC20(_tokens[j]).safeTransfer(_uesrs[i], _airdropAmount[j]);
            }
        }
    }

    function airdropBNB(address[] memory _uesrs, uint256 _amount) external onlyOwner {
        for (uint256 i = 0; i < _uesrs.length; ++i) {
            SafeERC20.safeTransferETH(_uesrs[i], _amount);
        }
    }

    function balanceOf(address _token) public view returns(uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    function claim(address _account) external {
        require(claimedAccount[_account] == false, "Claimed");
        claimedAccount[_account] = true;
        address[] memory _tokens = tokens;
        uint256[] memory _airdropAmount = airdropAmount;
        for (uint256 j = 0; j < _tokens.length; ++j) {
            IERC20(_tokens[j]).safeTransfer(_account, _airdropAmount[j]);
        }
    }
    
    function setClaimed(address[] memory _uesrs, bool _claimed) external onlyOwner {
        for (uint256 i = 0; i < _uesrs.length; ++i) {
            claimedAccount[_uesrs[i]] = _claimed;
        }
    }

    receive() external payable {}
}