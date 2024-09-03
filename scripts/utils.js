const fs = require("fs");
const ethers = require("ethers");

module.exports = {
     exportJson : function (jsonObj, filePath) {
        return new Promise(resolve => {
            let strJson = JSON.stringify(jsonObj, "", "\t");
            fs.writeFile(filePath, strJson, function(err) {
                if (err) {
                    console.error(err);
                } else {
                    console.log("export json file success: " + filePath);
                }
                resolve();
            })
        })
    },
    importJson : function (filePath) {
        return new Promise(resolve => {
            fs.readFile(filePath, function(err, data) {
                if (err) {
                    console.error(err);
                    resolve(new Object());
                } else {
                    console.log("import json file success: " + filePath);
                    resolve(JSON.parse(data));
                }
            })
        })
    },

    keccak256 : function (message) {
        let messageBytes = ethers.utils.toUtf8Bytes(message);
        return ethers.utils.keccak256(messageBytes);
    },

    readERC20Contract : async function (addr, abi, provider) {
        console.log("readERC20Contract addr: " + addr);
        let erc20Obj = new Object();
        if (addr.toString() === "0x0000000000000000000000000000000000000000") {
            erc20Obj.name = "";
            erc20Obj.symbol = "";
            erc20Obj.address = addr;
            erc20Obj.decimals = "0";
        } else {
            let erc20Contract = new ethers.Contract(addr, abi, provider);
            erc20Obj.name = await erc20Contract.name();
            erc20Obj.symbol = await erc20Contract.symbol();
            let decimals = await erc20Contract.decimals();
            erc20Obj.decimals = decimals.toString();
            erc20Obj.address = addr;
        }
        return erc20Obj;
    }
}