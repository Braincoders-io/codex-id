import { expect } from "chai";
import { ethers } from "hardhat";
import { CodexIdentity } from "../typechain-types";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

describe("CodexIdentity", function () {
  let codexIdentity: CodexIdentity;
  let owner: HardhatEthersSigner;
  let issuer: HardhatEthersSigner;
  let subject: HardhatEthersSigner;
  let unauthorized: HardhatEthersSigner;

  const SCHEMA_ID = ethers.keccak256(ethers.toUtf8Bytes("codex.identity.notary.v1"));
  const DOCUMENT_HASH = ethers.keccak256(ethers.toUtf8Bytes("test-document-content"));

  beforeEach(async function () {
    [owner, issuer, subject, unauthorized] = await ethers.getSigners();

    const CodexIdentityFactory = await ethers.getContractFactory("CodexIdentity");
    codexIdentity = await CodexIdentityFactory.deploy();
    await codexIdentity.waitForDeployment();
  });

  describe("Deployment", function () {
    it("should set deployer as owner", async function () {
      expect(await codexIdentity.owner()).to.equal(owner.address);
    });

    it("should authorize deployer as issuer", async function () {
      expect(await codexIdentity.authorizedIssuers(owner.address)).to.be.true;
    });
  });

  describe("Transaction 1: createAttestation", function () {
    it("should create an attestation with valid params", async function () {
      const futureTimestamp = BigInt(Math.floor(Date.now() / 1000) + 86400);

      const tx = await codexIdentity.createAttestation(
        subject.address,
        DOCUMENT_HASH,
        SCHEMA_ID,
        futureTimestamp
      );

      const receipt = await tx.wait();
      expect(receipt).to.not.be.null;

      const event = receipt!.logs[0];
      expect(event).to.not.be.undefined;
    });

    it("should reject zero address subject", async function () {
      const futureTimestamp = BigInt(Math.floor(Date.now() / 1000) + 86400);

      await expect(
        codexIdentity.createAttestation(
          ethers.ZeroAddress,
          DOCUMENT_HASH,
          SCHEMA_ID,
          futureTimestamp
        )
      ).to.be.revertedWithCustomError(codexIdentity, "InvalidSubject");
    });

    it("should reject unauthorized issuers", async function () {
      const futureTimestamp = BigInt(Math.floor(Date.now() / 1000) + 86400);

      await expect(
        codexIdentity.connect(unauthorized).createAttestation(
          subject.address,
          DOCUMENT_HASH,
          SCHEMA_ID,
          futureTimestamp
        )
      ).to.be.revertedWithCustomError(codexIdentity, "OnlyAuthorizedIssuer");
    });
  });

  describe("Transaction 2: revokeAttestation", function () {
    let attestationId: string;

    beforeEach(async function () {
      const futureTimestamp = BigInt(Math.floor(Date.now() / 1000) + 86400);

      const tx = await codexIdentity.createAttestation(
        subject.address,
        DOCUMENT_HASH,
        SCHEMA_ID,
        futureTimestamp
      );

      const receipt = await tx.wait();
      const iface = codexIdentity.interface;
      const log = receipt!.logs.find(
        (l) => l.topics[0] === iface.getEvent("AttestationCreated").topicHash
      );
      const parsed = iface.parseLog({ topics: log!.topics as string[], data: log!.data });
      attestationId = parsed!.args.attestationId;
    });

    it("should revoke an existing attestation", async function () {
      await codexIdentity.revokeAttestation(attestationId);
      const isValid = await codexIdentity.verifyAttestation(attestationId);
      expect(isValid).to.be.false;
    });

    it("should reject revocation by non-issuer", async function () {
      await expect(
        codexIdentity.connect(unauthorized).revokeAttestation(attestationId)
      ).to.be.revertedWithCustomError(codexIdentity, "OnlyIssuer");
    });

    it("should reject double revocation", async function () {
      await codexIdentity.revokeAttestation(attestationId);
      await expect(
        codexIdentity.revokeAttestation(attestationId)
      ).to.be.revertedWithCustomError(codexIdentity, "AttestationAlreadyRevoked");
    });
  });

  describe("verifyAttestation", function () {
    it("should return false for non-existent attestation", async function () {
      const fakeId = ethers.keccak256(ethers.toUtf8Bytes("non-existent"));
      expect(await codexIdentity.verifyAttestation(fakeId)).to.be.false;
    });
  });
});
