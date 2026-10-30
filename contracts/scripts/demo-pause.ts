/**
 * Task 5 — the kill switch, end to end on opBNB testnet.
 *   ALLOWED  ->  pause()  ->  DENIED  ->  unpause()  ->  ALLOWED
 * Every state change is a real transaction; the verdict is read from chain.
 */
import { ethers } from "hardhat";
import deployment from "../deployments/opbnb-testnet.json";

const AGENT_ID = 1n;
const SCHEMA = ethers.keccak256(ethers.toUtf8Bytes("dactilar.owner.verified.v1"));
const MIN_SCORE = 80;
const STATUS = ["Active", "Paused", "Terminated"];

async function check(identity: any, reputation: any) {
  const state = await identity.getState(AGENT_ID);
  const status = STATUS[Number(state.status)];
  let verified = false;
  for (const id of Array.from(await identity.getSubjectAttestations(state.owner))) {
    const a = await identity.getAttestation(id);
    if (a[3] === SCHEMA && (await identity.verifyAttestation(id))) { verified = true; break; }
  }
  const clients = Array.from(await reputation.getClients(AGENT_ID));
  let score = 0n, count = 0n;
  if (clients.length) { const s = await reputation.getSummary(AGENT_ID, clients, "", ""); count = s[0]; score = s[1]; }
  const allowed = status === "Active" && verified && Number(score) >= MIN_SCORE && count > 0n;
  return { status, verified, score, allowed };
}

const line = (tag: string, r: any) =>
  console.log(`  ${tag.padEnd(22)} status=${r.status.padEnd(10)} verified=${r.verified}  score=${r.score}  ->  ${r.allowed ? "ALLOWED" : "DENIED"}`);

async function main() {
  const [owner] = await ethers.getSigners();
  const identity = await ethers.getContractAt("CodexIdentity", deployment.contracts.CodexIdentity);
  const reputation = await ethers.getContractAt("ReputationRegistry", deployment.contracts.ReputationRegistry);
  const ex = (h: string) => `${deployment.explorer}/tx/${h}`;

  line("1. before", await check(identity, reputation));

  let r = await (await identity.connect(owner).pause(AGENT_ID)).wait();
  console.log(`  2. pause(1)            ${ex(r!.hash)}`);
  line("3. after pause", await check(identity, reputation));

  r = await (await identity.connect(owner).unpause(AGENT_ID)).wait();
  console.log(`  4. unpause(1)          ${ex(r!.hash)}`);
  line("5. after unpause", await check(identity, reputation));
}
main().catch((e) => { console.error(e); process.exitCode = 1; });
