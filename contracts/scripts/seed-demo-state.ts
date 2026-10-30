/**
 * Seed the demo state for the Orvium agents.
 *
 * This writes DEMO data: the reviews below come from a wallet we created and
 * funded, not from real customers. It exists so the platform view shows the
 * two outcomes a platform actually cares about:
 *
 *   #2 Sales      verified + reviewed        -> ALLOWED
 *   #3 Marketing  verified + reviewed        -> ALLOWED
 *   #4 Support    verified + reviewed, but owner-paused -> DENIED
 *
 * Agent #4 is denied purely because its owner paused it: it is verified and
 * well reviewed. The denial is a real lifecycle state, not a fabricated score.
 */
import { ethers } from "hardhat";
import deployment from "../deployments/opbnb-testnet.json";

const REVIEWS: [bigint, bigint, string, string][] = [
  [2n, 92n, "quality", "sales"],
  [3n, 88n, "quality", "marketing"],
  [4n, 91n, "quality", "support"],
];
const PAUSE_AGENT = 4n;

async function main() {
  const [owner] = await ethers.getSigners();
  const client = new ethers.Wallet(process.env.CLIENT_PRIVATE_KEY!, ethers.provider);
  const identity = await ethers.getContractAt("CodexIdentity", deployment.contracts.CodexIdentity);
  const reputation = await ethers.getContractAt("ReputationRegistry", deployment.contracts.ReputationRegistry);
  const ex = (h: string) => `${deployment.explorer}/tx/${h}`;

  const bal = await ethers.provider.getBalance(client.address);
  if (bal < ethers.parseEther("0.0001")) {
    const r = await (await owner.sendTransaction({ to: client.address, value: ethers.parseEther("0.0002") })).wait();
    console.log(`  funded reviewer wallet   ${ex(r!.hash)}`);
  } else {
    console.log(`  reviewer already funded (${ethers.formatEther(bal)} tBNB)`);
  }

  for (const [agentId, value, tag1, tag2] of REVIEWS) {
    const r = await (await reputation.connect(client).giveFeedback(
      agentId, value, 0, tag1, tag2, "https://orvium.ai/agents", "", ethers.ZeroHash
    )).wait();
    console.log(`  review on agent #${agentId}: ${value}/100   ${ex(r!.hash)}`);
  }

  if (Number((await identity.getState(PAUSE_AGENT)).status) === 0) {
    const r = await (await identity.connect(owner).pause(PAUSE_AGENT)).wait();
    console.log(`  paused agent #${PAUSE_AGENT}          ${ex(r!.hash)}`);
  } else {
    console.log(`  agent #${PAUSE_AGENT} already paused`);
  }
}
main().catch((e) => { console.error(e); process.exitCode = 1; });
