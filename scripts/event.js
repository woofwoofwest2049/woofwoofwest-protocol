let web3 = require('web3')

const url = "https://bsc-dataseed1.binance.org/";
const provider = new ethers.providers.JsonRpcProvider(url)

async function main() {
    
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });