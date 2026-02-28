# Codex ID — Backlog

## Legend
- 🔴 High priority
- 🟡 Medium priority
- 🟢 Low priority / Nice to have
- ✅ Done

---

## Smart Contract

### ✅ Completed
- [x] `CodexIdentity.sol` initial implementation
- [x] Add `block.chainid` to attestation ID hash (replay attack prevention)
- [x] Fix `transferOwnership` to auto-authorize new owner as issuer
- [x] Emit `IssuerAdded`, `IssuerRemoved`, `OwnershipTransferred` events
- [x] Add `getAttestation` and `getSubjectAttestations` to `ICodexIdentity` interface

### 🔴 Pre-Mainnet
- [ ] **Proxy Pattern — Upgradeability (OpenZeppelin UUPS)**
  - Migrate `CodexIdentity.sol` to use OpenZeppelin's `UUPSUpgradeable` pattern
  - Replace `constructor` with `initialize()` function
  - Add `_authorizeUpgrade()` override restricted to owner
  - Deploy `ERC1967Proxy` pointing to the logic contract
  - Ensures all on-chain attestation data is preserved across contract upgrades
  - Recommended lib: `@openzeppelin/contracts-upgradeable`
  - Reference: https://docs.openzeppelin.com/contracts/5.x/api/proxy#UUPSUpgradeable

- [ ] **Migrate access control to OpenZeppelin AccessControl (RBAC)**
  - Replace `mapping(address => bool) authorizedIssuers` with `DEFAULT_ADMIN_ROLE` and `ISSUER_ROLE`
  - Enables more granular role management and standard tooling compatibility
  - Reference: https://docs.openzeppelin.com/contracts/5.x/access-control

- [ ] **Fix NatSpec — standards alignment**
  - Update contract comments from "Implements ERC-8004 and BAP-578" to "Inspired by ERC-8004 attestation patterns"
  - Contract does not fully implement either standard's interface

### 🟡 Post-Hackathon
- [ ] **Add `schemaId` validation**
  - Reject `bytes32(0)` as a valid `schemaId` to prevent accidental misconfigured attestations

- [ ] **Add subject self-revocation**
  - Allow the subject address to revoke their own attestation (GDPR / right to erasure)

- [ ] **Pagination for `getSubjectAttestations`**
  - Add `offset` and `limit` parameters to avoid gas limit issues for agents with many attestations

- [ ] **Expand test coverage**
  - `transferOwnership` happy path and zero address revert
  - `addIssuer` / `removeIssuer` with event assertions
  - Expired attestation returns `false` from `verifyAttestation`
  - `getAttestation` found and not-found cases
  - `getSubjectAttestations` returns correct array

### 🟢 Future / Roadmap
- [ ] **Full ERC-8004 compliance**
  - Implement Identity Registry (ERC-721 based agent NFTs)
  - Implement Reputation Registry (`giveFeedback`, `getSummary`)
  - Implement Validation Registry (`validationRequest`, `validationResponse`)

- [ ] **Full BAP-578 compliance**
  - Implement agent NFT lifecycle (`Status`, `executeAction`, `pause`, `terminate`)
  - Add `logicAddress` delegation via delegatecall
  - Add Learning Module integration (Merkle tree root on-chain)

---

## Backend (NestJS)

### 🔴 In Progress
- [ ] Connect NestJS API to deployed contract ABI from `artifacts/`
- [ ] Implement `POST /attestations` → calls `createAttestation()`
- [ ] Implement `GET /attestations/:id` → calls `getAttestation()`
- [ ] Implement `GET /agents/:address/attestations` → calls `getSubjectAttestations()`
- [ ] Implement `DELETE /attestations/:id` → calls `revokeAttestation()`
- [ ] Implement `GET /attestations/:id/verify` → calls `verifyAttestation()`

### 🟡 Post-Hackathon
- [ ] Index `AttestationCreated` and `AttestationRevoked` events via WebSocket or polling
- [ ] Index `IssuerAdded`, `IssuerRemoved`, `OwnershipTransferred` events for audit trail
- [ ] Store full agent metadata in IPFS and reference `documentHash` on-chain

---

## Infrastructure

### 🟡 Post-Hackathon
- [ ] Deploy to opBNB Mainnet (Chain ID: 204)
- [ ] Set up a Subgraph (The Graph) to index contract events
- [ ] Add contract verification on BNBScan
