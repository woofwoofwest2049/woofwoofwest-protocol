// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./interfaces/IWoofEnumerable.sol";
import "./interfaces/IPVPConfig.sol";
import "./interfaces/IPVP.sol";
import "./interfaces/IUserDashboard.sol";
import "./library/SafeMath.sol";
import "./library/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

interface IPaw {
    function mint(address to, uint256 amount) external;
}

interface IGemMintHelper {
    function mint(address _account, uint256 _amount) external;
    function gem() external view returns(address);
}

interface ITreasury {
    function deposit(address _token, uint256 _amount) external;
}

interface IVestingPool {
    function balanceOf(address _user) external view returns(uint256);
    function transferFrom(address _from, address _to, uint256 _amount) external;
}

contract PVP is IPVP, OwnableUpgradeable, PausableUpgradeable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event PVPResult(address indexed sender, Report report);
    event Release(address indexed sender, uint32 _slaveOwner, uint32 _slave);
    event Reedem(address indexed sender, uint32 _slave, uint32 _slaveOwner, uint256 _tax);

    IWoofEnumerable public woof;
    address public paw;
    IVestingPool public pawVestingPool;
    IGemMintHelper public gemMintHelper;
    ITreasury public treasury;
    IPVPConfig public config;

    mapping (uint32=>PVPInfo) public pvpInfo;

    Report[] public reports;
    mapping (address=>uint32[]) public usersPVPReports;

    mapping(address => bool) public authControllers;
    IPVPLogic public pvpLogic;
    IUserDashboard public userDashboard;

    function initialize(
        address _woof, 
        address _paw,
        address _pawVestingPool,
        address _gemMintHelper,
        address _treasury,
        address _config,
        address _pvpLogic
    ) external initializer {
        require(_woof != address(0));
        require(_paw != address(0));
        require(_pawVestingPool != address(0));
        require(_gemMintHelper != address(0));
        require(_treasury != address(0));
        require(_config != address(0));
        require(_pvpLogic != address(0));

        __Ownable_init();
        __Pausable_init();

        woof = IWoofEnumerable(_woof);
        paw = _paw;
        pawVestingPool = IVestingPool(_pawVestingPool);
        gemMintHelper = IGemMintHelper(_gemMintHelper);
        treasury = ITreasury(_treasury);
        config = IPVPConfig(_config);
        pvpLogic = IPVPLogic(_pvpLogic);

        _safeApprove(_paw, _treasury);
    }

    function setAuthControllers(address _controller, bool _enable) external onlyOwner {
        authControllers[_controller] = _enable;
    }

    function setUserDashboard(address _userDashboard) external onlyOwner {
        require(_userDashboard != address(0));
        userDashboard = IUserDashboard(_userDashboard);
    }

    function setPawVestingPool(address _pool) external onlyOwner {
        pawVestingPool = IVestingPool(_pool);
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function pvp(uint32 _attackTokenId, uint32 _defensiveTokenId) external whenNotPaused {
        require(tx.origin == _msgSender(), "1");
        require(_attackTokenId != _defensiveTokenId, "2");
        require(woof.ownerOf(_attackTokenId) == _msgSender(), "3");
        require(woof.ownerOf(_defensiveTokenId) != _msgSender(), "4");

        IWoof.WoofWoofWest memory w = woof.getTokenTraits(_attackTokenId);        
        IPVPConfig.sPVPConfig memory sConfig = config.getPVPConfig(w.level);
        PVPInfo memory attackInfo = pvpInfo[_attackTokenId];
        require(block.timestamp > attackInfo.lastBattleTimestamp + sConfig.countdown, "5");
        pvpInfo[_attackTokenId].lastBattleTimestamp = uint32(block.timestamp);

        PVPInfo memory defensiveInfo = pvpInfo[_defensiveTokenId];
        require(block.timestamp > defensiveInfo.reedemTimestamp + config.getProtectionPeriod());
        require(defensiveInfo.slaveOwner != _attackTokenId, "6");
        if (defensiveInfo.slaveOwner > 0) {
            require(block.timestamp > defensiveInfo.slaveProtectEndTime, "7");
        }

        if (sConfig.staminaCost > 0) {
            require(w.attributes[0] >= sConfig.staminaCost, "8");
            w.attributes[0] = w.attributes[0] - sConfig.staminaCost;
            woof.updateTokenTraits(w);
        }
        _pvpCost(config.getPVPCost());
        Report memory r = pvpLogic.pvp(_attackTokenId, _defensiveTokenId);
        reports.push(r);

        if (r.attackWin) {
            if (attackInfo.slaveOwner == _defensiveTokenId) {
                pvpInfo[_attackTokenId].slaveOwner = 0;
                pvpInfo[_attackTokenId].taxPaw = 0;
                pvpInfo[_attackTokenId].taxGem = 0;
                pvpInfo[_attackTokenId].slaveProtectEndTime = 0; 
                woof.delSlavePower(_defensiveTokenId, attackInfo.powerSnapShot);
                pvpInfo[_attackTokenId].powerSnapShot = 0;
            }
            if (attackInfo.slaves.length < sConfig.maxSlaveCount) {
                pvpInfo[_attackTokenId].slaves.push(_defensiveTokenId);
                pvpInfo[_defensiveTokenId].slaveOwner = _attackTokenId;
                pvpInfo[_defensiveTokenId].taxPaw = 0;
                pvpInfo[_defensiveTokenId].taxGem = 0;
                pvpInfo[_defensiveTokenId].slaveProtectEndTime = uint32(block.timestamp + sConfig.protectPeriod);
                uint32 addPower = powerSnapShot(_defensiveTokenId);
                pvpInfo[_defensiveTokenId].powerSnapShot = addPower;
                woof.addSlavePower(_attackTokenId, addPower); 
            }
        }        

        uint32 rid = uint32(reports.length - 1);
        pvpInfo[_attackTokenId].attackReport.push(rid);
        pvpInfo[_defensiveTokenId].defensiveReport.push(rid);
        usersPVPReports[_msgSender()].push(rid);

        emit PVPResult(_msgSender(), r);
    }

    function release(uint32 _tokenId, uint32 _slaveId) external whenNotPaused {
        require(tx.origin == _msgSender(), "1");
        require(woof.ownerOf(_tokenId) == _msgSender(), "2");

        PVPInfo memory defensiveInfo = pvpInfo[_slaveId];
        require(defensiveInfo.slaveOwner == _tokenId, "3"); 
        woof.delSlavePower(_tokenId, defensiveInfo.powerSnapShot);
        defensiveInfo.slaveOwner = 0;
        defensiveInfo.taxPaw = 0;
        defensiveInfo.taxGem = 0;
        defensiveInfo.slaveProtectEndTime = 0;
        defensiveInfo.powerSnapShot = 0;
        pvpInfo[_slaveId] = defensiveInfo;

        uint32[] memory ids = pvpInfo[_tokenId].slaves;
        for (uint256 i = 0; i < ids.length; ++i) {
            if (_slaveId == ids[i]) {
                ids[i] = ids[ids.length - 1];
                break;
            }
        }

        pvpInfo[_tokenId].slaves = ids;
        pvpInfo[_tokenId].slaves.pop();

        emit Release(_msgSender(), _tokenId, _slaveId);
    }

    function reedem(uint32 _tokenId) external whenNotPaused {
        require(tx.origin == _msgSender(), "0");
        require(woof.ownerOf(_tokenId) == _msgSender(), "1");
        PVPInfo memory defensiveInfo = pvpInfo[_tokenId];
        require(defensiveInfo.slaveOwner > 0, "2");
        uint32 slaveOwner = defensiveInfo.slaveOwner;
        uint32 power = woof.miningPowerOf(_tokenId);
        uint256 tax = config.getReedemTax(power);
        address owner = woof.ownerOf2(defensiveInfo.slaveOwner);
        _reedemTax(owner, tax); 
        woof.delSlavePower(slaveOwner, defensiveInfo.powerSnapShot);
        defensiveInfo.reedemTimestamp = uint32(block.timestamp);
        defensiveInfo.slaveOwner = 0;
        defensiveInfo.taxPaw = 0;
        defensiveInfo.taxGem = 0;
        defensiveInfo.slaveProtectEndTime = 0;
        defensiveInfo.powerSnapShot = 0;
        pvpInfo[_tokenId] = defensiveInfo;

        uint32[] memory ids = pvpInfo[slaveOwner].slaves;
        for (uint256 i = 0; i < ids.length; ++i) {
            if (_tokenId == ids[i]) {
                ids[i] = ids[ids.length - 1];
                break;
            }
        }

        pvpInfo[slaveOwner].slaves = ids;
        pvpInfo[slaveOwner].slaves.pop();

        emit Reedem(_msgSender(), _tokenId, defensiveInfo.slaveOwner, tax);
    }

    function _pvpCost(uint256 _cost) internal {
        if (_cost == 0) {
            return;
        }

        uint256 bal1 = IERC20(paw).balanceOf(_msgSender());
        uint256 bal2 = pawVestingPool.balanceOf(_msgSender());
        require(bal1 + bal2 >= _cost, "p1");
        if (bal2 >= _cost) {
            pawVestingPool.transferFrom(_msgSender(), address(this), _cost);
        } else {
            if (bal2  > 0) {
                pawVestingPool.transferFrom(_msgSender(), address(this), bal2);
            }
            IERC20(paw).safeTransferFrom(_msgSender(), address(this), _cost - bal2);
        }
        treasury.deposit(paw, _cost);
    }

    function _reedemTax(address _owner, uint256 _tax) internal {
        uint256 bal1 = IERC20(paw).balanceOf(_msgSender());
        uint256 bal2 = pawVestingPool.balanceOf(_msgSender());
        require(bal1 + bal2 >= _tax, "r1");
        if (bal2 >= _tax) {
            pawVestingPool.transferFrom(_msgSender(), address(this), _tax);
        } else {
            if (bal2  > 0) {
                pawVestingPool.transferFrom(_msgSender(), address(this), bal2);
            }
            IERC20(paw).safeTransferFrom(_msgSender(), address(this), _tax);
        }
        if (_owner != address(0)) {
            IERC20(paw).safeTransferFrom(address(this), _owner, _tax);
        } else {
            treasury.deposit(paw, _tax);
        }
    }

    function _safeApprove(address _token, address _spender) internal {
        if (_token != address(0) && IERC20(_token).allowance(address(this), _spender) == 0) {
            IERC20(_token).safeApprove(_spender, type(uint256).max);
        }
    }

    function totalReportCount() public view override returns(uint256) {
        return reports.length;
    }

    function slaveOwnerAndPayTax(uint32 _tokenId, uint256 _paw, uint256 _gem) public override returns(address, uint256, uint256) {
        require(authControllers[msg.sender] == true, "1");
        PVPInfo memory info = pvpInfo[_tokenId];
        if (info.slaveOwner == 0) {
            return (address(0), 0, 0);
        }

        address owner = woof.ownerOf2(info.slaveOwner);
        if (owner == address(0)) {
            return (address(0), 0, 0);
        }

        uint256 pawTax = config.getSlaveTax(_paw);
        uint256 gemTax = config.getSlaveTax(_gem);
        info.taxPaw += pawTax;
        info.taxGem += gemTax;
        pvpInfo[_tokenId] = info;
        userDashboard.rewardFromScene(owner, 5, pawTax, gemTax, 0);
        return (owner, pawTax, gemTax);
    }

    function payTax(uint32 _tokenId, uint256 _paw, uint256 _gem) public override returns(uint256, uint256) {
        require(authControllers[msg.sender] == true, "1");
        PVPInfo memory info = pvpInfo[_tokenId];
        if (info.slaveOwner == 0) {
            return (0, 0);
        }

        address owner = woof.ownerOf2(info.slaveOwner);
        if (owner == address(0)) {
            return (0, 0);
        }

        uint256 pawTax = config.getSlaveTax(_paw);
        uint256 gemTax = config.getSlaveTax(_gem);
        if (pawTax > 0) {
            IPaw(paw).mint(owner, pawTax);
        }
        if (gemTax > 0) {
            gemMintHelper.mint(owner, gemTax);
        }
        info.taxPaw += pawTax;
        info.taxGem += gemTax;
        pvpInfo[_tokenId] = info;
        userDashboard.rewardFromScene(owner, 5, pawTax, gemTax, 0);
        return (pawTax, gemTax);
    }

    function getPVPInfo(uint32 _tokenId) public view returns(PVPInfo memory) {
        return pvpInfo[_tokenId];
    }

    function getUserReports(address _user) public view returns(uint32[] memory) {
        return usersPVPReports[_user];
    }

    function getReport(uint32 _id) external view returns(Report memory) {
        return reports[_id];
    }

    function powerSnapShot(uint32 _tokenId) public view returns(uint32) {
        IWoof.WoofWoofWest memory w = woof.getTokenTraits(_tokenId);        
        IPVPConfig.sPVPConfig memory sConfig = config.getPVPConfig(w.level);
        return woof.miningPowerOf(w) * sConfig.percentOfPowerBuf / 100;
    }
}