import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("╔══════════════════════════════════════════════════╗");
  console.log("║   Codex Identity — opBNB Testnet Deployment     ║");
  console.log("╚══════════════════════════════════════════════════╝");
  console.log(`  Deployer : ${deployer.address}`);
  console.log(`  Balance  : ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} tBNB`);
  console.log(`  Network  : opBNB Testnet (Chain ID 5611)`);
  console.log("");

  // Deploy CodexIdentity
  const CodexIdentity = await ethers.getContractFactory("CodexIdentity");
  const codexIdentity = await CodexIdentity.deploy();
  await codexIdentity.waitForDeployment();

  const contractAddress = await codexIdentity.getAddress();
  console.log(`  ✓ CodexIdentity deployed at: ${contractAddress}`);

  // --- Transaction 1: Create an initial attestation schema ---
  const NOTARY_SCHEMA_ID = ethers.keccak256(
    ethers.toUtf8Bytes("codex.identity.notary.v1")
  );
  console.log(`  ✓ Notary Schema ID: ${NOTARY_SCHEMA_ID}`);

  // --- Verify the deployer is an authorized issuer ---
  const isAuthorized = await codexIdentity.authorizedIssuers(deployer.address);
  console.log(`  ✓ Deployer is authorized issuer: ${isAuthorized}`);

  console.log("");
  console.log("  Deployment complete. Save this address in your .env:");
  console.log(`  CODEX_IDENTITY_ADDRESS=${contractAddress}`);
  console.log("");
  console.log("  Next steps:");
  console.log("  1. Call createAttestation() to register an identity");
  console.log("  2. Call revokeAttestation() to revoke if needed");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
