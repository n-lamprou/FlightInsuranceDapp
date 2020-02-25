const HDWalletProvider = require('truffle-hdwallet-provider');
const fs = require('fs');

//const infuraKey = fs.readFileSync(".infura").toString().trim();
//const mnemonic = fs.readFileSync(".secret").toString().trim();

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",     // Localhost (default: none)
      port: 7545,            // Standard Ethereum port (default: none)
      network_id: "*",       // Any network (default: none)
     },
     ropsten: {
       provider: () => new HDWalletProvider(mnemonic, `https://ropsten.infura.io/v3/${infuraKey}`),
       network_id: 3,       // Ropsten's id
       gas: 5500000,        // Ropsten has a lower block limit than mainnet
     },
  },

  // Set default mocha options here
  mocha: {
     timeout: 100000
  },

  // Configure compilers
  compilers: {
    solc: {
       version: "0.4.25",    // Fetch exact version from solc-bin (default: truffle's version)
      // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
      // settings: {          // See the solidity docs for advice about optimization and evmVersion
      //  optimizer: {
      //    enabled: false,
      //    runs: 200
      //  },
      //  evmVersion: "byzantium"
      // }
    }
  }
}
