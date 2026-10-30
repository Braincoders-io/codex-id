# Codex ID — Decentralized AI Agent Identity & Trust Registry

> BNB Ignite Challenge Hackathon Submission — Built on opBNB Testnet

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/Braincoders-io/codex-id/blob/main/LICENSE)
[![GitHub](https://img.shields.io/badge/GitHub-Braincoders--io%2Fcodex--id-blue?logo=github)](https://github.com/Braincoders-io/codex-id)
[![Website](https://img.shields.io/badge/Website-braincoders.io-green)](https://www.braincoders.io)
[![Sourcify](https://img.shields.io/badge/Sourcify-Exact%20Match-brightgreen)](https://repo.sourcify.dev/5611/0x8E036e205ff434D62F132Cf2471eC868728205Cb)

Codex ID is a decentralized registry for AI agents. Each agent is minted as an NFT with an on-chain identity, attestation-based trust proofs, a reputation score built from client feedback, and third-party validation — all governed by open standards.

---

## Standards Compliance

| Standard | Description | Status |
|---|---|---|
| **ERC-721** | NFT backbone — each AI agent is a unique token | ✅ Full |
| **ERC-8004** | Trustless Agents — Identity, Reputation, Validation registries | ✅ 28/28 |
| **BAP-578** | Non-Fungible Agent (NFA) — lifecycle, logic, funding, metadata | ✅ 17/17 core |
| **EIP-712** | Typed structured data for `setAgentWallet` signature verification | ✅ Full |
| **ERC-1271** | Smart contract wallet signature fallback | ✅ Full |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Codex ID System                         │
├─────────────────────┬────────────────────┬──────────────────────┤
│   CodexIdentity     │ ReputationRegistry │  ValidationRegistry  │
│   (ERC-721 NFT)     │    (ERC-8004)      │     (ERC-8004)       │
│                     │                    │                      │
│ • register()        │ • giveFeedback()   │ • validationRequest()│
│ • setAgentURI()     │ • revokeFeedback() │ • validationResponse()│
│ • setMetadata()     │ • appendResponse() │ • getValidationStatus│
│ • setAgentWallet()  │ • readAllFeedback()│ • getSummary()       │
│ • createAttestation │ • getSummary()     │ • getAgentValidations│
│ • verifyAttestation │ • getLastIndex()   │                      │
│ • pause/unpause/    │                    │                      │
│   terminate()       │                    │                      │
│ • fundAgent()       │                    │                      │
│ • getState()        │                    │                      │
│ • updateAgentMetadata                    │                      │
└─────────────────────┴────────────────────┴──────────────────────┘
         ▲                      ▲                     ▲
         │              reads ownerOf()               │
         └──────────────────────┴─────────────────────┘
                     ERC-721 identity link
```

**Three-registry ERC-8004 pattern:**
- `CodexIdentity` — mints the NFT, stores identity + attestations + BAP-578 state
- `ReputationRegistry` — collects scored feedback from clients (NOT the agent owner)
- `ValidationRegistry` — manages third-party validation requests and responses

---

## Contracts

| Contract | File | Description |
|---|---|---|
| `CodexIdentity` | `contracts/CodexIdentity.sol` | ERC-721 identity NFT + attestations + BAP-578 lifecycle |
| `ReputationRegistry` | `contracts/ReputationRegistry.sol` | Client feedback & reputation scoring |
| `ValidationRegistry` | `contracts/ValidationRegistry.sol` | Third-party validation requests/responses |
| `ICodexIdentity` | `contracts/ICodexIdentity.sol` | Full interface including ERC-8004 + BAP-578 |
| `IReputationRegistry` | `contracts/IReputationRegistry.sol` | ERC-8004 Reputation interface |
| `IValidationRegistry` | `contracts/IValidationRegistry.sol` | ERC-8004 Validation interface |

---

## Setup

### Prerequisites
- Node.js 18+
- `cd contracts && npm install`

### Environment
Copy `.env.example` to `.env` and fill in your key:
```bash
cp contracts/.env.example contracts/.env
```

Required in `contracts/.env`:
```
PRIVATE_KEY=0x<your-64-char-private-key>
```

> Get testnet BNB from: https://opbnb-testnet-faucet.bnbchain.org
> Minimum required for deployment: **0.005 tBNB** (opBNB L2 gas is very cheap)

---

## Commands

All commands run from the `contracts/` directory:

```bash
cd contracts
```

### Compile
```bash
npm run compile
# or
npx hardhat compile
```

### Test (local Hardhat network)
```bash
npm test
# or
npx hardhat test
```

### Deploy to opBNB Testnet
```bash
npm run deploy:testnet
# or
npx hardhat run scripts/deploy-opbnb-testnet.ts --network opbnbTestnet
```

The deploy script runs **4 phases automatically**:
1. Deploy all 3 contracts
2. Execute 5 on-chain demo transactions
3. Verify on-chain state via read calls
4. Save `deployments/opbnb-testnet.json` with all addresses + tx hashes

---

## Deployment — opBNB Testnet

**Network:** opBNB Testnet | **Chain ID:** 5611
**Explorer:** https://testnet.opbnbscan.com
**Deployed:** 2026-03-01
**Deployer:** `0x7d2Fa1Ced7b9574C7B17B3d798Eb30e651A07f1F`

### Live Contract Addresses

| Contract | Address |
|---|---|
| CodexIdentity | [`0x8E036e205ff434D62F132Cf2471eC868728205Cb`](https://testnet.opbnbscan.com/address/0x8E036e205ff434D62F132Cf2471eC868728205Cb) |
| ReputationRegistry | [`0x1C32d4625916a23789C635861A49E4E8Aed13E6e`](https://testnet.opbnbscan.com/address/0x1C32d4625916a23789C635861A49E4E8Aed13E6e) |
| ValidationRegistry | [`0x89D9e3e42cD8655eb94e303ec0Ab7307dcAdDB2F`](https://testnet.opbnbscan.com/address/0x89D9e3e42cD8655eb94e303ec0Ab7307dcAdDB2F) |

### Live On-Chain Transactions

| # | Function | Tx Hash |
|---|---|---|
| 1 | `register()` — Mint AI agent NFT (tokenId=1) | [0x3b81d7cd...](https://testnet.opbnbscan.com/tx/0x3b81d7cdf6b3adf6367209ee5d83a285b9f9e7b1ecfab0afb91aedc676bd9774) |
| 2 | `createAttestation()` — Notarize identity (expires 2027-03-01) | [0x9f815c6a...](https://testnet.opbnbscan.com/tx/0x9f815c6aabae231ef68d108e1acf536fc068dbad5891a42c965df44cdfcaf411) |
| 3 | `updateAgentMetadata()` — Set BAP-578 persona/experience/vault | [0xa87c059f...](https://testnet.opbnbscan.com/tx/0xa87c059f4ccd896fa9744dfdf97eb990ffb68fc8c8ad277ae08de339aebebde1) |
| 4 | `validationRequest()` — Request 3rd-party validator assessment | [0x09f62bcf...](https://testnet.opbnbscan.com/tx/0x09f62bcf005455e8139576ab13c3777426940acfbcbd7bccccc05e2630f621f1) |
| 5 | `giveFeedback()` — Submit 95/100 score from client wallet | [0x9553c611...](https://testnet.opbnbscan.com/tx/0x9553c61118eda023feeb6118eb2085abbdb207cdde31355a7cc1e218d030ed6c) |

### On-Chain Verification Results (Phase 3)

```
✓ ownerOf(1)             = 0x7d2Fa1Ced7b9574C7B17B3d798Eb30e651A07f1F
✓ getState(1).status     = Active
✓ verifyAttestation()    = true
✓ getLastIndex() feedbacks = 1
✓ getAgentValidations() count = 1
```

### Source Code Verification

All three contracts are verified on **opBNBScan** and on **[Sourcify](https://sourcify.dev)**,
both reporting an **exact match** on runtime and creation bytecode. The source in this
repository compiles byte-for-byte to the code deployed on opBNB, metadata included.

| Contract | opBNBScan | Sourcify | Deployment tx | Block |
|---|---|---|---|---|
| CodexIdentity | [Verified](https://testnet.opbnbscan.com/address/0x8E036e205ff434D62F132Cf2471eC868728205Cb#code) | [Exact Match](https://repo.sourcify.dev/5611/0x8E036e205ff434D62F132Cf2471eC868728205Cb) | [0x90ad7529...](https://testnet.opbnbscan.com/tx/0x90ad7529860e6ff8cc77f558487181cdbf1d1c816bd497cfb318ee8db6ff5068) | 134,229,776 |
| ReputationRegistry | [Verified](https://testnet.opbnbscan.com/address/0x1C32d4625916a23789C635861A49E4E8Aed13E6e#code) | [Exact Match](https://repo.sourcify.dev/5611/0x1C32d4625916a23789C635861A49E4E8Aed13E6e) | [0x31e74716...](https://testnet.opbnbscan.com/tx/0x31e74716ef6462771c63f6fca87254cf0d288d6a76013d15aafcad831360dd49) | 134,229,786 |
| ValidationRegistry | [Verified](https://testnet.opbnbscan.com/address/0x89D9e3e42cD8655eb94e303ec0Ab7307dcAdDB2F#code) | [Exact Match](https://repo.sourcify.dev/5611/0x89D9e3e42cD8655eb94e303ec0Ab7307dcAdDB2F) | [0x8a6a2fae...](https://testnet.opbnbscan.com/tx/0x8a6a2fae3c326f28e6afea94f28d7e05356851fadf83ce0a57d32b2d568a9e88) | 134,229,795 |

Verified 2026-10-29 · `solc 0.8.24+commit.e11b9ed9` · optimizer on (200 runs) · viaIR · EVM `paris`

#### Check it yourself

This asks Sourcify directly — nothing of ours is in the path:

```bash
curl -s https://sourcify.dev/server/v2/contract/5611/0x8E036e205ff434D62F132Cf2471eC868728205Cb
```

Look for `"match": "exact_match"`. To confirm the verified source is the same source you are
reading here, compare Sourcify's stored files against this repository:

```bash
curl -s "https://sourcify.dev/server/v2/contract/5611/0x8E036e205ff434D62F132Cf2471eC868728205Cb?fields=sources" \
  | python3 -c "import json,sys;[open('/tmp/'+k.split('/')[-1],'w').write(v['content']) for k,v in json.load(sys.stdin)['sources'].items()]"
diff /tmp/CodexIdentity.sol contracts/contracts/CodexIdentity.sol && echo "identical"
```

#### opbnbscan

opbnbscan runs its own verification database and does not index Sourcify, so it is verified
there separately. It needs a free API key from [NodeReal](https://nodereal.io) (the company
that operates opbnbscan); `contracts/hardhat.config.ts` contains the `customChains` entry and
reads the key from `NODEREAL_API_KEY`:

```bash
# add NODEREAL_API_KEY=... to contracts/.env first
cd contracts
npx hardhat verify --network opbnbTestnet 0x8E036e205ff434D62F132Cf2471eC868728205Cb
npx hardhat verify --network opbnbTestnet 0x1C32d4625916a23789C635861A49E4E8Aed13E6e 0x8E036e205ff434D62F132Cf2471eC868728205Cb
npx hardhat verify --network opbnbTestnet 0x89D9e3e42cD8655eb94e303ec0Ab7307dcAdDB2F 0x8E036e205ff434D62F132Cf2471eC868728205Cb
```

Note: opBNB is not covered by Etherscan's multichain (v2) API and `opbnb-testnet.bscscan.com`
does not resolve, so NodeReal is the only route to an opbnbscan badge.

---

## Verify It Yourself

Every claim below is checkable from a clean clone. **No private key is required** for any
command in this section — the read-only scripts run with no `.env` at all.

```bash
git clone https://github.com/Braincoders-io/codex-id && cd codex-id/contracts && npm install
```

If your network blocks the default opBNB RPC, point it elsewhere — any opBNB testnet endpoint
works, and no other change is needed:

```bash
export OPBNB_TESTNET_RPC=https://opbnb-testnet-rpc.publicnode.com
```

### 1. The platform check — one command per agent

This is the question a platform asks before letting an agent act: *who owns it, is that owner
verified, is it still active, and what is its track record?*

```bash
AGENT_ID=2 npx hardhat run scripts/check-agent.ts --network opbnbTestnet
```

```
  Agent #2  —  opBNB Testnet (chainId 5611)

    owner            0x7d2Fa1Ced7b9574C7B17B3d798Eb30e651A07f1F
    owner verified   true  (attestation 0xdd5e860d…)
    attested by      0xe8FA7c7046c2B0e099EDb554Ff2B8bABf5c1b5F1  (independent of owner)
    status           Active
    reputation       92/100  from 1 review(s)

    DECISION         ALLOWED   (policy: Active + owner verified + score >= 80)
```

The `attested by` line prints **⚠ SELF-ATTESTED** if an owner ever attests to itself, so a
circular trust claim is visible rather than hidden.

### 2. The live state

| Agent | Name | Status | Owner verified | Score | Decision |
|---|---|---|---|---|---|
| #1 | Demo agent | Active | yes | 95 | ALLOWED |
| #2 | Sales Agent | Active | yes | 92 | ALLOWED |
| #3 | Marketing Agent | Active | yes | 88 | ALLOWED |
| #4 | Support Agent | **Paused** | yes | 91 | **DENIED** |

Agent #4 is verified and well reviewed. It is denied **only** because its owner paused it —
the kill switch isolated from every other signal.

```bash
npx hardhat run scripts/stats.ts --network opbnbTestnet
```

### 3. Owner verification is per company, not per agent

Attestations are keyed by **address**, so one company-level attestation covers every agent
that company owns. Agents #2, #3 and #4 have no attestation of their own — they inherit
`0xdd5e860d…`, issued to the owning wallet.

The attestation records only a hash. The document it attests to is in this repository, so
anyone can recompute that hash and compare it to the chain:

```bash
node -e '
const {ethers}=require("ethers"), fs=require("fs");
const p=new ethers.JsonRpcProvider("https://opbnb-testnet-rpc.publicnode.com");
const c=new ethers.Contract("0x8E036e205ff434D62F132Cf2471eC868728205Cb",
  ["function getAttestation(bytes32) view returns (address issuer,address subject,bytes32 documentHash,bytes32 schemaId,uint64 createdAt,uint64 expiresAt,bool revoked)"],p);
c.getAttestation("0xdd5e860d1d0f3880a33bf814823823694974906135e1bb15e446cfbe3ca36d05").then(a=>{
  const local=ethers.keccak256(fs.readFileSync("attestations/braincoders-company-verification.txt"));
  console.log("on-chain :",a.documentHash);
  console.log("this repo:",local);
  console.log("match    :",a.documentHash===local);
});'
```

### 4. The agent wallet is bound by signature

`setAgentWallet` only succeeds if the wallet being bound signed an EIP-712 message consenting
to it. The owner pays the gas; the wallet never needs funds. `_update` clears the binding on
transfer, so selling an agent cannot leave payments flowing to the previous owner.

```bash
node -e '
const {ethers}=require("ethers");
const p=new ethers.JsonRpcProvider("https://opbnb-testnet-rpc.publicnode.com");
new ethers.Contract("0x8E036e205ff434D62F132Cf2471eC868728205Cb",
  ["function getAgentWallet(uint256) view returns (address)"],p)
  .getAgentWallet(1).then(w=>console.log("agent #1 payment wallet:",w));'
```

### 5. Source code

Both registries report an exact match — see [Source Code Verification](#source-code-verification)
above for the links and the byte-for-byte comparison against this repository.

### Scope and limits

Stated plainly, so nothing here is read as more than it is:

- **This is opBNB testnet.** No mainnet deployment exists yet.
- **Dactilar is currently its own authorised issuer.** The architecture separates the issuer
  from the agent owner, and the registry shows which issuer signed off, so anyone can judge
  whether to trust them. At public launch that role moves to a licensed KYB provider.
- **Reputation scores are seeded demo data**, submitted from a wallet created for the purpose
  (see `scripts/seed-demo-state.ts`, which says so in its header). The feedback mechanism is
  real and on-chain; the reviewers are not customers.
- **`executeAction` is not implemented.** BAP-578 lifecycle (pause / unpause / terminate),
  structs and state are implemented; the execution hook reverts by design for now.
- **The contracts are not upgradeable** and have not had an external security audit.

---

## On-Chain Transactions (Demo Flow)

The deploy script executes these 5 transactions to prove the full system works:

| # | Function | Contract | What it does |
|---|---|---|---|
| 1 | `register(agentURI)` | CodexIdentity | Mints the AI agent as an ERC-721 NFT |
| 2 | `createAttestation(subject, docHash, schemaId, expiresAt)` | CodexIdentity | Creates a notarized identity attestation valid for 1 year |
| 3 | `updateAgentMetadata(tokenId, metadata)` | CodexIdentity | Sets BAP-578 structured metadata (persona, experience, vault) |
| 4 | `validationRequest(validator, agentId, requestURI, requestHash)` | ValidationRegistry | Requests a third-party validator assessment |
| 5 | `giveFeedback(agentId, 95, 0, "quality", "speed", ...)` | ReputationRegistry | Submits a 95/100 score from a separate client wallet |

> **Note on Tx 5:** The spec requires the feedback submitter to NOT be the agent owner.
> The script creates a random wallet, funds it 0.001 tBNB for gas, then submits feedback from it.

Each transaction hash is clickable on https://testnet.opbnbscan.com and shows:
- Full function call + decoded parameters
- Events emitted
- Gas used
- Block confirmation

---

## Checking Deployed Contracts on opBNBScan

1. Go to https://testnet.opbnbscan.com
2. Paste a contract address from `deployments/opbnb-testnet.json`
3. Click the **"Contract"** tab to see verified source code (after running `verify`)
4. Click **"Read Contract"** to call view functions
5. Click **"Write Contract"** (connect MetaMask) to send transactions manually
6. Click **"Events"** to see all emitted events

To check a specific transaction:
- Paste any tx hash from the deploy output into https://testnet.opbnbscan.com/tx/<hash>

---

## Key Concepts

**Agent as NFT:** When you call `register()`, the contract mints an ERC-721 token. The `tokenId` IS the `agentId`. Whoever holds the NFT owns the agent and can update its metadata, set its wallet, pause/terminate it, and respond to feedback.

**Attestations:** An authorized issuer (the deployer by default) calls `createAttestation(subject, documentHash, schemaId, expiresAt)`. This creates a tamper-proof on-chain proof that a real-world identity document was verified. Anyone can call `verifyAttestation(id)` to check it.

**Reputation:** Third-party clients call `giveFeedback(agentId, score, ...)` to submit scored reviews. The agent owner can call `appendResponse()` to reply. All feedback is permanently on-chain.

**Validation:** The agent owner calls `validationRequest(validator, agentId, ...)` to request a third-party assessment. The validator calls `validationResponse(requestHash, score, ...)` to respond. Scores are 0–100.

**BAP-578 Lifecycle:** Agents have three states: `Active` → `Paused` → `Active` (reversible), or `Active/Paused` → `Terminated` (irreversible). Only the NFT owner can terminate. BNB funded via `fundAgent()` is returned to the owner on termination.

---

## Project Structure

```
codex-id/
├── contracts/                  # Hardhat project
│   ├── contracts/              # Solidity source
│   │   ├── CodexIdentity.sol
│   │   ├── ICodexIdentity.sol
│   │   ├── ReputationRegistry.sol
│   │   ├── IReputationRegistry.sol
│   │   ├── ValidationRegistry.sol
│   │   └── IValidationRegistry.sol
│   ├── scripts/
│   │   └── deploy-opbnb-testnet.ts   # Full 4-phase deploy script
│   ├── test/
│   │   └── CodexIdentity.test.ts     # Unit tests (Hardhat local network)
│   ├── deployments/
│   │   └── opbnb-testnet.json        # Generated after deploy
│   ├── hardhat.config.ts
│   └── package.json
├── backend-nestjs/             # NestJS API backend
├── dashboard-lovable/          # Frontend dashboard
└── workflows-n8n/             # n8n automation workflows
```

---

## Built With

- [Hardhat](https://hardhat.org) — Solidity build & deploy
- [OpenZeppelin v5](https://openzeppelin.com/contracts/) — ERC-721, EIP-712, ERC-1271
- [opBNB](https://opbnb.bnbchain.org) — OP Stack L2 on BNB Chain
- [ERC-8004](https://eips.ethereum.org/EIPS/eip-8004) — Trustless Agents standard
- [BAP-578](https://github.com/bnb-chain/BEPs/blob/master/BAPs/BAP-578.md) — Non-Fungible Agent standard

---

## Team

Built by [Braincoders](https://www.braincoders.io) for the BNB Ignite Challenge.

---

## License

MIT — Copyright (c) 2026 Braincoders
