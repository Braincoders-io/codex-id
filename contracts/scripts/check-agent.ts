/**
 * Read-only "platform check" against the live opBNB testnet deployment.
 *   npx hardhat run <this file> --network opbnbTestnet
 * Answers, for one agentId: owner, owner-verified, status, reputation score, allow/deny.
 */
import { ethers } from "hardhat";
import deployment from "../deployments/opbnb-testnet.json";

const AGENT_ID = BigInt(process.env.AGENT_ID ?? "1");
const OWNER_VERIFIED_SCHEMA = ethers.keccak256(
  ethers.toUtf8Bytes(process.env.SCHEMA ?? "dactilar.owner.verified.v1")
);
const MIN_SCORE = Number(process.env.MIN_SCORE ?? "80");

const STATUS = ["Active", "Paused", "Terminated"];

async function main() {
  const identity = await ethers.getContractAt("CodexIdentity", deployment.contracts.CodexIdentity);
  const reputation = await ethers.getContractAt("ReputationRegistry", deployment.contracts.ReputationRegistry);

  // 1. owner + lifecycle status (one call)
  const state = await identity.getState(AGENT_ID);
  const owner = state.owner;
  const status = STATUS[Number(state.status)];

  // 2. owner verified — any unexpired, unrevoked attestation on the chosen schema
  let ownerVerified = false;
  let attestationId = "";
  let issuer = "";
  for (const id of Array.from(await identity.getSubjectAttestations(owner))) {
    const a = await identity.getAttestation(id);
    if (a[3] === OWNER_VERIFIED_SCHEMA && (await identity.verifyAttestation(id))) {
      ownerVerified = true;
      attestationId = id;
      issuer = a[0];
      break;
    }
  }
  // An attestation an owner issued about itself proves nothing — say so plainly.
  const selfAttested = ownerVerified && issuer.toLowerCase() === owner.toLowerCase();

  // 3. reputation — getSummary requires an explicit client list (ERC-8004 anti-Sybil)
  const clients = Array.from(await reputation.getClients(AGENT_ID));
  let count = 0n, score = 0n;
  if (clients.length > 0) {
    const s = await reputation.getSummary(AGENT_ID, clients, "", "");
    count = s[0]; score = s[1];
  }

  const allowed = status === "Active" && ownerVerified && Number(score) >= MIN_SCORE && count > 0n;

  console.log(`
  Agent #${AGENT_ID}  —  ${deployment.network} (chainId ${deployment.chainId})

    owner            ${owner}
    owner verified   ${ownerVerified}${attestationId ? `  (attestation ${attestationId.slice(0, 10)}…)` : ""}
    attested by      ${issuer || "—"}${selfAttested ? "  ⚠ SELF-ATTESTED" : ownerVerified ? "  (independent of owner)" : ""}
    status           ${status}
    reputation       ${score}/100  from ${count} review(s)

    DECISION         ${allowed ? "ALLOWED" : "DENIED"}   (policy: Active + owner verified + score >= ${MIN_SCORE})

    identity         ${deployment.explorer}/address/${deployment.contracts.CodexIdentity}
    reputation       ${deployment.explorer}/address/${deployment.contracts.ReputationRegistry}
  `);
}

main().catch((e) => { console.error(e); process.exitCode = 1; });
