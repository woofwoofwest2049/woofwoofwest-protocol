// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./interfaces/IWoof.sol";
import "./library/SafeERC20.sol";
import "./library/SafeMath.sol";
import "./interfaces/ITraits.sol";
import "./interfaces/IUserDashboard.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IWanted {
    function updatePower(uint32 _tokenId, uint256 _miningPower, uint256 _beforeMiningPower) external;
}

interface IWoofMinePool {
    function updatePower(uint32 _tokenId, uint256 _miningPower, uint256 _beforeMiningPower) external;
}

interface IWoofEquipment {
    function getWearEqipmentsBattleAttributes(uint32 _woofId) external view returns(uint32 hp, uint32 attack, uint32 hitRate);
}

contract Woof is IWoof, ERC721EnumerableUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    event DividendU(uint256 _amount);
    event ClaimU(address indexed _user, uint256 _amount);
    event UpdateTraits(WoofWoofWest w);
    
    ITraits public traits;
    IWanted public wanted;
    IWoofMinePool public woofMinePool;
    address public uToken;

    mapping(uint256 => WoofWoofWest) public tokenTraits;
    
    uint256 public burned;
    mapping(uint256 => uint256[]) public tokenIdsOfEachType;
    mapping(address => bool) public authControllers;

    uint256 public totalMiningPower;
    uint256 public accPerMiningPower;
    uint256 public totalRewardU;
    uint256 public constant UNIT = 1e12;

    struct G0RewardInfo {
        uint256 pending;
        uint256 rewardPaid;
    }
    mapping(uint256 => G0RewardInfo) public g0RewardInfo;
    IWoofEquipment public woofEquipment;
    IUserDashboard public userDashboard;
 
    function initialize(
        address _traits,
        address _config,
        address _u
    ) external initializer {
        require(_traits != address(0));
        require(_config != address(0));

        __ERC721_init("Woof Woof West", "WWW");
        __ERC721Enumerable_init();
        __Ownable_init();

        traits = ITraits(_traits);
        uToken = _u;
    }

    function setAuthControllers(address _controller, bool _enable) external onlyOwner {
        authControllers[_controller] = _enable;
    }

    function setWanted(address _wanted) external onlyOwner {
        require(_wanted != address(0));
        wanted = IWanted(_wanted);
    }

    function setWoofMinePool(address _pool) external onlyOwner {
        require(_pool != address(0));
        woofMinePool = IWoofMinePool(_pool);
    }
    
    function setWoofEquipment(address _woofEquipment) external onlyOwner {
        woofEquipment = IWoofEquipment(_woofEquipment);
    }

    function setUserDashboard(address _userDashboard) external onlyOwner {
        require(_userDashboard != address(0));
        userDashboard = IUserDashboard(_userDashboard);
    }

    function setUToken(address _token) external onlyOwner {
        require(_token != address(0));
        uToken = _token;
    }

    function mint(address _user, WoofWoofWest memory _w) external override {
        require(authControllers[_msgSender()], "no auth");
        _mint(_user, _w);
    }

    function batchMint(address _user, WoofWoofWest[10] memory _w) external override {
        require(authControllers[_msgSender()], "no auth");
        for (uint256 i = 0; i < 10; ++i) {
            _mint(_user, _w[i]);
        }
    }

    function updateTokenTraits(WoofWoofWest memory _w) external override {
        require(authControllers[_msgSender()], "no auth");
        uint32 beforeMiningPower = miningPowerOf(tokenTraits[_w.tokenId]);
        uint32 power = miningPowerOf(_w);
        if (beforeMiningPower != power) {
            _updatePower(_w, power, beforeMiningPower);
        }
        tokenTraits[_w.tokenId] = _w;
        emit UpdateTraits(_w);
    }

    function updateStamina(uint256 _tokenId, uint32 _stamina) external override {
        require(authControllers[_msgSender()], "no auth");
        tokenTraits[_tokenId].attributes[0] = _stamina;
        emit UpdateTraits(tokenTraits[_tokenId]);
    }

    function updateName(uint256 _tokenId, string memory _name) external override {
        require(authControllers[_msgSender()], "no auth");
        tokenTraits[_tokenId].name = _name;
        emit UpdateTraits(tokenTraits[_tokenId]);
    }

    function burn(uint256 _tokenId) external override {
        require(authControllers[_msgSender()], "no auth");
        _burn(_tokenId);
        burned += 1;
    }

    function addSlavePower(uint32 _tokenId, uint32 _power) external override {
        require(authControllers[_msgSender()], "no auth");
        WoofWoofWest memory w = tokenTraits[_tokenId];
        uint32 beforeMiningPower = miningPowerOf(w);
        uint32 power = beforeMiningPower + _power;
        _updatePower(w, power, beforeMiningPower);
        tokenTraits[_tokenId].slavesPower += _power;
    }

    function delSlavePower(uint32 _tokenId, uint32 _power) external override {
        require(authControllers[_msgSender()], "no auth");
        WoofWoofWest memory w = tokenTraits[_tokenId];
        uint32 beforeMiningPower = miningPowerOf(w);
        if (tokenTraits[_tokenId].slavesPower < _power) {
            tokenTraits[_tokenId].slavesPower = 0;
        } else {
            tokenTraits[_tokenId].slavesPower -= _power;
        }
        uint32 power = miningPowerOf(_tokenId);
        _updatePower(w, power, beforeMiningPower);
    }

    function getTokenTraits(uint256 _tokenId) external view override returns (WoofWoofWest memory) {
        return tokenTraits[_tokenId];
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        require(_exists(_tokenId));
        return traits.tokenURI(_tokenId);
    }

    function balanceOfType(uint256 _type) external override view returns(uint256) {
        return tokenIdsOfEachType[_type].length;
    }

    function tokenOfTypeByIndex(uint256 _type, uint256 _index) external override view returns(uint256) {
        return tokenIdsOfEachType[_type][_index];
    }

    function dividendU(uint256 _amount) external override {
        require(authControllers[_msgSender()], "no auth");
        IERC20(uToken).safeTransferFrom(_msgSender(), address(this), _amount);
        accPerMiningPower = accPerMiningPower.add(_amount.mul(UNIT).div(totalMiningPower));
        totalRewardU = totalRewardU.add(_amount);
        emit DividendU(_amount);
    }

    function claimU(uint256 _tokenId) external override {
        require(ownerOf(_tokenId) == _msgSender(), "Not owner");
        WoofWoofWest memory w = tokenTraits[_tokenId];
        require(w.generation == 0, "Not G0");
        uint256 miningPower = miningPowerOf(w);
        G0RewardInfo memory rewardInfo = g0RewardInfo[_tokenId];
        uint256 pending =  miningPower.mul(accPerMiningPower).div(UNIT).sub(rewardInfo.rewardPaid);
        pending = rewardInfo.pending.add(pending);
        rewardInfo.pending = 0;
        rewardInfo.rewardPaid = miningPower.mul(accPerMiningPower).div(UNIT);
        g0RewardInfo[_tokenId] = rewardInfo;
        IERC20(uToken).safeTransfer(_msgSender(), pending);
        userDashboard.rewardFromScene(_msgSender(), 6, 0, 0, pending);
        emit ClaimU(_msgSender(), pending);
    }

    function pendingU(uint256 _tokenId) external view override returns(uint256) {
        WoofWoofWest memory w = tokenTraits[_tokenId];
        if (w.generation > 0) {
            return 0;
        }

        uint256 miningPower = miningPowerOf(w);
        G0RewardInfo memory rewardInfo = g0RewardInfo[_tokenId];
        uint256 pending =  miningPower.mul(accPerMiningPower).div(UNIT).sub(rewardInfo.rewardPaid);
        pending = rewardInfo.pending.add(pending);
        return pending;
    }

    function miningPowerOf(WoofWoofWest memory _w) public pure override returns(uint32) {
        return _w.attributes[2] + _w.attributes[3] + _w.slavesPower;
    }

    function miningPowerOf(uint256 _tokenId) public view override returns(uint32) {
        WoofWoofWest memory w = tokenTraits[_tokenId];
        return miningPowerOf(w);
    }

    function ownerOf2(uint256 _tokenId) public view override returns(address) {
        if (_exists(_tokenId)) {
            return ownerOf(_tokenId);
        }
        return address(0);
    }

    function getBattleAttributes(uint256 _tokenId) public view override returns(uint32[4] memory attr /*0: hp, 1: attack, 2: hitRate, 3: equipmentHitRate*/) {
        WoofWoofWest memory w = tokenTraits[_tokenId];
        attr[0] = w.attributes[4];
        attr[1] = w.attributes[5];
        attr[2] = w.attributes[6];
        attr[3] = 0;

        (uint32 hp, uint32 attack, uint32 hitRate) = woofEquipment.getWearEqipmentsBattleAttributes(uint32(_tokenId));
        attr[0] += hp;
        attr[1] += attack;
        attr[3] = hitRate;
    }

    function _mint(address _user, WoofWoofWest memory _w) internal {
        if (_w.generation == 0) {
            uint256 miningPower = miningPowerOf(_w);
            G0RewardInfo memory rewardInfo = g0RewardInfo[_w.tokenId];
            rewardInfo.rewardPaid = miningPower.mul(accPerMiningPower).div(UNIT);
            g0RewardInfo[_w.tokenId] = rewardInfo;
            totalMiningPower = totalMiningPower.add(miningPower);
        }
        tokenTraits[_w.tokenId] = _w;
        tokenIdsOfEachType[_w.nftType].push(_w.tokenId);
        _safeMint(_user, _w.tokenId);
    }

    function _updatePower(WoofWoofWest memory _w, uint32 _power, uint32 _beforeMiningPower) internal {
        if (_w.nftType == 0) {
            woofMinePool.updatePower(_w.tokenId, _power, _beforeMiningPower);
        }
        else if (_w.nftType == 2) {
            wanted.updatePower(_w.tokenId, _power, _beforeMiningPower);
        }

        if (_w.generation == 0) {
            _updateG0Power(_w.tokenId, _power, _beforeMiningPower);
        }
    }

    function _updateG0Power(uint32 _tokenId, uint256 _miningPower, uint256 _beforeMiningPower) internal {
        G0RewardInfo memory rewardInfo = g0RewardInfo[_tokenId];
        uint256 pending = _beforeMiningPower.mul(accPerMiningPower).div(UNIT).sub(rewardInfo.rewardPaid);
        rewardInfo.pending = rewardInfo.pending.add(pending);
        rewardInfo.rewardPaid = _miningPower.mul(accPerMiningPower).div(UNIT);
        g0RewardInfo[_tokenId] = rewardInfo;
        totalMiningPower = totalMiningPower.add(_miningPower).sub(_beforeMiningPower);
    }
}