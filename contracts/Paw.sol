// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;
import "./library/SafeMath.sol";
import "./helpers/ERC20.sol";
import "./helpers/Ownable.sol";

contract Paw is ERC20, Ownable {

    using SafeMath for uint256;

    // a mapping from an address to whether or not it can mint
    uint256 public totalBurnedAmount;
    address public approveHelper;
    mapping (address=>bool) internal _vaultControllers;
  
    constructor() ERC20("WoofWoofWest Gold", "Paw") {
         _vaultControllers[msg.sender] = true;
    }

    function initApproveHelper(address _helper) external onlyOwner() {
        require(_helper != address(0));
        require(approveHelper == address(0));
        approveHelper = _helper;
    }

    function setVault(address _vault, bool _enable) external onlyOwner() returns ( bool ) {
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

    function mint(address to, uint256 amount) onlyVault external {
        _mint(to, amount);
    }

    function burn(uint256 amount_) public virtual {
        _burn(msg.sender, amount_);
        totalBurnedAmount += amount_;
    }
    
    function burnFrom(address account_, uint256 amount_) public virtual {
        _burnFrom(account_, amount_);
    }

    function _burnFrom(address account_, uint256 amount_) private {
        uint256 decreasedAllowance_ =
            allowance(account_, msg.sender).sub(
                amount_,
                "ERC20: burn amount exceeds allowance"
            );

        _approve(account_, msg.sender, decreasedAllowance_);
        _burn(account_, amount_);
        totalBurnedAmount += amount_;
    }

    function approveFromHelper(address owner_, address spender_, uint256 amount_) public {
        require(msg.sender == approveHelper, "no auth");
        require(tx.origin == owner_, "invalid owner");
        _approve(owner_, spender_, amount_);
    }
}