/**
 * Re-issue the owner-verified attestation at COMPANY level.
 * Dactilar (the issuer) verifies the company once; every agent that company
 * owns inherits verification, because attestations are keyed by address.
 * Revokes the earlier agent-specific attestation so only one is authoritative.
 */
import { ethers } from "hardhat";
import * as fs from "fs";
import deployment from "../deployments/opbnb-testnet.json";

const DOC = "attestations/braincoders-company-verification.txt";
const SCHEMA = ethers.keccak256(ethers.toUtf8Bytes("dactilar.owner.verified.v1"));
const STALE = "0xf874c273985d8aeac12a1dab71749c28720ec3cb1629f62e6d1c044dcdd5e37c";

async function main() {
  const issuer = new ethers.Wallet(process.env.ISSUER_PRIVATE_KEY!, ethers.provider);
  const identity = await ethers.getContractAt("CodexIdentity", deployment.contracts.CodexIdentity);
  const ex = (h: string) => `${deployment.explorer}/tx/${h}`;

  const subject = await identity.ownerOf(1n);
  const documentHash = ethers.keccak256(fs.readFileSync(DOC));
  const expiresAt = Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60;

  const old = await identity.getAttestation(STALE);
  if (!old.revoked) {
    const r = await (await identity.connect(issuer).revokeAttestation(STALE)).wait();
    console.log(`  revoked agent-specific attestation  ${ex(r!.hash)}`);
  } else console.log("  earlier attestation already revoked — skipped");

  const r = await (await identity.connect(issuer)
    .createAttestation(subject, documentHash, SCHEMA, expiresAt)).wait();
  let id = "";
  for (const log of r!.logs) {
    try { const p = identity.interface.parseLog({ topics: [...log.topics], data: log.data });
          if (p?.name === "AttestationCreated") id = p.args[0]; } catch {}
  }
  console.log(`  issued company-level attestation    ${ex(r!.hash)}`);
  console.log(`
  attestationId  ${id}
  issuer         ${issuer.address}   (Dactilar)
  subject        ${subject}   (Braincoders)
  documentHash   ${documentHash}
  valid          ${await identity.verifyAttestation(id)}
  stale revoked  ${(await identity.getAttestation(STALE)).revoked}
`);
}
main().catch((e) => { console.error(e); process.exitCode = 1; });
