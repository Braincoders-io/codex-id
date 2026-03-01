import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";

dotenv.config();

// Support both DEPLOYER_PRIVATE_KEY and the legacy PRIVATE_KEY env var name
const DEPLOYER_PRIVATE_KEY =
  process.env.DEPLOYER_PRIVATE_KEY ||
  process.env.PRIVATE_KEY ||
  "0x" + "0".repeat(64);

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
      evmVersion: "paris",
    },
  },
  networks: {
    hardhat: {
      chainId: 31337,
    },
    opbnbTestnet: {
      url: "https://opbnb-testnet-rpc.bnbchain.org",
      chainId: 5611,
      accounts: [DEPLOYER_PRIVATE_KEY],
      gasPrice: 1000000000,
    },
    opbnbMainnet: {
      url: "https://opbnb-mainnet-rpc.bnbchain.org",
      chainId: 204,
      accounts: [DEPLOYER_PRIVATE_KEY],
      gasPrice: 1000000000,
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
};

export default config;
