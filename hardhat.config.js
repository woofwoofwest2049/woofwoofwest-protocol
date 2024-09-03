require("@nomiclabs/hardhat-waffle");
require('hardhat-abi-exporter');
require('@openzeppelin/hardhat-upgrades');
require('@nomiclabs/hardhat-etherscan');
require('hardhat-contract-sizer');
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version:"0.8.0",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    },
    mocha: {
      timeout: 20000
    }
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
  },
  abiExporter: {
    path: './config/abi',
    clear: true,
    flat: true,
    spacing: 4,
    runOnCompile: true
  }, 
  defaultNetwork: "bsc",
  forceDeploy: 0,
  networks:{
    eth: {
      url: "https://1rpc.io/eth",
      chainId: 1,
      accounts: [
        "0xa64766af867e5538910ca85feaebd31f6d6502ccd327b44a0b41c6e63ad3b8b2"
      ],
      gasPrice: 10000000000
    },
    bsc: {
      url: "https://binance.llamarpc.com",
      chainId: 56,
      accounts: [
        "0x643eedc04abd191f6411a3aab597831faccdc263174ef17571aa9817a7ddc68a"
      ],
      gasPrice: 1000000000
    },
    bsctest: {
      //url: "https://data-seed-prebsc-1-s3.binance.org:8545",
      url: "https://data-seed-prebsc-1-s2.bnbchain.org:8545",
      chainId: 97,
      accounts: [
        "0x341229517ccaf06fc3b52d3e9f29a3ffad1529e2c05ba046e39ad64169c8f4ea"
      ],
      gasPrice: 10000000000
    },
    arb: {
      url: "https://arbitrum.llamarpc.com",
      chainId: 42161,
      accounts: [
        "0xa64766af867e5538910ca85feaebd31f6d6502ccd327b44a0b41c6e63ad3b8b2"
      ],
      gasPrice: 100000000
    },
    arb2: {
      url: "https://arb1.arbitrum.io/rpc",
      chainId: 42161,
      accounts: [
        "0xaaabceaf45fa2cccab790601771cceb9c6b335b738394643febed676af02ae35"
      ],
      gasPrice: 100000000
    },
    arbtest: {
      url: "https://arb-goerli.g.alchemy.com/v2/cjn9AkdIi3dRnrYPoObK20cDEVPzFUFf",
      chainId: 421613,
      accounts: [
        "0x341229517ccaf06fc3b52d3e9f29a3ffad1529e2c05ba046e39ad64169c8f4ea"
      ],
      gasPrice: 6000000000
    },
    core: {
      url: "https://rpc.coredao.org",
      chainId: 1116,
      accounts: [
        "0x70d5af13cef18d3dfddc5fbac176dffa6db3d2372c9b3e40a396c0d15cf8f0a6"
      ],
      gasPrice: 1000000000
    },
    coretest: {
      url: "https://rpc.test.btcs.network",
      chainId: 1115,
      accounts: [
        "0x341229517ccaf06fc3b52d3e9f29a3ffad1529e2c05ba046e39ad64169c8f4ea"
      ],
      gasPrice: 30000000000
    },
    base: {
      url: "https://developer-access-mainnet.base.org",
      chainId: 8453,
      accounts: [
        "0xa64766af867e5538910ca85feaebd31f6d6502ccd327b44a0b41c6e63ad3b8b2"
      ],
      gasPrice: 10000000
    },
    avax: {
      url: "https://rpc.ankr.com/avalanche",
      chainId: 43114,
      accounts: [
        "0xa2f8c150233589e002c8e3f3d13b9512cabf61d0d2c88eb9e5ee11baa7b1d07d"
      ],
      gasPrice: 50000000000
    },
    bitlayertest: {
      url: "https://testnet-rpc.bitlayer.org",
      chainId: 200810,
      accounts: [
        "0x643eedc04abd191f6411a3aab597831faccdc263174ef17571aa9817a7ddc68a"
      ],
      gasPrice: 100000007
    },
    bitlayertest2: {
      url: "https://testnet-rpc.bitlayer.org",
      chainId: 200810,
      accounts: [
        "0x643eedc04abd191f6411a3aab597831faccdc263174ef17571aa9817a7ddc68a"
      ],
      gasPrice: 100000007
    },
    bitlayer: {
      url: "https://rpc.bitlayer.org",
      chainId: 200901,
      accounts: [
        "0x643eedc04abd191f6411a3aab597831faccdc263174ef17571aa9817a7ddc68a"
      ],
      gasPrice: 50000007
    }
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    //apiKey: "FGUNBYM5V8ZQ41QHHGIE6VTYKYCQXCM5Q6"
    //apiKey: "MKPV9RGSKU18BFG4RP6KANSCZGFJ8G2313"
    apiKey: {
      bitlayertestnet: "1234",
      bitlayertestnet2: "1234",
      bitlayer: "1234"
    },
    customChains: [
      {
        network: "bitlayertestnet",
        chainId: 200810,
        urls: {
          apiURL: "https://api-testnet.btrscan.com/scan/api",
          browserURL: "https://testnet.btrscan.com/"
        }
      },
      {
        network: "bitlayer",
        chainId: 200901,
        urls: {
          apiURL: "https://api.btrscan.com/scan/api",
          browserURL: "https://www.btrscan.com/"
        }
      }
    ]
  }
};
