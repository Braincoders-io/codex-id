/**
 * Task 8 — live numbers for the deck, read from chain. No private key needed.
 *   npx hardhat run scripts/stats.ts --network opbnbTestnet
 * Note: _tokenIdCounter and _nonce are private with no getter, so agents are
 * probed and attestations are read per subject rather than counted globally.
 */
import { ethers } from "hardhat";
import deployment from "../deployments/opbnb-testnet.json";

const WALLETS: Record<string, string> = {
  deployer: deployment.deployer,
  issuer:   "0xe8FA7c7046c2B0e099EDb554Ff2B8bABf5c1b5F1",
  client:   deployment.demo.clientWallet,
  reviewer: "0xc649298F4017074adB7dFC9ADF311fC4f6b5cb5e",
};
const STATUS = ["Active", "Paused", "Terminated"];

async function main() {
  const identity   = await ethers.getContractAt("CodexIdentity", deployment.contracts.CodexIdentity);
  const reputation = await ethers.getContractAt("ReputationRegistry", deployment.contracts.ReputationRegistry);
  const p = ethers.provider;

  // agents
  const agents: { id: bigint; owner: string; status: string; wallet: string }[] = [];
  for (let i = 1n; i <= 50n; i++) {
    try {
      const s = await identity.getState(i);
      agents.push({ id: i, owner: s.owner, status: STATUS[Number(s.status)],
                    wallet: await identity.getAgentWallet(i) });
    } catch { break; }
  }

  // attestations, per distinct owner
  const owners = [...new Set(agents.map(a => a.owner))];
  let live = 0, revoked = 0;
  for (const o of owners)
    for (const id of Array.from(await identity.getSubjectAttestations(o))) {
      const a = await identity.getAttestation(id);
      a.revoked ? revoked++ : live++;
    }

  // issuers (a mapping cannot be enumerated — probe the known addresses)
  const issuers: string[] = [];
  for (const a of Object.values(WALLETS))
    if (await identity.authorizedIssuers(a)) issuers.push(a);

  // reputation + transactions
  const clients = Array.from(await reputation.getClients(1n));
  let reviews = 0n, score = 0n;
  if (clients.length) { const s = await reputation.getSummary(1n, clients, "", ""); reviews = s[0]; score = s[1]; }

  let txs = 0;
  for (const a of Object.values(WALLETS)) txs += await p.getTransactionCount(a);

  const fee = (await p.getFeeData()).gasPrice!;
  console.log(`
  DACTILAR — LIVE ON-CHAIN STATS          ${new Date().toISOString()}
  ${deployment.network} · chainId ${deployment.chainId} · block ${await p.getBlockNumber()}

    contracts deployed        3
    agents registered         ${agents.length}
    attestations live         ${live}   (revoked: ${revoked})
    authorised issuers        ${issuers.length}
    reviews on agent #1       ${reviews}  (score ${score}/100)
    on-chain transactions     ${txs}
    gas price                 ${ethers.formatUnits(fee, "gwei")} gwei
`);
  for (const a of agents)
    console.log(`    agent #${a.id}  ${a.status.padEnd(10)} owner ${a.owner}  wallet ${a.wallet}`);
  console.log();
}
main().catch((e) => { console.error(e); process.exitCode = 1; });
