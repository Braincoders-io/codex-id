// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "./ICodexIdentity.sol";

/**
 * @title CodexIdentity
 * @author Braincoders
 * @notice ERC-8004 Identity Registry and BAP-578 Non-Fungible Agent (NFA).
 *         Each AI agent is represented as an ERC-721 NFT whose URI resolves
 *         to an agent registration file (off-chain IPFS / HTTPS).
 *         Includes a Codex ID attestation extension for notarized identity proofs.
 *
 * @dev Extends ERC-721 with URIStorage and EIP-712 for agent wallet verification.
 *      Implements the full ERC-8004 Identity Registry standard.
 *      Implements the BAP-578 NFA core interface (lifecycle, logic, funding, state, metadata).
 *      executeAction is stubbed — delegatecall logic is a post-v1 roadmap item.
 *      BAP-578 events use tokenId instead of agent address (NFT-registry adaptation).
 *      Part of the three-registry ERC-8004 architecture alongside
 *      ReputationRegistry and ValidationRegistry.
 *
 *      agentId     = ERC-721 tokenId (auto-incremented from 1)
 *      agentURI    = ERC-721 tokenURI (resolves to agent registration file)
 *      agentWallet = reserved metadata key for the agent's payment address
 */
contract CodexIdentity is ICodexIdentity, ERC721URIStorage, EIP712 {

    // ──────────────────────────────────────────────
    //  Constants
    // ──────────────────────────────────────────────

    bytes32 private constant SET_AGENT_WALLET_TYPEHASH =
        keccak256("SetAgentWallet(uint256 agentId,address newWallet,uint256 deadline)");

    bytes32 private constant AGENT_WALLET_KEY = keccak256("agentWallet");

    bytes4 private constant ERC1271_MAGIC_VALUE = 0x1626ba7e;

    // ──────────────────────────────────────────────
    //  Types
    // ──────────────────────────────────────────────

    struct Attestation {
        address issuer;
        address subject;
        bytes32 documentHash;
        bytes32 schemaId;
        uint64  createdAt;
        uint64  expiresAt;
        bool    revoked;
    }

    // ──────────────────────────────────────────────
    //  State — Admin
    // ──────────────────────────────────────────────

    /// @notice Contract admin. Can manage authorized issuers.
    address public owner;

    /// @notice Authorized issuers that can create attestations.
    mapping(address => bool) public authorizedIssuers;

    // ──────────────────────────────────────────────
    //  State — ERC-8004 Identity
    // ──────────────────────────────────────────────

    /// @notice Auto-incrementing counter for agentId (ERC-721 tokenId).
    uint256 private _tokenIdCounter;

    /// @notice agentId => metadataKey (keccak256 hashed) => metadataValue.
    mapping(uint256 => mapping(bytes32 => bytes)) private _metadata;

    // ──────────────────────────────────────────────
    //  State — BAP-578
    // ──────────────────────────────────────────────

    /// @notice agentId => lifecycle status. Defaults to Active (enum value 0).
    mapping(uint256 => Status) private _agentStatus;

    /// @notice agentId => optional logic contract address for executeAction.
    mapping(uint256 => address) private _logicAddress;

    /// @notice agentId => BNB balance deposited via fundAgent().
    mapping(uint256 => uint256) private _agentBalance;

    /// @notice agentId => block.timestamp of last executeAction call.
    mapping(uint256 => uint256) private _lastActionTimestamp;

    /// @notice agentId => BAP-578 structured metadata.
    mapping(uint256 => AgentMetadata) private _agentMetadata;

    // ──────────────────────────────────────────────
    //  State — Attestations (Codex ID extension)
    // ──────────────────────────────────────────────

    /// @notice Nonce for deterministic attestation ID generation.
    uint256 private _nonce;

    /// @notice attestationId => Attestation data.
    mapping(bytes32 => Attestation) private _attestations;

    /// @notice subject address => list of attestation IDs.
    mapping(address => bytes32[]) private _subjectAttestations;

    // ──────────────────────────────────────────────
    //  Errors
    // ──────────────────────────────────────────────

    error OnlyOwner();
    error OnlyAuthorizedIssuer();
    error OnlyIssuer();
    error AgentNotOwner();
    error InvalidSubject();
    error InvalidDocumentHash();
    error InvalidExpiration();
    error AttestationNotFound();
    error AttestationAlreadyRevoked();
    error ReservedMetadataKey();
    error InvalidSignature();
    error SignatureExpired();
    // BAP-578 errors
    error AgentPaused();
    error AgentTerminated();
    error InvalidStatusTransition();
    error ExecuteActionNotImplemented();
    error WithdrawFailed();

    // ──────────────────────────────────────────────
    //  Modifiers
    // ──────────────────────────────────────────────

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    modifier onlyAuthorizedIssuer() {
        if (!authorizedIssuers[msg.sender]) revert OnlyAuthorizedIssuer();
        _;
    }

    modifier onlyAgentOwnerOrOperator(uint256 agentId) {
        address tokenOwner = ownerOf(agentId);
        if (
            msg.sender != tokenOwner &&
            !isApprovedForAll(tokenOwner, msg.sender) &&
            getApproved(agentId) != msg.sender
        ) revert AgentNotOwner();
        _;
    }

    // ──────────────────────────────────────────────
    //  Constructor
    // ──────────────────────────────────────────────

    constructor()
        ERC721("Codex ID Agent", "CXID") // TODO: update name/symbol to final brand before mainnet
        EIP712("CodexIdentity", "1")
    {
        owner = msg.sender;
        authorizedIssuers[msg.sender] = true;
    }

    // ──────────────────────────────────────────────
    //  Admin
    // ──────────────────────────────────────────────

    /// @notice Add an authorized issuer.
    function addIssuer(address issuer) external onlyOwner {
        authorizedIssuers[issuer] = true;
        emit IssuerAdded(issuer);
    }

    /// @notice Remove an authorized issuer.
    function removeIssuer(address issuer) external onlyOwner {
        authorizedIssuers[issuer] = false;
        emit IssuerRemoved(issuer);
    }

    /// @notice Transfer contract admin ownership.
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidSubject();
        authorizedIssuers[newOwner] = true;
        authorizedIssuers[owner] = false;
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ──────────────────────────────────────────────
    //  ERC-8004: Registration
    // ──────────────────────────────────────────────

    /// @inheritdoc ICodexIdentity
    function register(
        string calldata agentURI,
        MetadataEntry[] calldata metadata
    ) external returns (uint256 agentId) {
        agentId = _mintAgent(agentURI);
        for (uint256 i = 0; i < metadata.length; i++) {
            if (keccak256(bytes(metadata[i].metadataKey)) == AGENT_WALLET_KEY) {
                revert ReservedMetadataKey();
            }
            bytes32 keyHash = keccak256(bytes(metadata[i].metadataKey));
            _metadata[agentId][keyHash] = metadata[i].metadataValue;
            emit MetadataSet(
                agentId,
                metadata[i].metadataKey,
                metadata[i].metadataKey,
                metadata[i].metadataValue
            );
        }
    }

    /// @inheritdoc ICodexIdentity
    function register(string calldata agentURI) external returns (uint256 agentId) {
        agentId = _mintAgent(agentURI);
    }

    /// @inheritdoc ICodexIdentity
    function register() external returns (uint256 agentId) {
        agentId = _mintAgent("");
    }

    /// @inheritdoc ICodexIdentity
    function setAgentURI(
        uint256 agentId,
        string calldata newURI
    ) external onlyAgentOwnerOrOperator(agentId) {
        if (_agentStatus[agentId] == Status.Terminated) revert AgentTerminated();
        _setTokenURI(agentId, newURI);
        emit URIUpdated(agentId, newURI, msg.sender);
        emit MetadataUpdated(agentId, newURI); // BAP-578
    }

    // ──────────────────────────────────────────────
    //  ERC-8004: On-Chain Metadata
    // ──────────────────────────────────────────────

    /// @inheritdoc ICodexIdentity
    function getMetadata(
        uint256 agentId,
        string memory metadataKey
    ) external view returns (bytes memory) {
        return _metadata[agentId][keccak256(bytes(metadataKey))];
    }

    /// @inheritdoc ICodexIdentity
    function setMetadata(
        uint256 agentId,
        string memory metadataKey,
        bytes memory metadataValue
    ) external onlyAgentOwnerOrOperator(agentId) {
        if (keccak256(bytes(metadataKey)) == AGENT_WALLET_KEY) revert ReservedMetadataKey();
        _metadata[agentId][keccak256(bytes(metadataKey))] = metadataValue;
        emit MetadataSet(agentId, metadataKey, metadataKey, metadataValue);
    }

    // ──────────────────────────────────────────────
    //  ERC-8004: Agent Wallet
    // ──────────────────────────────────────────────

    /// @inheritdoc ICodexIdentity
    function setAgentWallet(
        uint256 agentId,
        address newWallet,
        uint256 deadline,
        bytes calldata signature
    ) external onlyAgentOwnerOrOperator(agentId) {
        if (block.timestamp > deadline) revert SignatureExpired();

        bytes32 structHash = keccak256(
            abi.encode(SET_AGENT_WALLET_TYPEHASH, agentId, newWallet, deadline)
        );
        bytes32 hash = _hashTypedDataV4(structHash);

        // Try EOA — ECDSA recovery
        address recovered = ECDSA.recover(hash, signature);
        if (recovered == newWallet) {
            _setAgentWalletInternal(agentId, newWallet);
            return;
        }

        // Try smart contract wallet — ERC-1271
        if (newWallet.code.length > 0) {
            try IERC1271(newWallet).isValidSignature(hash, signature) returns (bytes4 magic) {
                if (magic == ERC1271_MAGIC_VALUE) {
                    _setAgentWalletInternal(agentId, newWallet);
                    return;
                }
            } catch {}
        }

        revert InvalidSignature();
    }

    /// @inheritdoc ICodexIdentity
    function getAgentWallet(uint256 agentId) external view returns (address) {
        bytes memory data = _metadata[agentId][AGENT_WALLET_KEY];
        if (data.length == 0) return address(0);
        return abi.decode(data, (address));
    }

    /// @inheritdoc ICodexIdentity
    function unsetAgentWallet(
        uint256 agentId
    ) external onlyAgentOwnerOrOperator(agentId) {
        _setAgentWalletInternal(agentId, address(0));
    }

    // ──────────────────────────────────────────────
    //  BAP-578: Lifecycle Management
    // ──────────────────────────────────────────────

    /// @inheritdoc ICodexIdentity
    function pause(uint256 tokenId) external onlyAgentOwnerOrOperator(tokenId) {
        if (_agentStatus[tokenId] != Status.Active) revert InvalidStatusTransition();
        _agentStatus[tokenId] = Status.Paused;
        emit StatusChanged(tokenId, Status.Paused);
    }

    /// @inheritdoc ICodexIdentity
    function unpause(uint256 tokenId) external onlyAgentOwnerOrOperator(tokenId) {
        if (_agentStatus[tokenId] != Status.Paused) revert InvalidStatusTransition();
        _agentStatus[tokenId] = Status.Active;
        emit StatusChanged(tokenId, Status.Active);
    }

    /// @inheritdoc ICodexIdentity
    /// @dev Only the NFT owner (not operator) can terminate — it is irreversible.
    ///      Returns any funded BNB to the caller before status is finalised.
    ///      NOTE: Uses a push pattern. If owner is a contract without receive(),
    ///      termination will revert — call getState() first to drain balance separately.
    function terminate(uint256 tokenId) external {
        if (msg.sender != ownerOf(tokenId)) revert AgentNotOwner();
        if (_agentStatus[tokenId] == Status.Terminated) revert InvalidStatusTransition();

        _agentStatus[tokenId] = Status.Terminated;
        emit StatusChanged(tokenId, Status.Terminated);

        // Return funded balance to owner
        uint256 bal = _agentBalance[tokenId];
        if (bal > 0) {
            _agentBalance[tokenId] = 0;
            (bool ok,) = msg.sender.call{value: bal}("");
            if (!ok) revert WithdrawFailed();
        }
    }

    // ──────────────────────────────────────────────
    //  BAP-578: Logic & Funding
    // ──────────────────────────────────────────────

    /// @inheritdoc ICodexIdentity
    /// @dev Stub — always reverts with ExecuteActionNotImplemented.
    ///      Status guard is in place for when delegatecall is implemented post-v1.
    function executeAction(uint256 tokenId, bytes calldata /*data*/) external {
        if (_agentStatus[tokenId] == Status.Paused)     revert AgentPaused();
        if (_agentStatus[tokenId] == Status.Terminated) revert AgentTerminated();
        revert ExecuteActionNotImplemented();
    }

    /// @inheritdoc ICodexIdentity
    function setLogicAddress(
        uint256 tokenId,
        address newLogic
    ) external onlyAgentOwnerOrOperator(tokenId) {
        if (_agentStatus[tokenId] == Status.Terminated) revert AgentTerminated();
        address oldLogic = _logicAddress[tokenId];
        _logicAddress[tokenId] = newLogic;
        emit LogicUpgraded(tokenId, oldLogic, newLogic);
    }

    /// @inheritdoc ICodexIdentity
    function fundAgent(uint256 tokenId) external payable {
        if (_agentStatus[tokenId] == Status.Terminated) revert AgentTerminated();
        ownerOf(tokenId); // reverts with ERC721NonexistentToken if token doesn't exist
        _agentBalance[tokenId] += msg.value;
        emit AgentFunded(tokenId, msg.sender, msg.value);
    }

    // ──────────────────────────────────────────────
    //  BAP-578: State & Metadata
    // ──────────────────────────────────────────────

    /// @inheritdoc ICodexIdentity
    function getState(uint256 tokenId) external view returns (State memory) {
        return State({
            balance:             _agentBalance[tokenId],
            status:              _agentStatus[tokenId],
            owner:               ownerOf(tokenId),
            logicAddress:        _logicAddress[tokenId],
            lastActionTimestamp: _lastActionTimestamp[tokenId]
        });
    }

    /// @inheritdoc ICodexIdentity
    function getAgentMetadata(uint256 tokenId) external view returns (AgentMetadata memory) {
        return _agentMetadata[tokenId];
    }

    /// @inheritdoc ICodexIdentity
    function updateAgentMetadata(
        uint256 tokenId,
        AgentMetadata calldata metadata
    ) external onlyAgentOwnerOrOperator(tokenId) {
        if (_agentStatus[tokenId] == Status.Terminated) revert AgentTerminated();
        _agentMetadata[tokenId] = metadata;
        emit MetadataUpdated(tokenId, tokenURI(tokenId));
    }

    // ──────────────────────────────────────────────
    //  Attestations (Codex ID Extension)
    // ──────────────────────────────────────────────

    /// @inheritdoc ICodexIdentity
    function createAttestation(
        address subject,
        bytes32 documentHash,
        bytes32 schemaId,
        uint64  expiresAt
    ) external onlyAuthorizedIssuer returns (bytes32 attestationId) {
        if (subject == address(0)) revert InvalidSubject();
        if (documentHash == bytes32(0)) revert InvalidDocumentHash();
        if (expiresAt <= block.timestamp) revert InvalidExpiration();

        attestationId = keccak256(
            abi.encodePacked(msg.sender, subject, documentHash, _nonce, block.chainid)
        );
        _nonce++;

        _attestations[attestationId] = Attestation({
            issuer:       msg.sender,
            subject:      subject,
            documentHash: documentHash,
            schemaId:     schemaId,
            createdAt:    uint64(block.timestamp),
            expiresAt:    expiresAt,
            revoked:      false
        });

        _subjectAttestations[subject].push(attestationId);

        emit AttestationCreated(attestationId, subject, msg.sender, documentHash, expiresAt);
    }

    /// @inheritdoc ICodexIdentity
    function revokeAttestation(bytes32 attestationId) external {
        Attestation storage att = _attestations[attestationId];
        if (att.issuer == address(0)) revert AttestationNotFound();
        if (att.issuer != msg.sender) revert OnlyIssuer();
        if (att.revoked) revert AttestationAlreadyRevoked();

        att.revoked = true;

        emit AttestationRevoked(attestationId, msg.sender, uint64(block.timestamp));
    }

    /// @inheritdoc ICodexIdentity
    function verifyAttestation(bytes32 attestationId) external view returns (bool valid) {
        Attestation storage att = _attestations[attestationId];
        if (att.issuer == address(0)) return false;
        if (att.revoked) return false;
        if (att.expiresAt <= block.timestamp) return false;
        return true;
    }

    /// @inheritdoc ICodexIdentity
    function getAttestation(
        bytes32 attestationId
    ) external view returns (
        address issuer,
        address subject,
        bytes32 documentHash,
        bytes32 schemaId,
        uint64  createdAt,
        uint64  expiresAt,
        bool    revoked
    ) {
        Attestation storage att = _attestations[attestationId];
        if (att.issuer == address(0)) revert AttestationNotFound();
        return (
            att.issuer,
            att.subject,
            att.documentHash,
            att.schemaId,
            att.createdAt,
            att.expiresAt,
            att.revoked
        );
    }

    /// @inheritdoc ICodexIdentity
    function getSubjectAttestations(
        address subject
    ) external view returns (bytes32[] memory) {
        return _subjectAttestations[subject];
    }

    // ──────────────────────────────────────────────
    //  ERC-721 Overrides
    // ──────────────────────────────────────────────

    /// @dev Clear agentWallet when the NFT is transferred to a new owner.
    ///      Spec: "agentWallet is automatically cleared when the agent is transferred."
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address from) {
        from = super._update(to, tokenId, auth);
        // Only clear on transfer, not on mint (from == 0) or burn (to == 0)
        if (from != address(0) && to != address(0)) {
            _setAgentWalletInternal(tokenId, address(0));
        }
        return from;
    }

    // ──────────────────────────────────────────────
    //  Internal Helpers
    // ──────────────────────────────────────────────

    /// @dev Mint a new agent NFT, set URI if provided, and initialize agentWallet.
    function _mintAgent(string memory agentURI) internal returns (uint256 agentId) {
        _tokenIdCounter++;
        agentId = _tokenIdCounter;

        _safeMint(msg.sender, agentId);

        if (bytes(agentURI).length > 0) {
            _setTokenURI(agentId, agentURI);
        }

        // Initialize agentWallet to the owner address
        bytes memory walletValue = abi.encode(msg.sender);
        _metadata[agentId][AGENT_WALLET_KEY] = walletValue;
        emit MetadataSet(agentId, "agentWallet", "agentWallet", walletValue);

        emit Registered(agentId, agentURI, msg.sender);
    }

    /// @dev Write agentWallet metadata and emit MetadataSet event.
    function _setAgentWalletInternal(uint256 agentId, address wallet) internal {
        bytes memory walletValue = abi.encode(wallet);
        _metadata[agentId][AGENT_WALLET_KEY] = walletValue;
        emit MetadataSet(agentId, "agentWallet", "agentWallet", walletValue);
    }
}
