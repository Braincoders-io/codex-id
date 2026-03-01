import { ethers } from "hardhat";
import type { Log, LogDescription } from "ethers";
import type { ReputationRegistry, CodexIdentity } from "../typechain-types";
import * as fs from "fs";
import * as path from "path";

// ─────────────────────────────────────────────────────────────
//  Explorer helper
// ─────────────────────────────────────────────────────────────
const EXPLORER = "https://testnet.opbnbscan.com";
const tx  = (hash: string) => `${EXPLORER}/tx/${hash}`;
const addr = (address: string) => `${EXPLORER}/address/${address}`;

function separator() {
  console.log("  " + "─".repeat(60));
}

function section(title: string) {
  console.log("");
  console.log(`  ▶ ${title}`);
  separator();
}

// ─────────────────────────────────────────────────────────────
//  Main
// ─────────────────────────────────────────────────────────────
async function main() {
  const [deployer] = await ethers.getSigners();
  const balance = await ethers.provider.getBalance(deployer.address);

  console.log("");
  console.log("  ╔══════════════════════════════════════════════════════════╗");
  console.log("  ║           Full Deployment to opBNB Testnet               ║");
  console.log("  ╚══════════════════════════════════════════════════════════╝");
  console.log(`  Deployer : ${deployer.address}`);
  console.log(`  Balance  : ${ethers.formatEther(balance)} tBNB`);
  console.log(`  Network  : opBNB Testnet (Chain ID 5611)`);
  console.log(`  Explorer : ${EXPLORER}`);

  if (balance < ethers.parseEther("0.001")) {
    throw new Error(
      `Insufficient balance. Need at least 0.001 tBNB, have ${ethers.formatEther(balance)}.\n` +
      `  Get tBNB from: https://opbnb-testnet-faucet.bnbchain.org`
    );
  }

  // ─────────────────────────────────────────────────────────
  //  PHASE 1 — Deploy Contracts
  // ─────────────────────────────────────────────────────────
  section("PHASE 1 — Deploying Contracts");

  // 1. CodexIdentity
  const CodexIdentityFactory = await ethers.getContractFactory("CodexIdentity");
  const codexIdentity = (await CodexIdentityFactory.deploy()) as unknown as CodexIdentity;
  await codexIdentity.waitForDeployment();
  const identityAddress = await codexIdentity.getAddress();
  console.log(`  ✓ CodexIdentity     → ${identityAddress}`);
  console.log(`    ${addr(identityAddress)}`);

  // 2. ReputationRegistry
  const ReputationFactory = await ethers.getContractFactory("ReputationRegistry");
  const reputationRegistry = await ReputationFactory.deploy(identityAddress);
  await reputationRegistry.waitForDeployment();
  const reputationAddress = await reputationRegistry.getAddress();
  console.log(`  ✓ ReputationRegistry   → ${reputationAddress}`);
  console.log(`    ${addr(reputationAddress)}`);

  // 3. ValidationRegistry
  const ValidationFactory = await ethers.getContractFactory("ValidationRegistry");
  const validationRegistry = await ValidationFactory.deploy(identityAddress);
  await validationRegistry.waitForDeployment();
  const validationAddress = await validationRegistry.getAddress();
  console.log(`  ✓ ValidationRegistry   → ${validationAddress}`);
  console.log(`    ${addr(validationAddress)}`);

  // ─────────────────────────────────────────────────────────
  //  PHASE 2 — On-Chain Transactions
  // ─────────────────────────────────────────────────────────
  section("PHASE 2 — On-Chain Transactions");

  // ── Tx 1: Register AI Agent (mint NFT) ──────────────────
  console.log("  [Tx 1] register() — Mint first AI agent NFT");
  const agentURI = "ipfs://QmAgentDemo1Registration";
  const registerTx = await (codexIdentity as CodexIdentity)["register(string)"](agentURI);
  const registerReceipt = await registerTx.wait();

  // Parse agentId from the Registered(uint256 indexed agentId, ...) event
  const registeredEvent = registerReceipt!.logs
    .map((log: Log): LogDescription | null => { try { return codexIdentity.interface.parseLog(log); } catch { return null; } })
    .find((e: LogDescription | null) => e?.name === "Registered");
  const agentId: bigint = registeredEvent?.args?.agentId ?? 1n;

  console.log(`    agentId  : ${agentId}`);
  console.log(`    agentURI : ${agentURI}`);
  console.log(`    Tx Hash  : ${tx(registerReceipt!.hash)}`);

  // ── Tx 2: Create Identity Attestation ───────────────────
  console.log("");
  console.log("  [Tx 2] createAttestation() — Notarize agent identity");
  const schemaId      = ethers.keccak256(ethers.toUtf8Bytes("identity.notary.v1"));
  const documentHash  = ethers.keccak256(ethers.toUtf8Bytes(`agent.${agentId}.identity`));
  const expiresAt     = BigInt(Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60); // 1 year
  const attestationTx = await codexIdentity.createAttestation(
    deployer.address,
    documentHash,
    schemaId,
    expiresAt
  );
  const attestationReceipt = await attestationTx.wait();
  // Parse attestationId from event
  const attestationEvent = attestationReceipt!.logs
    .map((log: Log): LogDescription | null => { try { return codexIdentity.interface.parseLog(log); } catch { return null; } })
    .find((e: LogDescription | null) => e?.name === "AttestationCreated");
  const attestationId: string = attestationEvent?.args?.attestationId ?? ethers.ZeroHash;
  console.log(`    schemaId      : ${schemaId}`);
  console.log(`    documentHash  : ${documentHash}`);
  console.log(`    expiresAt     : ${new Date(Number(expiresAt) * 1000).toISOString()}`);
  console.log(`    attestationId : ${attestationId}`);
  console.log(`    Tx Hash       : ${tx(attestationReceipt!.hash)}`);

  // ── Tx 3: Update BAP-578 Agent Metadata ─────────────────
  console.log("");
  console.log("  [Tx 3] updateAgentMetadata() — Set BAP-578 structured metadata");
  const agentMetadata = {
    persona:      '{"role":"sales","tone":"professional","language":"en"}',
    experience:   "AI Sales Agent specialized in Web3 protocol onboarding",
    voiceHash:    "",
    animationURI: "",
    vaultURI:     "ipfs://QmAgentVaultDemo",
    vaultHash:    ethers.keccak256(ethers.toUtf8Bytes("agent.1.vault.v1")),
  };
  const metadataTx = await codexIdentity.updateAgentMetadata(agentId, agentMetadata);
  const metadataReceipt = await metadataTx.wait();
  console.log(`    persona      : ${agentMetadata.persona}`);
  console.log(`    experience   : ${agentMetadata.experience}`);
  console.log(`    Tx Hash      : ${tx(metadataReceipt!.hash)}`);

  // ── Tx 4: Validation Request ─────────────────────────────
  console.log("");
  console.log("  [Tx 4] validationRequest() — Request third-party validation");
  const requestHash = ethers.keccak256(
    ethers.toUtf8Bytes(`validation.${agentId}.${Date.now()}`)
  );
  const requestURI  = "ipfs://QmValidationRequestDemo";
  const validationTx = await validationRegistry.validationRequest(
    deployer.address, // validator = deployer for demo
    agentId,
    requestURI,
    requestHash
  );
  const validationReceipt = await validationTx.wait();
  console.log(`    validatorAddress : ${deployer.address}`);
  console.log(`    requestHash      : ${requestHash}`);
  console.log(`    requestURI       : ${requestURI}`);
  console.log(`    Tx Hash          : ${tx(validationReceipt!.hash)}`);

  // ── Tx 5: Give Feedback (second wallet) ─────────────────
  console.log("");
  console.log("  [Tx 5] giveFeedback() — Submit reputation score from client wallet");

  // Create a fresh client wallet (submitter cannot be agent owner)
  const clientWallet = ethers.Wallet.createRandom().connect(ethers.provider);
  console.log(`    Client wallet    : ${clientWallet.address} (random, funded for demo)`);

  // Fund the client wallet with just enough for one tx (opBNB L2 gas is < 0.0001 tBNB per tx)
  const fundClientTx = await deployer.sendTransaction({
    to: clientWallet.address,
    value: ethers.parseEther("0.0003"),
  });
  await fundClientTx.wait();

  const feedbackTx = await (reputationRegistry.connect(clientWallet) as ReputationRegistry).giveFeedback(
    agentId,        // agentId
    95n,            // value — int128 score (95/100)
    0,              // valueDecimals
    "quality",      // tag1
    "speed",        // tag2
    "https://api.agent-identity.demo", // endpoint (emitted only, not stored)
    "",             // feedbackURI (optional)
    ethers.ZeroHash // feedbackHash (optional)
  );
  const feedbackReceipt = await feedbackTx.wait();
  console.log(`    agentId      : ${agentId}`);
  console.log(`    score        : 95 (tag: quality / speed)`);
  console.log(`    feedbackIndex: 1 (1-indexed per ERC-8004)`);
  console.log(`    Tx Hash      : ${tx(feedbackReceipt!.hash)}`);

  // ─────────────────────────────────────────────────────────
  //  PHASE 3 — Verify On-Chain State
  // ─────────────────────────────────────────────────────────
  section("PHASE 3 — Verifying On-Chain State");

  const agentOwner       = await codexIdentity.ownerOf(agentId);
  const agentState       = await codexIdentity.getState(agentId);
  const attestationValid = await codexIdentity.verifyAttestation(attestationId);
  const reputationCount  = await reputationRegistry.getLastIndex(agentId, clientWallet.address);
  const validationHashes = await validationRegistry.getAgentValidations(agentId);

  console.log(`  ✓ ownerOf(${agentId})             = ${agentOwner}`);
  console.log(`  ✓ getState(${agentId}).status     = ${["Active","Paused","Terminated"][Number(agentState.status)]}`);
  console.log(`  ✓ verifyAttestation()           = ${attestationValid}`);
  console.log(`  ✓ getLastIndex() feedbacks      = ${reputationCount}`);
  console.log(`  ✓ getAgentValidations() count   = ${validationHashes.length}`);

  // ─────────────────────────────────────────────────────────
  //  PHASE 4 — Save Deployment Artifacts
  // ─────────────────────────────────────────────────────────
  section("PHASE 4 — Saving Deployment Artifacts");

  const deployment = {
    network:    "opBNB Testnet",
    chainId:    5611,
    deployedAt: new Date().toISOString(),
    deployer:   deployer.address,
    contracts: {
      CodexIdentity:    identityAddress,
      ReputationRegistry:  reputationAddress,
      ValidationRegistry:  validationAddress,
    },
    transactions: {
      register:          registerReceipt!.hash,
      createAttestation: attestationReceipt!.hash,
      updateMetadata:    metadataReceipt!.hash,
      validationRequest: validationReceipt!.hash,
      giveFeedback:      feedbackReceipt!.hash,
    },
    demo: {
      agentId:       agentId.toString(),
      attestationId: attestationId.toString(),
      clientWallet:  clientWallet.address,
    },
    explorer: EXPLORER,
  };

  const outDir  = path.join(__dirname, "../deployments");
  const outFile = path.join(outDir, "opbnb-testnet.json");
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(outFile, JSON.stringify(deployment, null, 2));
  console.log(`  ✓ Saved to deployments/opbnb-testnet.json`);

  // ─────────────────────────────────────────────────────────
  //  Final Summary
  // ─────────────────────────────────────────────────────────
  console.log("");
  console.log("  ╔══════════════════════════════════════════════════════════╗");
  console.log("  ║                   DEPLOYMENT COMPLETE                    ║");
  console.log("  ╚══════════════════════════════════════════════════════════╝");
  console.log("");
  console.log("  CONTRACTS");
  console.log(`  CodexIdentity   : ${identityAddress}`);
  console.log(`  ReputationRegistry : ${reputationAddress}`);
  console.log(`  ValidationRegistry : ${validationAddress}`);
  console.log("");
  console.log("  ON-CHAIN TRANSACTIONS");
  console.log(`  Tx 1 register()            : ${tx(registerReceipt!.hash)}`);
  console.log(`  Tx 2 createAttestation()   : ${tx(attestationReceipt!.hash)}`);
  console.log(`  Tx 3 updateAgentMetadata() : ${tx(metadataReceipt!.hash)}`);
  console.log(`  Tx 4 validationRequest()   : ${tx(validationReceipt!.hash)}`);
  console.log(`  Tx 5 giveFeedback()        : ${tx(feedbackReceipt!.hash)}`);
  console.log("");
  console.log("  ADD TO YOUR .env:");
  console.log(`  CODEX_IDENTITY_ADDRESS=${identityAddress}`);
  console.log(`  REPUTATION_REGISTRY_ADDRESS=${reputationAddress}`);
  console.log(`  VALIDATION_REGISTRY_ADDRESS=${validationAddress}`);
  console.log("");
}

main().catch((error) => {
  console.error("\n  ✗ Deployment failed:", error.message);
  process.exitCode = 1;
});
