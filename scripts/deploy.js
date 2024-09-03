const {ethers, upgrades} = require("hardhat");
const hre = require("hardhat");

const utils = require("./utils.js");
const fs = require("fs");

let config;
let deployer;
let deployerAddress;

async function main() {
    let blockNumber = await ethers.provider.getBlockNumber();
    console.log("block number: " + blockNumber.toString());

    [deployer,] = await ethers.getSigners();
    deployerAddress = await deployer.getAddress();
  
    let balance = await ethers.provider.getBalance(deployerAddress);
    let etherString = ethers.utils.formatEther(balance);
    console.log("deployer: " + deployerAddress + " balance: " + etherString);

    const feeData = await ethers.provider.getFeeData();
    console.log("fee: " + feeData.gasPrice);
  
    //读取network下的合约部署配置文件
    const dirPath = __dirname + "/../config/network/";
    if (!fs.existsSync(dirPath)) {
        fs.mkdirSync(dirPath);
    }
  
    const filePath = dirPath + hre.network.name + ".json";
    config = await utils.importJson(filePath);

    try {
        await deployProxyContract("RandomSeeds", "RandomSeeds", []);
        await deployProxyContract("WoofConfig", "WoofConfig", []);
        await deployProxyContract("WoofRandom", "WoofRandom", [
            config.RandomSeeds.address
        ]);
        await deployProxyContract("WoofTraits", "WoofTraits", []);
        await deployProxyContract("Woof", "Woof", [
            config.WoofTraits.address,
            config.WoofConfig.address,
            config.USDT.address
        ]);

        await deployContract("Paw");
        await deployContract("Gem");
        await deployProxyContract("GemMintHelper", "GemMintHelper", [config.Gem.address]);
        return
        //await deployProxyContract("Airdrop", "Airdrop", []);

        await deployProxyContract("ApproveHelper", "ApproveHelper",  [config.Gem.address, config.Paw.address]);
        await deployProxyContract("GemLiquidity", "GemLiquidity", [config.GemMintHelper.address, config.USDT.address, config.Router.address]);
        await deployProxyContract("PawLiquidity", "PawLiquidity", [config.USDT.address, config.Paw.address, config.Router.address]);
        await setLP("Gem-USDT", "GemLiquidity");
        await setLP("Paw-USDT", "PawLiquidity");
        
        await deployProxyContract("Treasury", "Treasury", [
            config.Gem.address, 
            config.Paw.address, 
            config.USDT.address, 
            config.GemLiquidity.address, 
            config.PawLiquidity.address, 
            config.Dao,
            config.Team
        ]);
        await deployProxyContract("Discount", "Discount", []);
        await deployProxyContract("Barn", "Barn", [
            config.Woof.address,
            config.WoofConfig.address,
            config.Paw.address
        ]);
        await deployProxyContract("WoofHelper", "WoofHelper", [
            config.USDT.address,
            config.WoofRandom.address,
            config.Discount.address,
            config.WoofConfig.address,
            config.Treasury.address,
            config.Woof.address,
            config.Barn.address,
            config.Gem.address,
            config.WBTC.address
        ]);
        await deployProxyContract("LootRandom", "LootRandom", [
            config.RandomSeeds.address
        ]);
        await deployProxyContract("Wanted", "Wanted", [
            config.Woof.address,
            config.Paw.address,
            config.Gem.address,
            config.LootRandom.address
        ]);
        await deployProxyContract("WoofMineConfig", "WoofMineConfig", []);
        await deployProxyContract("WoofMineRandom", "WoofMineRandom",[
            config.RandomSeeds.address
        ]);
        await deployProxyContract("WoofMineTraits", "WoofMineTraits", []);
        await deployProxyContract("WoofMine", "WoofMine", [config.WoofMineTraits.address]);
        await deployProxyContract("WoofMineHelper", "WoofMineHelper", [
            config.Gem.address,
            config.WoofMineRandom.address,
            config.WoofMineConfig.address,
            config.Treasury.address,
            config.WoofMine.address
        ]);
        await deployProxyContract("WoofMinePool", "WoofMinePool", [
            config.WoofMine.address,
            config.Woof.address,
            config.Paw.address,
            config.GemMintHelper.address
        ]);
        await deployProxyContract("Loot", "Loot", [
            config.Woof.address,
            config.WoofMine.address,
            config.WoofMinePool.address,
            config.Paw.address,
            config.Gem.address,
            config.Wanted.address
        ]);
        await deployProxyContract("WoofEnumerable", "WoofEnumerable", [
            config.Woof.address,
            config.Loot.address,
            config.Wanted.address
        ]);
        await deployProxyContract("WoofMineEnumerable", "WoofMineEnumerable", [
            config.WoofMine.address,
            config.WoofMinePool.address,
            config.Woof.address,
            config.Loot.address
        ]);

        await deployProxyContract("PriceCalculator", "PriceCalculator", [config.WBTC.address, config.Factory.address]);
        await deployProxyContract("GemVestingPool", "VestingPool", []);
        await deployProxyContract("PawVestingPool", "VestingPool", []);

        await deployProxyContract("Dashboard", "Dashboard", [
            config.GemVestingPool.address, 
            config.PawVestingPool.address, 
            config.Gem.address, 
            config.Paw.address,
            config.PriceCalculator.address,
            config.Treasury.address
        ]);

        await deployProxyContract("WoofUpgrade", "WoofUpgrade", [
            config.Woof.address,
            config.Treasury.address,
            config.PawVestingPool.address,
            config.Gem.address,
            config.Paw.address,
            config.WoofConfig.address,
            config.RandomSeeds.address
        ]);
        await deployProxyContract("WoofMineUpgrade", "WoofMineUpgrade", [
            config.WoofMine.address,
            config.WoofMinePool.address,
            config.Treasury.address,
            config.GemVestingPool.address,
            config.PawVestingPool.address,
            config.Gem.address,
            config.Paw.address,
            config.WoofMineConfig.address
        ]);
        await deployProxyContract("Item", "Item", [
            config.Paw.address,
            config.Gem.address,
            config.USDT.address,
            config.Treasury.address,
            config.GemVestingPool.address,
            config.PawVestingPool.address
        ]);


        await deployProxyContract("BabyTraits", "BabyTraits", []);
        await deployProxyContract("BabyConfig", "BabyConfig", []);
        await deployProxyContract("Baby", "Baby", [
            config.BabyTraits.address,
            config.Woof.address,
            config.RandomSeeds.address,
            config.PawVestingPool.address,
            config.Treasury.address,
            config.Item.address,
            config.Paw.address,
            config.BabyConfig.address
        ]);
        await deployProxyContract("BabyBlindBox", "BabyBlindBox", [
            config.Baby.address,
            config.RandomSeeds.address,
            config.WoofHelper.address
        ]);
        await deployProxyContract("ExploreConfig", "ExploreConfig", []);
        await deployProxyContract("Explore", "Explore", [
            config.ExploreConfig.address,
            config.Woof.address,
            config.Treasury.address,
            config.PawVestingPool.address,
            config.GemVestingPool.address,
            config.RandomSeeds.address,
            config.Item.address,
            config.GemMintHelper.address,
            config.Paw.address,
            config.Baby.address,
            config.WoofConfig.address
        ]);

        await deployProxyContract("ExploreFollowUp", "ExploreFollowUp",[
            config.Explore.address,
            config.ExploreConfig.address,
            config.Woof.address,
            config.Treasury.address,
            config.PawVestingPool.address,
            config.GemVestingPool.address,
            config.RandomSeeds.address,
            config.WoofConfig.address,
            config.Paw.address,
            config.Gem.address
        ]);
        await deployProxyContract("PVPConfig", "PVPConfig", []);
        await deployProxyContract("PVPLogic", "PVPLogic", [
            config.Woof.address,
            config.RandomSeeds.address
        ]);
        await deployProxyContract("PVP", "PVP", [
            config.Woof.address,
            config.Paw.address,
            config.PawVestingPool.address,
            config.GemMintHelper.address,
            config.Treasury.address,
            config.PVPConfig.address,
            config.PVPLogic.address
        ]);
        await deployProxyContract("PVPEnumerable", "PVPEnumerable", [
            config.PVP.address,
            config.Woof.address
        ]);

        await deployProxyContract("EquipmentTraits", "EquipmentTraits", []);
        await deployProxyContract("EquipmentConfig", "EquipmentConfig", []);
        await deployProxyContract("Equipment", "Equipment", [
            config.EquipmentTraits.address,
            config.EquipmentConfig.address,
            config.RandomSeeds.address
        ]);
        await deployProxyContract("EquipmentUpgrade", "EquipmentUpgrade", [
            config.Equipment.address,
            config.Treasury.address,
            config.PawVestingPool.address,
            config.GemVestingPool.address,
            config.Paw.address,
            config.Gem.address,
            config.RandomSeeds.address
        ]);
        await deployProxyContract("EquipmentBlindBoxTraits", "EquipmentBlindBoxTraits", []);
        await deployProxyContract("EquipmentBlindBox", "EquipmentBlindBox", [
            config.EquipmentBlindBoxTraits.address,
            config.Equipment.address,
            config.Treasury.address,
            config.PawVestingPool.address,
            config.GemVestingPool.address,
            config.Paw.address,
            config.Gem.address
        ]);

        await deployProxyContract("WoofEquipment", "WoofEquipment", [
            config.Woof.address,
            config.Equipment.address
        ]);

        await deployProxyContract("UserDashboard", "UserDashboard", []);

        await deployProxyContract("RankReward", "RankReward", [
            config.GemMintHelper.address,
            config.Woof.address
        ]);

        /*await deployProxyContract("Staking", "Staking", [
            config.WBTC.address,
            config.GemMintHelper.address,
            0
        ]);*/
        
        //await deployBond();
        await sleep(3000);
        await setDependencies();
    } catch(e) {
        console.log("error: " + e);
    } finally {
        await utils.exportJson(config, filePath);
        let balance2 = await ethers.provider.getBalance(deployerAddress);
        etherString = ethers.utils.formatEther(balance2);
        let cost = balance.sub(balance2);
        let costString = ethers.utils.formatEther(cost);
        console.log("deployer: " + deployerAddress + " balance: " + etherString + " cost: " + costString);
    }
}

async function deployProxyContract(name, contractName, arr) {
    if (config[name]) {
        console.log(name + " exist: " + config[name].address);
        return;
    }
    console.log("deployProxyContract name: " + name + " contractName: " + contractName + " arr: " + arr);
    const Contract = await ethers.getContractFactory(contractName);
    const contract = await upgrades.deployProxy(
        Contract,
        arr
    );
    await contract.deployed();
    console.log("deployed " + name + ": " + contract.address);
    let obj = {};
    obj.contractName = contractName;
    obj.address = contract.address;
    config[name] = obj;
    return contract;
}

async function deployContract(name, addr1) {
    if (config[name]) {
        console.log(name + " exist: " + config[name].address);
        return;
    }
    const Contract = await ethers.getContractFactory(name);
    const contract = (addr1) ? (await Contract.deploy(addr1)) : (await Contract.deploy());
    await contract.deployed();
    console.log("deployed " + name + ": " + contract.address);
    let obj = {};
    obj.contractName = name;
    obj.address = contract.address;
    config[name] = obj;
    return contract;
}

async function deployBond() {
    /*await deployProxyContract("LPBondHelper", "LPBondHelper", [
        config.USDT.address,
        config.GemUSDTBond.address,
        config.PawUSDTBond.address,
        config.Router.address
    ]);*/

    await deployProxyContract("GemUSDTFarm", "LPFarm", [
        config["Gem-USDT"].address,
        config.Dao,
        config.GemMintHelper.address,
        config.Woof.address
    ]);
    
    config.GemUSDTFarm.depositToken = config["Gem-USDT"].address;
}

async function setDependencies() {
    console.log("setDependencies");
    gem = contract("Gem", "Gem");
    await initMintHelper("Gem", gem, config.GemMintHelper.address);
    await initApproveHelper("Gem", gem, config.ApproveHelper.address);
    
    gemLiquidity = contract("GemLiquidity", "GemLiquidity");
    await setTreasury("GemLiquidity", gemLiquidity, config.Treasury.address);

    pawLiquidity = contract("PawLiquidity", "PawLiquidity");
    await setTreasury("PawLiquidity", pawLiquidity, config.Treasury.address);

    gemMintHelper = contract("GemMintHelper", "GemMintHelper");
    await setVault("GemMintHelper", gemMintHelper, config.WoofMinePool.address);
    await setVault("GemMintHelper", gemMintHelper, config.GemLiquidity.address);
    await setVault("GemMintHelper", gemMintHelper, config.PawLiquidity.address);
    await setVault("GemMintHelper", gemMintHelper, config.Explore.address);
    //await setVault("GemMintHelper", gemMintHelper, config.GemUSDTBond.address);
    //await setVault("GemMintHelper", gemMintHelper, config.GemUSDTFarm.address);
    await setVault("GemMintHelper", gemMintHelper, config.RankReward.address);
    await setVault("GemMintHelper", gemMintHelper, config.PVP.address);
    await setVault("GemMintHelper", gemMintHelper, config.Staking.address);

    paw = contract("Paw", "Paw");
    await initApproveHelper("Paw", paw, config.ApproveHelper.address);
    await setVault("Paw", paw, config.Barn.address);
    await setVault("Paw", paw, config.WoofMinePool.address);
    await setVault("Paw", paw, config.PawLiquidity.address);
    await setVault("Paw", paw, config.Loot.address);
    await setVault("Paw", paw, config.Explore.address);
    await setVault("Paw", paw, config.PVP.address);
    //await setVault("Paw", paw, config.PawUSDTBond.address);

    treasury = contract("Treasury", "Treasury");
    await setWoof("Treasury", treasury, config.Woof.address);
    await setAuthControllers("Treasury", treasury, config.WoofHelper.address);
    await setAuthControllers("Treasury", treasury, config.WoofMineHelper.address);
    await setAuthControllers("Treasury", treasury, config.WoofMineUpgrade.address);
    await setAuthControllers("Treasury", treasury, config.WoofUpgrade.address);
    await setAuthControllers("Treasury", treasury, config.Item.address);
    await setAuthControllers("Treasury", treasury, config.Baby.address);
    await setAuthControllers("Treasury", treasury, config.Explore.address);
    //await setAuthControllers("Treasury", treasury, config.LooksRareExchange.address);
    await setAuthControllers("Treasury", treasury, config.PVP.address);
    await setAuthControllers("Treasury", treasury, config.EquipmentBlindBox.address);
    await setAuthControllers("Treasury", treasury, config.EquipmentUpgrade.address);
    await setAuthControllers("Treasury", treasury, config.ExploreFollowUp.address);
    await setAuthControllers("Treasury", treasury, config.Rebase);

    wanted = contract("Wanted", "Wanted");
    await setAuthControllers("Wanted", wanted, config.Loot.address);
    await setAuthControllers("Wanted", wanted, config.Woof.address);
    await setPVP("Wanted", wanted, config.PVP.address);
    await setUserDashboard("Wanted", wanted, config.UserDashboard.address);

    woof = contract("Woof", "Woof");
    await setAuthControllers("Woof", woof, config.Barn.address);
    await setAuthControllers("Woof", woof, config.WoofMinePool.address);
    await setAuthControllers("Woof", woof, config.WoofUpgrade.address);
    await setAuthControllers("Woof", woof, config.WoofHelper.address);
    await setAuthControllers("Woof", woof, config.Loot.address);
    await setAuthControllers("Woof", woof, config.Wanted.address);
    await setAuthControllers("Woof", woof, config.Explore.address);
    await setAuthControllers("Woof", woof, config.Treasury.address);
    await setAuthControllers("Woof", woof, config.PVP.address);
    await setAuthControllers("Woof", woof, config.ExploreFollowUp.address);
    //await setAuthControllers("Woof", woof, config.GemUSDTFarm.address);
    await setWanted("Woof", woof, config.Wanted.address);
    await setWoofEquipment("Woof", woof, config.WoofEquipment.address);
    await setUserDashboard("Woof", woof, config.UserDashboard.address);
    await setWoofMinePool("Woof", woof, config.WoofMinePool.address);

    woofHelper = contract("WoofHelper", "WoofHelper");
    await setGemVestingPool("WoofHelper", woofHelper, config.GemVestingPool.address);
    await setDiscount("WoofHelper", woofHelper, config.Discount.address);
    await setItem("WoofHelper", woofHelper, config.Item.address);
    await setAuthControllers("WoofHelper", woofHelper, config.BabyBlindBox.address);
    await setWoofMine("WoofHelper", woofHelper, config.WoofMineHelper.address);
    await setWoofRandom("WoofHelper", woofHelper, config.WoofRandom.address);

    woofMine = contract("WoofMine", "WoofMine");
    await setAuthControllers("WoofMine", woofMine, config.WoofMineHelper.address);
    await setAuthControllers("WoofMine", woofMine, config.WoofMineUpgrade.address);
    await setWoofMinePool("WoofMine", woofMine, config.WoofMinePool.address);

    woofMineHelper = contract("WoofMineHelper", "WoofMineHelper");
    await setVestingPool("WoofMineHelper", woofMineHelper, config.GemVestingPool.address);
    await setWoofMinePool("WoofMineHelper", woofMineHelper, config.WoofMinePool.address);
    await setItem("WoofMineHelper", woofMineHelper, config.Item.address);
    await setAuthControllers("WoofMineHelper", woofMineHelper, config.WoofHelper.address);

    woofMinePool = contract("WoofMinePool", "WoofMinePool");
    await setAuthControllers("WoofMinePool", woofMinePool, config.Loot.address);
    await setAuthControllers("WoofMinePool", woofMinePool, config.WoofMine.address);
    await setAuthControllers("WoofMinePool", woofMinePool, config.WoofMineHelper.address);
    await setAuthControllers("WoofMinePool", woofMinePool, config.Woof.address);
    await setPVP("WoofMinePool", woofMinePool, config.PVP.address);
    await setUserDashboard("WoofMinePool", woofMinePool, config.UserDashboard.address);

    woofMineRandom = contract("WoofMineRandom", "WoofMineRandom");
    await setController("WoofMineRandom", woofMineRandom, config.WoofMineHelper.address);

    lootRandom = contract("LootRandom", "LootRandom");
    await setController("LootRandom", lootRandom, config.Wanted.address);

    woofRandom = contract("WoofRandom", "WoofRandom");
    await setController("WoofRandom", woofRandom, config.WoofHelper.address);

    woofMineTraits = contract("WoofMineTraits", "WoofMineTraits");
    await setNft("WoofMineTraits", woofMineTraits, config.WoofMine.address);

    woofTraits = contract("WoofTraits", "WoofTraits");
    await setNft("WoofTraits", woofTraits, config.Woof.address);
    await setConfig("WoofTraits", woofTraits, config.WoofConfig.address);

    woofConfig = contract("WoofConfig", "WoofConfig");
    await setMintHelper("WoofConfig", woofConfig, config.WoofHelper.address);
    await setWoof("WoofConfig", woofConfig, config.Woof.address);

    woofMineConfig = contract("WoofMineConfig", "WoofMineConfig");
    await setMintHelper("WoofMineConfig", woofMineConfig, config.WoofMineHelper.address);
    await setWoofMine("WoofMineConfig", woofMineConfig, config.WoofMine.address);

    discount = contract("Discount", "Discount");
    await setMintHelper("Discount", discount, config.WoofHelper.address);

    woofEnumerable = contract("WoofEnumerable", "WoofEnumerable");
    await setWoofHelper("WoofEnumerable", woofEnumerable, config.WoofHelper.address);
    await setBaby("WoofEnumerable", woofEnumerable, config.Baby.address);
    await setExplore("WoofEnumerable", woofEnumerable, config.Explore.address);
    await setPVP("WoofEnumerable", woofEnumerable, config.PVPEnumerable.address);

    gemVestingPool = contract("GemVestingPool", "VestingPool");
    await setApprovedController("GemVestingPool", gemVestingPool, config.WoofHelper.address);
    await setApprovedController("GemVestingPool", gemVestingPool, config.WoofMineHelper.address);
    await setApprovedController("GemVestingPool", gemVestingPool, config.WoofUpgrade.address);
    await setApprovedController("GemVestingPool", gemVestingPool, config.WoofMineUpgrade.address);
    await setApprovedController("GemVestingPool", gemVestingPool, config.Explore.address);
    //await setApprovedController("GemVestingPool", gemVestingPool, config.GemUSDTBond.address);
    await setApprovedController("GemVestingPool", gemVestingPool, config.Item.address);
    await setApprovedController("GemVestingPool", gemVestingPool, config.EquipmentBlindBox.address);
    await setApprovedController("GemVestingPool", gemVestingPool, config.EquipmentUpgrade.address);
    await setApprovedController("GemVestingPool", gemVestingPool, config.ExploreFollowUp.address);
    //await setFarmPool("GemVestingPool", gemVestingPool, config.GemUSDTBond.address);
    
    pawVestingPool = contract("PawVestingPool", "VestingPool");
    await setApprovedController("PawVestingPool", pawVestingPool, config.WoofUpgrade.address);
    await setApprovedController("PawVestingPool", pawVestingPool, config.WoofMineUpgrade.address);
    await setApprovedController("PawVestingPool", pawVestingPool, config.Baby.address);
    await setApprovedController("PawVestingPool", pawVestingPool, config.Explore.address);
    //await setApprovedController("PawVestingPool", pawVestingPool, config.PawUSDTBond.address);
    await setApprovedController("PawVestingPool", pawVestingPool, config.Item.address);
    await setApprovedController("PawVestingPool", pawVestingPool, config.WoofHelper.address);
    await setApprovedController("PawVestingPool", pawVestingPool, config.PVP.address);
    await setApprovedController("PawVestingPool", pawVestingPool, config.EquipmentBlindBox.address);
    await setApprovedController("PawVestingPool", pawVestingPool, config.EquipmentUpgrade.address);
    await setApprovedController("PawVestingPool", pawVestingPool, config.ExploreFollowUp.address);
    //await setFarmPool("PawVestingPool", pawVestingPool, config.PawUSDTBond.address);

    item = contract("Item", "Item");
    await setAuthControllers("Item", item, config.WoofMineHelper.address);
    await setAuthControllers("Item", item, config.WoofHelper.address);
    await setAuthControllers("Item", item, config.Baby.address);
    await setAuthControllers("Item", item, config.Explore.address);
    await setAuthControllers("Item", item, config.ExploreFollowUp.address);

    babyTraits = contract("BabyTraits", "BabyTraits");
    await setNft("BabyTraits", babyTraits, config.Baby.address);
    
    baby = contract("Baby", "Baby");
    await setAuthControllers("Baby", baby, config.Explore.address);
    await setAuthControllers("Baby", baby, config.BabyBlindBox.address);

    pvp = contract("PVP", "PVP");
    await setAuthControllers("PVP", pvp, config.Barn.address);
    await setAuthControllers("PVP", pvp, config.Explore.address);
    await setAuthControllers("PVP", pvp, config.Loot.address);
    await setAuthControllers("PVP", pvp, config.Wanted.address);
    await setAuthControllers("PVP", pvp, config.WoofMinePool.address);
    await setUserDashboard("PVP", pvp, config.UserDashboard.address);


    pvpEnumerable = contract("PVPEnumerable", "PVPEnumerable");
    await setWoof("PVPEnumerable", pvpEnumerable, config.Woof.address);

    //dashboard = contract("Dashboard", "Dashboard");
    //await setLPFarm("Dashboard", dashboard, config.GemUSDTFarm.address);

    eBlindBox = contract("EquipmentBlindBox", "EquipmentBlindBox");
    await setAuthControllers("EquipmentBlindBox", eBlindBox, config.Explore.address);

    eBlindBoxTraits = contract("EquipmentBlindBoxTraits", "EquipmentBlindBoxTraits");
    await setNft("EquipmentBlindBoxTraits", eBlindBoxTraits, config.Equipment.address);

    equipment = contract("Equipment", "Equipment");
    await setAuthControllers("Equipment", equipment, config.EquipmentBlindBox.address);
    await setAuthControllers("Equipment", equipment, config.EquipmentUpgrade.address);
    await setAuthControllers("Equipment", equipment, config.WoofEquipment.address);

    equipmentTraits = contract("EquipmentTraits", "EquipmentTraits");
    await setNft("EquipmentTraits", equipmentTraits, config.Equipment.address);

    barn = contract("Barn", "Barn");
    await setPVP("Barn", barn, config.PVP.address);
    await setUserDashboard("Barn", barn, config.UserDashboard.address);

    explore = contract("Explore", "Explore");
    await setPVP("Explore", explore, config.PVP.address);
    await setExploreConfig("Explore", explore, config.ExploreConfig.address);
    await setEquipmentBlindBox("Explore", explore, config.EquipmentBlindBox.address);
    await setUserDashboard("Explore", explore, config.UserDashboard.address);

    exploreFollowUp = contract("ExploreFollowUp", "ExploreFollowUp");
    await setExploreConfig("ExploreFollowUp", exploreFollowUp, config.ExploreConfig.address);
    await setItem("ExploreFollowUp", exploreFollowUp, config.Item.address);

    loot = contract("Loot", "Loot");
    await setPVP("Loot", loot, config.PVP.address);
    await setUserDashboard("Loot", loot, config.UserDashboard.address);

    userDashboard = contract("UserDashboard", "UserDashboard");
    await setAuthControllers("UserDashboard", userDashboard, config.Barn.address);
    await setAuthControllers("UserDashboard", userDashboard, config.Explore.address);
    await setAuthControllers("UserDashboard", userDashboard, config.Loot.address);
    await setAuthControllers("UserDashboard", userDashboard, config.Wanted.address);
    await setAuthControllers("UserDashboard", userDashboard, config.Woof.address);
    await setAuthControllers("UserDashboard", userDashboard, config.WoofMinePool.address);
    await setAuthControllers("UserDashboard", userDashboard, config.PVP.address);
    await setAuthControllers("UserDashboard", userDashboard, config.RankReward.address);

    rankReward = contract("RankReward", "RankReward");
    await setUserDashboard("RankReward", rankReward, config.UserDashboard.address);
    await setAuthControllers("RankReward", rankReward, config.RankRewardAccount);

    priceCalculator = contract("PriceCalculator", "PriceCalculator");
    await setPairToken("PriceCalculator", priceCalculator, config.Paw.address, config.USDT.address);
    await setPairToken("PriceCalculator", priceCalculator, config.Gem.address, config.USDT.address);
}

async function initApproveHelper(name, c, addr) {
    approveHelper = await c.approveHelper();
    console.log(name + " approveHelper: " + approveHelper);
    if (approveHelper != addr) {
        console.log(name + " initApproveHelper");
        await c.initApproveHelper(addr);
    }
}

async function initMintHelper(name, c, addr) {
    mintHelper = await c.mintHelper();
    console.log(name + " mintHelper: " + mintHelper);
    if (mintHelper != addr) {
        console.log(name + " initMintHelper");
        await c.initMintHelper(addr);
    }
}

async function setTreasury(name, c, addr) {
    treasury  = await c.treasury();
    console.log(name + " treasury: " + treasury);
    if (treasury != addr) {
        console.log(name + " setTreasury");
        await c.setTreasury(addr);
    }
}

async function setVault(name, c, addr) {
    isVault = await c.vault(addr);
    console.log(name + " " + addr + " isVault: " + isVault);
    if (isVault == false) {
        console.log(name + " setVault: " + addr);
        await c.setVault(addr, true);
    }
}

async function setWoof(name, c, addr) {
    woof = await c.woof();
    console.log(name + " woof: " + woof);
    if (woof != addr) {
        console.log(name + " setWoof");
        await c.setWoof(addr);
    }
}

async function setAuthControllers(name, c, addr) {
    isController = await c.authControllers(addr);
    console.log(name + " " + addr + " authControllers: " + isController);
    if (isController == false) {
        console.log(name + " setAuthControllers: " + addr);
        await c.setAuthControllers(addr, true);
    }
}

async function setController(name, c, addr) {
    controller = await c.controller();
    console.log(name + " controller: " + controller);
    if (controller != addr) {
        console.log(name + " setController");
        await c.setController(addr);
    }
}

async function setWanted(name, c, addr) {
    wanted = await c.wanted();
    console.log(name + " wanted: " + wanted);
    if (wanted != addr) {
        console.log(name + " setWanted");
        await c.setWanted(addr);
    }
}

async function setNft(name, c, addr) {
    nft = await c.nft();
    console.log(name + " nft: " + nft);
    if (nft != addr) {
        console.log(name + " setNft");
        await c.setNft(addr);
    }
}

async function setConfig(name, c, addr) {
    cig = await c.config();
    console.log(name + " config: " + cig + " addr: " + addr);
    if (cig != addr) {
        console.log(name + " setConfig");
        await c.setConfig(addr);
    }
}

async function setWoofMine(name, c, addr) {
    woofMine = await c.woofMine();
    console.log(name + " woofMine: " + woofMine);
    if (woofMine != addr) {
        console.log(name + " setWoofMine");
        await c.setWoofMine(addr);
    }
}

async function setWoofMinePool(name, c, addr) {
    woofMinePool = await c.woofMinePool();
    console.log(name + " woofMinePool: " + woofMinePool);
    if (woofMinePool != addr) {
        console.log(name + " setWoofMinePool");
        await c.setWoofMinePool(addr);
    }
}

async function setMintHelper(name, c, addr) {
    mintHelper = await c.mintHelper();
    console.log(name + " mintHelper: " + mintHelper);
    if (mintHelper != addr) {
        console.log(name + " setMintHelper");
        await c.setMintHelper(addr);
    }
}

async function setWoofHelper(name, c, addr) {
    woofHelper = await c.woofHelper();
    console.log(name + " woofHelper: " + woofHelper);
    if (woofHelper != addr) {
        console.log(name + " setWoofHelper");
        await c.setWoofHelper(addr);
    }
}

async function setDiscount(name, c, addr) {
    discount = await c.discount();
    console.log(name + " discount: " + discount);
    if (discount != addr) {
        console.log(name + " setDiscount");
        await c.setDiscount(addr);
    }
}

async function setVestingPool(name, c, addr) {
    vestingPool = await c.vestingPool();
    console.log(name + " vestingPool: " + vestingPool);
    if (vestingPool != addr) {
        console.log(name + " setVestingPool");
        await c.setVestingPool(addr);
    }
}

async function setGemVestingPool(name, c, addr) {
    vestingPool = await c.gemVestingPool();
    console.log(name + " gemVestingPool: " + vestingPool);
    if (vestingPool != addr) {
        console.log(name + " setGemVestingPool");
        await c.setGemVestingPool(addr);
    }
}

async function setApprovedController(name, c, addr) {
    isController = await c.approvedController(addr);
    console.log(name + " " + addr + " approvedController: " + isController);
    if (isController == false) {
        console.log(name + " setApprovedController: " + addr);
        await c.setApprovedController(addr, true);
    }
}

async function setItem(name, c, addr) {
    item = await c.item();
    console.log(name + " item: " + item);
    if (item != addr) {
        console.log(name + " setItem");
        await c.setItem(addr);
    }
}

async function setLP(name, cName) {
    c = contract(cName, cName);
    console.log("setLP: " + name);
    if (config[name] == undefined) {
        lp = await c.lp();
        console.log(name + " address: " + lp);
        let obj = {};
        obj.contractName = name;
        obj.address = lp;
        config[name] = obj;
    }
}

async function setFarmPool(name, c, addr) {
    farmPool = await c.farmPool();
    console.log(name + " farmPool: " + farmPool);
    if (farmPool != addr) {
        console.log(name + " setFarmPool");
        await c.setFarmPool(addr);
    }
}

async function setBaby(name, c, addr) {
    baby = await c.baby();
    console.log(name + " baby: " + baby);
    if (baby != addr) {
        console.log(name + " setBaby");
        await c.setBaby(addr);
    }
}

async function setWoofRandom(name, c, addr) {
    random = await c.random();
    console.log(name + " random: " + random);
    if (random != addr) {
        console.log(name + " setWoofRandom");
        await c.setWoofRandom(addr);
    }
}

async function setLPFarm(name, c, addr) {
    lpFarm = await c.lpFarm();
    console.log(name + " lpFarm: " + lpFarm);
    if (lpFarm != addr) {
        console.log(name + " setLPFarm");
        await c.setLPFarm(addr);
    }
}

async function setPVP(name, c, addr) {
    pvp = await c.pvp();
    console.log(name + " pvp: " + pvp);
    if (pvp != addr) {
        console.log(name + " setPVP");
        await c.setPVP(addr);
    }
}

async function setWoofEquipment(name, c, addr) {
    woofEquipment = await c.woofEquipment();
    console.log(name + " woofEquipment: " + woofEquipment);
    if (woofEquipment != addr) {
        console.log(name + " setWoofEquipment");
        await c.setWoofEquipment(addr);
    }
}

async function setExploreConfig(name, c, addr) {
    exploreConfig = await c.exploreConfig();
    console.log(name + " exploreConfig: " + exploreConfig);
    if (exploreConfig != addr) {
        console.log(name + " setExploreConfig");
        await c.setExploreConfig(addr);
    }
}

async function setEquipmentBlindBox(name, c, addr) {
    equipmentBlindBox = await c.equipmentBlindBox();
    console.log(name + " equipmentBlindBox: " + equipmentBlindBox);
    if (equipmentBlindBox != addr) {
        console.log(name + " setEquipmentBlindBox");
        await c.setEquipmentBlindBox(addr);
    }
}

async function setUserDashboard(name, c, addr) {
    userDashboard = await c.userDashboard();
    console.log(name + " userDashboard: " + userDashboard);
    if (userDashboard != addr) {
        console.log(name + " setUserDashboard");
        await c.setUserDashboard(addr);
    }
}

async function setExplore(name, c, addr) {
    explore = await c.explore();
    console.log(name + " explore: " + explore);
    if (explore != addr) {
        console.log(name + " setExplore");
        await c.setExplore(addr);
    }
}

async function setPairToken(name, c, addr, pairToken) {
    p = await c.pairTokens(addr);
    console.log(name + " pairTokens: " + addr + " " + p + " " + pairToken);
    if (p != pairToken) {
        console.log(name + " setPairToken");
        await c.setPairToken(addr, pairToken);
    }
}

function contract(name, contractName) {
    abiJson = abi(contractName);
    const contract = new ethers.Contract(config[name].address, abiJson, deployer);
    return contract;
}


function abi(contractName) {
    abiObj = require("../config/abi/" + contractName + ".json");
    return JSON.stringify(abiObj);
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });