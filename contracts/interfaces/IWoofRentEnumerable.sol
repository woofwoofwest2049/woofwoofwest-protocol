// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;
import "./IWoofEnumerable.sol";

interface IWoofRentEnumerable is IWoofEnumerable {
    function balanceOfRent(address _renter) external view returns(uint256);
    function tokenOfRenterByIndex(address _renter, uint256 _index) external view returns(uint256);
}