// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./library/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

interface IGem {
     function mint(address account_, uint256 amount_) external;
     function MAX_SUPPLY() external view returns(uint256);
}

contract GemMintHelper is OwnableUpgradeable, PausableUpgradeable {
    IGem public gem;
    mapping (address=>bool) internal _vaultControllers;

    uint256[4] public reservedShares; //0: private 14%, 1: team 10%, 2: marketing 10%, 3: foundation 10%
    uint256[4] public accMintReservedShares;
    uint256 public gameMintMaxAmounts;
    uint256 public accGameMintAmounts;

    function initialize(
        address _gem
    ) external initializer {
        require(_gem != address(0));

        __Ownable_init();
        __Pausable_init();

        gem = IGem(_gem);
        _vaultControllers[msg.sender] = true;
        reservedShares = [14, 10, 10, 10];
        accMintReservedShares = [0,0,0,0];
        uint256 maxAmount = gem.MAX_SUPPLY();
        gameMintMaxAmounts = maxAmount * 56 / 100;
        accGameMintAmounts = 0;
    }

    function reservedMint(address _account, uint8 _shares, uint8 _type) external onlyOwner {
        require(_type < 4);
        require(accMintReservedShares[_type] + _shares <= 100);
        accMintReservedShares[_type] += _shares;
        uint256 maxAmount = gem.MAX_SUPPLY();
        uint256 amount = maxAmount * reservedShares[_type] * _shares / 10000;
        gem.mint(_account, amount);

    }

    function setVault(address _vault, bool _enable) external onlyOwner returns ( bool ) {
        _vaultControllers[_vault] = _enable;
        return true;
    }

    function vault(address _vault) public view returns ( bool ) {
        return _vaultControllers[_vault];
    }

    modifier onlyVault() {
        require( _vaultControllers[msg.sender] == true, "VaultOwned: caller is not the Vault" );
        _;
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function mint(address _account, uint256 _amount) external onlyVault whenNotPaused {
        if (accGameMintAmounts + _amount > gameMintMaxAmounts) {
            if (IERC20(address(gem)).balanceOf(address(this)) >= _amount) {
                IERC20(address(gem)).transfer(_account, _amount);
                return;
            } 

            _amount = gameMintMaxAmounts - accGameMintAmounts;
            if (_amount == 0) {
                return;
            }
        }

        gem.mint(_account, _amount);
        accGameMintAmounts += _amount;
    }
}