/**
 * Task 6 — register the Orvium platform agents.
 *
 * They are registered from the Braincoders wallet, which already holds a
 * company-level owner-verified attestation, so each agent is owner-verified on
 * arrival. No per-agent attestation is issued or needed.
 */
import { ethers } from "hardhat";
import deployment from "../deployments/opbnb-testnet.json";

const BASE = "https://raw.githubusercontent.com/Braincoders-io/codex-id/main/agents";
const AGENTS = [
  ["Sales Agent",     `${BASE}/sales-agent.json`],
  ["Marketing Agent", `${BASE}/marketing-agent.json`],
  ["Support Agent",   `${BASE}/support-agent.json`],
];

async function main() {
  const [owner] = await ethers.getSigners();
  const identity = await ethers.getContractAt("CodexIdentity", deployment.contracts.CodexIdentity);
  const ex = (h: string) => `${deployment.explorer}/tx/${h}`;

  for (const [name, uri] of AGENTS) {
    const tx = await identity.connect(owner)["register(string)"](uri);
    const r = await tx.wait();
    let agentId = "?";
    for (const log of r!.logs) {
      try {
        const p = identity.interface.parseLog({ topics: [...log.topics], data: log.data });
        if (p?.name === "Registered") agentId = p.args[0].toString();
      } catch {}
    }
    const cost = r!.gasUsed * r!.gasPrice;
    console.log(`  ${name.padEnd(16)} agentId ${agentId}  $${(Number(ethers.formatEther(cost)) * 1100).toFixed(6)}`);
    console.log(`  ${" ".repeat(16)} ${ex(r!.hash)}`);
  }
}
main().catch((e) => { console.error(e); process.exitCode = 1; });
