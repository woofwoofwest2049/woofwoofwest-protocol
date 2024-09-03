// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./library/SafeMath.sol";
import "./helpers/ERC20.sol";
import "./helpers/Ownable.sol";

contract Gem is ERC20, Ownable {

    using SafeMath for uint256;
    uint256 public constant MAX_SUPPLY = 100000000 * 10**18;
    uint256 public totalBurnedAmount;
    address public approveHelper;
    address public mintHelper;  

    constructor() ERC20("WoofWoofWest Gem", "Gem") {
    }

    function initApproveHelper(address _helper) external onlyOwner() {
        require(_helper != address(0));
        require(approveHelper == address(0));
        approveHelper = _helper;
    }

    function initMintHelper(address _helper) external onlyOwner() {
        require(_helper != address(0));
        require(mintHelper == address(0));
        mintHelper = _helper;
    }

    function mint(address account_, uint256 amount_) external {
        require(msg.sender == mintHelper, "no auth");
        uint256 totalSupply_ = totalSupply();
        if (amount_ + totalSupply_ > MAX_SUPPLY) {
            amount_ = MAX_SUPPLY - totalSupply_;
        }
        _mint(account_, amount_);
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