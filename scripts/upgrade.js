const {ethers, upgrades} = require("hardhat");
const hre = require("hardhat");
const utils = require("./utils.js");
const fs = require("fs");

async function main() {
    let blockNumber = await ethers.provider.getBlockNumber();
    console.log("block number: " + blockNumber.toString());

    [deployer,] = await ethers.getSigners();
    let deployerAddress = await deployer.getAddress();

    let balance = await ethers.provider.getBalance(deployerAddress);
    let etherString = ethers.utils.formatEther(balance);
    console.log("deployer: " + deployerAddress + " balance: " + etherString);

    //读取network下的合约部署配置文件
    const dirPath = __dirname + "/../config/network/";
    const filePath = dirPath + hre.network.name + ".json";
    let config = await utils.importJson(filePath);
    //await upgradeContract(config.Discount.address, config.Discount.contractName);
    await upgradeContract(config.Airdrop.address, config.Airdrop.contractName);
    //await upgradeContract(config.BabyBlindBox.address, config.BabyBlindBox.contractName);
    //await upgradeContract(config.WoofHelper.address, config.WoofHelper.contractName);
    let balance2 = await ethers.provider.getBalance(deployerAddress);
    etherString = ethers.utils.formatEther(balance2);
    let cost = balance.sub(balance2);
    let costString = ethers.utils.formatEther(cost);
    console.log("deployer: " + deployerAddress + " balance: " + etherString + " cost: " + costString);
}

async function upgradeContract(address, name) {
  console.log("upgradeContract: " + name + " address: " + address);
  const Contract = await ethers.getContractFactory(name);
  const contract = await upgrades.upgradeProxy(address, Contract);
  await contract.deployed();
  console.log("upgradeContract upgradeProxy to: " + contract.address);

  let obj = {};
  obj.contractName = name;
  obj.address = contract.address;
  return obj;
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