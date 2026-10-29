import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";

dotenv.config();

// Support both DEPLOYER_PRIVATE_KEY and the legacy PRIVATE_KEY env var name.
// Left unset, the networks have no accounts — read-only scripts still run.
const DEPLOYER_PRIVATE_KEY =
  process.env.DEPLOYER_PRIVATE_KEY || process.env.PRIVATE_KEY;

const accounts = DEPLOYER_PRIVATE_KEY ? [DEPLOYER_PRIVATE_KEY] : [];

// opBNB is not served by Etherscan's multichain API, so opbnbscan verification
// goes through NodeReal's open platform. Get a free key at nodereal.io.
// Without the key, `hardhat verify` still publishes to Sourcify.
const NODEREAL_API_KEY = process.env.NODEREAL_API_KEY;

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
      accounts,
    },
    opbnbMainnet: {
      url: "https://opbnb-mainnet-rpc.bnbchain.org",
      chainId: 204,
      accounts,
    },
  },
  // Chain configs are matched by chainId, and the api key is then looked up by
  // the config's `network` name — hence "opbnb" / "opbnbMainnet" below rather
  // than the Hardhat network names.
  etherscan: {
    enabled: Boolean(NODEREAL_API_KEY),
    apiKey: {
      opbnb: NODEREAL_API_KEY ?? "",
      opbnbMainnet: NODEREAL_API_KEY ?? "",
    },
    customChains: [
      {
        network: "opbnb",
        chainId: 5611,
        urls: {
          apiURL: `https://open-platform.nodereal.io/${NODEREAL_API_KEY}/op-bnb-testnet/contract/`,
          browserURL: "https://testnet.opbnbscan.com",
        },
      },
      {
        network: "opbnbMainnet",
        chainId: 204,
        urls: {
          apiURL: `https://open-platform.nodereal.io/${NODEREAL_API_KEY}/op-bnb/contract/`,
          browserURL: "https://opbnbscan.com",
        },
      },
    ],
  },
  sourcify: {
    enabled: true,
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
};

export default config;
