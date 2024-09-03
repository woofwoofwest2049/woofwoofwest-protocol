// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./interfaces/IWoofMine.sol";
import "./library/SafeERC20.sol";
import "./library/SafeMath.sol";
import "./interfaces/ITraits.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IWoofMinePool {
    function updateTokenTraits(uint32 _tokenId) external;
}

contract WoofMine is IWoofMine, ERC721EnumerableUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    event UpdateTraits(WoofWoofMine w);

    ITraits public traits;
    mapping(uint32 => WoofWoofMine) public tokenTraits;
    IWoofMinePool public woofMinePool;
    mapping(address => bool) public authControllers;

    function initialize(
        address _traits
    ) external initializer {
        require(_traits != address(0));

        __ERC721_init("Woof Woof West Mine", "WWM");
        __ERC721Enumerable_init();
        __Ownable_init();

        traits = ITraits(_traits);
    }

    function setAuthControllers(address _controller, bool _enable) external onlyOwner {
        authControllers[_controller] = _enable;
    }

    function setWoofMinePool(address _minePool) external onlyOwner {
        require(_minePool != address(0));
        woofMinePool = IWoofMinePool(_minePool);
    }

    function mint(address _user, WoofWoofMine memory _w) external override {
        require(authControllers[_msgSender()], "no auth");
        tokenTraits[_w.tokenId] = _w;
        _safeMint(_user, _w.tokenId);
    }

    function updateTokenTraits(WoofWoofMine memory _w) external override {
        require(authControllers[_msgSender()], "no auth");
        tokenTraits[_w.tokenId] = _w;
        emit UpdateTraits(_w);
    }

    function getTokenTraits(uint256 _tokenId) external view override returns (WoofWoofMine memory) {
        return tokenTraits[uint32(_tokenId)];
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        require(_exists(_tokenId));
        return traits.tokenURI(_tokenId);
    }
}