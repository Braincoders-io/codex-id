/**
 * Task 4 — bind agent #1's payment wallet with an EIP-712 signature.
 *
 * The AGENT WALLET signs; the AGENT OWNER sends the transaction. The wallet
 * therefore never needs gas, and the binding is only valid if the wallet itself
 * consented. CodexIdentity._update clears it automatically on transfer, so
 * selling the agent cannot leave payments flowing to the previous owner.
 */
import { ethers } from "hardhat";
import deployment from "../deployments/opbnb-testnet.json";

const AGENT_ID = 1n;

async function main() {
  const [owner] = await ethers.getSigners();
  const key = process.env.AGENT_WALLET_PRIVATE_KEY;
  if (!key) throw new Error("AGENT_WALLET_PRIVATE_KEY missing from .env");
  const agentWallet = new ethers.Wallet(key);

  const identity = await ethers.getContractAt("CodexIdentity", deployment.contracts.CodexIdentity);
  const before = await identity.getAgentWallet(AGENT_ID);

  const deadline = Math.floor(Date.now() / 1000) + 3600;
  const signature = await agentWallet.signTypedData(
    { name: "CodexIdentity", version: "1", chainId: Number(deployment.chainId),
      verifyingContract: deployment.contracts.CodexIdentity },
    { SetAgentWallet: [
        { name: "agentId",   type: "uint256" },
        { name: "newWallet", type: "address" },
        { name: "deadline",  type: "uint256" } ] },
    { agentId: AGENT_ID, newWallet: agentWallet.address, deadline }
  );

  const tx = await identity.connect(owner).setAgentWallet(AGENT_ID, agentWallet.address, deadline, signature);
  const r = await tx.wait();
  const cost = r!.gasUsed * r!.gasPrice;

  console.log(`
  agentWallet before : ${before}   (mint default — never signed for)
  agentWallet after  : ${await identity.getAgentWallet(AGENT_ID)}
  signed by          : ${agentWallet.address}  (the wallet itself, off-chain)
  sent by            : ${owner.address}  (the agent owner)
  tx                 : ${deployment.explorer}/tx/${r!.hash}
  cost               : ${ethers.formatEther(cost)} tBNB  (~$${(Number(ethers.formatEther(cost)) * 1100).toFixed(6)})
`);
}
main().catch((e) => { console.error(e); process.exitCode = 1; });
