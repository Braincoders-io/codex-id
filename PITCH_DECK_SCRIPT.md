# Codex ID — Pitch Deck Script
## BNB Ignite Challenge

> Paste each slide into Canva / Google Slides.
> Suggested theme: dark background (#0D0D0D), gold accent (#F0B90B — BNB yellow), white text.
> Target: 8–10 slides, ~3 min read time.

---

## SLIDE 1 — Cover

**Title:** Codex ID
**Subtitle:** Decentralized Identity & Trust Registry for AI Agents
**Tag:** BNB Ignite Challenge — Built on opBNB
**Logo area:** [Your logo or a simple robot + chain icon]

---

## SLIDE 2 — The Problem

**Title:** AI Agents Have No Identity

**3 bullet points (large, bold):**
- ❌ No verifiable on-chain identity — anyone can fake an AI agent
- ❌ No trustless reputation — no way to know if an agent is reliable
- ❌ No standard lifecycle — agents can't be paused, audited, or terminated on-chain

**Bottom stat line:**
> Billions of AI agent interactions will happen on-chain in 2025–2026 — with zero trust infrastructure.

---

## SLIDE 3 — The Solution

**Title:** Codex ID gives every AI agent a permanent on-chain identity

**Visual:** 3-column layout

| 🪪 Identity | ⭐ Reputation | ✅ Validation |
|---|---|---|
| Each agent minted as ERC-721 NFT | Clients submit scored feedback | Third-party validators assess agents |
| Attestations notarize real-world proofs | Agent responds on-chain | 0–100 score stored permanently |
| BAP-578 lifecycle: Active / Paused / Terminated | Aggregate trust score queryable by anyone | Anyone can verify instantly |

**Bottom line:**
> One NFT. Three registries. Full trust stack.

---

## SLIDE 4 — How It Works

**Title:** The Three-Registry Architecture (ERC-8004)

**Visual:** Flow diagram (describe for designer)
```
User calls register()
      ↓
CodexIdentity mints NFT → agentId = tokenId
      ↓
        ┌─────────────────┬──────────────────────┐
        ▼                 ▼                      ▼
  Identity            Reputation            Validation
  Attestations        Client Feedback       Third-Party Score
  BAP-578 State       getSummary()          getSummary()
  Agent Wallet        appendResponse()      validationResponse()
```

**Key insight callout:**
> The NFT IS the agent. Transfer the NFT = transfer ownership of identity, reputation, and all metadata.

---

## SLIDE 5 — Standards We Implement

**Title:** Built on Open Standards — Not Proprietary

**Table:**
| Standard | What It Does | Our Status |
|---|---|---|
| ERC-721 | NFT backbone — each agent is a unique token | ✅ Full |
| ERC-8004 | Trustless Agents — 3-registry pattern | ✅ 28/28 requirements |
| BAP-578 | Non-Fungible Agent — lifecycle + metadata | ✅ 17/17 core |
| EIP-712 | Typed signature for agent wallet verification | ✅ Full |
| ERC-1271 | Smart contract wallet support | ✅ Full |

**Bottom callout:**
> First project to implement ERC-8004 + BAP-578 together on opBNB.

---

## SLIDE 6 — Live on opBNB Testnet

**Title:** Already Deployed — 5 Real Transactions on-chain

**Contract addresses (monospace font):**
```
CodexIdentity      0x8E036e205ff434D62F132Cf2471eC868728205Cb
ReputationRegistry 0x1C32d4625916a23789C635861A49E4E8Aed13E6e
ValidationRegistry 0x89D9e3e42cD8655eb94e303ec0Ab7307dcAdDB2F
```

**5 transactions (icon + function name + one-liner):**
1. 🔑 `register()` — AI agent minted as NFT (tokenId = 1)
2. 📜 `createAttestation()` — Identity notarized, valid until 2027
3. 🤖 `updateAgentMetadata()` — BAP-578 persona + vault set
4. 🔍 `validationRequest()` — 3rd-party validation requested
5. ⭐ `giveFeedback()` — 95/100 score from independent client wallet

**Bottom:** `testnet.opbnbscan.com` [small logo]

---

## SLIDE 7 — Why opBNB

**Title:** opBNB Makes On-Chain AI Trust Viable

**3 points:**
- ⚡ **Ultra-low fees** — < $0.001 per transaction. Every feedback, attestation, and validation can be on-chain affordably.
- 🔗 **EVM compatible** — All OpenZeppelin standards (ERC-721, EIP-712, ERC-1271) work natively.
- 🌐 **BNB ecosystem alignment** — BAP-578 is a BNB Application Proposal. We're building exactly where the ecosystem is heading.

**Visual:** opBNB logo + "OP Stack L2 on BNB Chain"

---

## SLIDE 8 — Use Cases

**Title:** Who Uses Codex ID?

**3 cards:**

🏦 **DeFi Protocols**
> Verify an AI trading agent's identity and track record before granting permissions to manage funds.

🛒 **Marketplaces**
> Buyers check an AI sales agent's reputation score and attestations before engaging in a deal.

🏗️ **Agent Platforms**
> List only verified agents. Use `verifyAttestation()` and `getSummary()` as trust gatekeeping.

---

## SLIDE 9 — Traction & Roadmap

**Title:** Where We Are

**Left column — Done ✅**
- Smart contracts deployed on opBNB Testnet
- ERC-8004 full compliance (28/28)
- BAP-578 NFA core compliance (17/17)
- 5 live on-chain demo transactions
- NestJS backend integration
- n8n automation workflow

**Right column — Roadmap 🗺️**
- Q2 2026: Mainnet deployment + contract verification
- Q2 2026: `executeAction` delegatecall implementation
- Q3 2026: Dashboard UI for agent registry browsing
- Q3 2026: BAP-578 Dual-Path Memory (Merkle learning tree)
- Q4 2026: Cross-chain identity bridging

---

## SLIDE 10 — Close

**Title:** Every AI Agent Deserves an Identity

**Big quote:**
> "In a world where AI agents transact autonomously, Codex ID is the trust layer that makes it safe."

**3 links:**
- 🔗 GitHub: https://github.com/Braincoders-io/codex-id
- 🔗 Explorer: testnet.opbnbscan.com
- 🔗 Demo Video: https://www.youtube.com/watch?v=pdTY9bV6kPE

**Team:** [Braincoders](https://www.braincoders.io)
**Call to action:** Built for BNB Ignite Challenge — opBNB Track

---

## DESIGN TIPS

- **Fonts:** Use a clean sans-serif (Inter, Outfit, or Space Grotesk)
- **Colors:** #0D0D0D background, #F0B90B (BNB gold) for accents, white for text
- **Icons:** Use Phosphor Icons or Lucide (free) for the bullet point icons
- **Slides 6:** screenshot from testnet.opbnbscan.com showing real tx hashes
- **Slide 4:** use a simple Figma/Canva flowchart, not code

**Fastest option:** Use Canva → search "Web3 Pitch Deck" dark template → replace content.
Takes ~20 minutes with copy-paste from this script.
