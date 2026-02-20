import { registerAs } from "@nestjs/config";

export const blockchainConfig = registerAs("blockchain", () => ({
  rpcUrl: process.env.OPBNB_RPC_URL || "https://opbnb-testnet-rpc.bnbchain.org",
  chainId: parseInt(process.env.OPBNB_CHAIN_ID || "5611", 10),
  codexIdentityAddress: process.env.CODEX_IDENTITY_ADDRESS,
  signerPrivateKey: process.env.SIGNER_PRIVATE_KEY,
}));
