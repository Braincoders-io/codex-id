/**
 * Task 3 — introduce a second, independent attestation issuer and have it
 * notarise the agent-1 ownership statement under schema
 * "dactilar.owner.verified.v1".
 *
 *   npx hardhat run scripts/setup-issuer.ts --network opbnbTestnet
 *
 * Needs PRIVATE_KEY (registry admin / agent owner) and ISSUER_PRIVATE_KEY in .env.
 * Idempotent: skips funding and addIssuer if already done.
 */
import { ethers } from "hardhat";
import * as fs from "fs";
import deployment from "../deployments/opbnb-testnet.json";

const DOC = "attestations/agent-1-ownership.txt";
const SCHEMA = "dactilar.owner.verified.v1";
const AGENT_ID = 1n;
const ISSUER_FLOAT = ethers.parseEther("0.0002");
const ONE_YEAR = 365 * 24 * 60 * 60;

const ex = (h: string) => `${deployment.explorer}/tx/${h}`;

async function main() {
  const [admin] = await ethers.getSigners();
  const issuerKey = process.env.ISSUER_PRIVATE_KEY;
  if (!issuerKey) throw new Error("ISSUER_PRIVATE_KEY missing from .env");
  const issuer = new ethers.Wallet(issuerKey, ethers.provider);

  const identity = await ethers.getContractAt("CodexIdentity", deployment.contracts.CodexIdentity);

  const documentHash = ethers.keccak256(fs.readFileSync(DOC));
  const schemaId = ethers.keccak256(ethers.toUtf8Bytes(SCHEMA));
  const subject = await identity.ownerOf(AGENT_ID);

  console.log(`
  admin / agent owner : ${admin.address}
  new issuer          : ${issuer.address}
  subject             : ${subject}
  document            : ${DOC}
  documentHash        : ${documentHash}
  schemaId            : ${schemaId}  ("${SCHEMA}")
`);

  // 1 — fund the issuer so it can pay for its own attestation
  const bal = await ethers.provider.getBalance(issuer.address);
  if (bal < ISSUER_FLOAT / 2n) {
    const tx = await admin.sendTransaction({ to: issuer.address, value: ISSUER_FLOAT });
    const r = await tx.wait();
    console.log(`  [1/3] funded issuer with ${ethers.formatEther(ISSUER_FLOAT)} tBNB`);
    console.log(`        ${ex(r!.hash)}`);
  } else {
    console.log(`  [1/3] issuer already funded (${ethers.formatEther(bal)} tBNB) — skipped`);
  }

  // 2 — authorise it (onlyOwner)
  if (!(await identity.authorizedIssuers(issuer.address))) {
    const tx = await identity.connect(admin).addIssuer(issuer.address);
    const r = await tx.wait();
    console.log(`  [2/3] addIssuer(${issuer.address})`);
    console.log(`        ${ex(r!.hash)}`);
  } else {
    console.log(`  [2/3] already an authorised issuer — skipped`);
  }

  // 3 — the issuer notarises the statement (msg.sender becomes the issuer)
  const expiresAt = Math.floor(Date.now() / 1000) + ONE_YEAR;
  const tx = await identity
    .connect(issuer)
    .createAttestation(subject, documentHash, schemaId, expiresAt);
  const r = await tx.wait();

  let attestationId = "";
  for (const log of r!.logs) {
    try {
      const p = identity.interface.parseLog({ topics: [...log.topics], data: log.data });
      if (p?.name === "AttestationCreated") attestationId = p.args[0];
    } catch {}
  }

  const cost = r!.gasUsed * r!.gasPrice;
  console.log(`  [3/3] createAttestation by the new issuer`);
  console.log(`        ${ex(r!.hash)}`);
  console.log(`        attestationId : ${attestationId}`);
  console.log(`        gas ${r!.gasUsed} @ ${ethers.formatUnits(r!.gasPrice, "gwei")} gwei`);
  console.log(`        cost ${ethers.formatEther(cost)} tBNB  (~$${(Number(ethers.formatEther(cost)) * 1100).toFixed(6)})`);
  console.log(`        valid        : ${await identity.verifyAttestation(attestationId)}`);
  console.log(`        expires      : ${new Date(expiresAt * 1000).toISOString()}`);
}

main().catch((e) => { console.error(e); process.exitCode = 1; });
