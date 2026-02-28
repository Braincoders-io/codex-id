// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ICodexIdentity
 * @notice Interface for the Codex ID Identity Registry.
 *         Implements the ERC-8004 Identity Registry standard.
 *         Part of the three-registry ERC-8004 architecture alongside
 *         IReputationRegistry and IValidationRegistry.
 *
 * @dev Extends ERC-721 with URIStorage. Each AI agent is a unique NFT.
 *      agentId = ERC-721 tokenId, assigned incrementally at registration.
 *      Attestation functions are a Codex ID extension to ERC-8004.
 */
interface ICodexIdentity {

    // ──────────────────────────────────────────────
    //  Structs
    // ──────────────────────────────────────────────

    /// @notice Key-value metadata entry used during registration.
    struct MetadataEntry {
        string metadataKey;
        bytes  metadataValue;
    }

    // ──────────────────────────────────────────────
    //  ERC-8004 Identity Events
    // ──────────────────────────────────────────────

    /// @notice Emitted when a new agent is registered (NFT minted).
    event Registered(
        uint256 indexed agentId,
        string  agentURI,
        address indexed owner
    );

    /// @notice Emitted when an agent's URI is updated.
    event URIUpdated(
        uint256 indexed agentId,
        string  newURI,
        address indexed updatedBy
    );

    /// @notice Emitted when on-chain metadata is set for an agent.
    event MetadataSet(
        uint256 indexed agentId,
        string  indexed indexedMetadataKey,
        string  metadataKey,
        bytes   metadataValue
    );

    // ──────────────────────────────────────────────
    //  Attestation Events (Codex ID extension)
    // ──────────────────────────────────────────────

    /// @notice Emitted when a new identity attestation is registered.
    event AttestationCreated(
        bytes32 indexed attestationId,
        address indexed subject,
        address indexed issuer,
        bytes32 documentHash,
        uint64  expiresAt
    );

    /// @notice Emitted when an attestation is revoked by its issuer.
    event AttestationRevoked(
        bytes32 indexed attestationId,
        address indexed revokedBy,
        uint64  revokedAt
    );

    // ──────────────────────────────────────────────
    //  Admin Events
    // ──────────────────────────────────────────────

    event IssuerAdded(address indexed issuer);
    event IssuerRemoved(address indexed issuer);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ──────────────────────────────────────────────
    //  ERC-8004: Registration
    // ──────────────────────────────────────────────

    /// @notice Register a new agent with a URI and optional metadata.
    /// @param agentURI URI resolving to the agent registration file.
    /// @param metadata Array of key-value metadata entries.
    /// @return agentId The ERC-721 tokenId assigned to this agent.
    function register(
        string calldata agentURI,
        MetadataEntry[] calldata metadata
    ) external returns (uint256 agentId);

    /// @notice Register a new agent with a URI only.
    function register(string calldata agentURI) external returns (uint256 agentId);

    /// @notice Register a new agent without a URI (set later via setAgentURI).
    function register() external returns (uint256 agentId);

    /// @notice Update the agent's registration file URI.
    /// @dev Only callable by the token owner or approved operator.
    function setAgentURI(uint256 agentId, string calldata newURI) external;

    // ──────────────────────────────────────────────
    //  ERC-8004: On-Chain Metadata
    // ──────────────────────────────────────────────

    /// @notice Read arbitrary on-chain metadata for an agent.
    function getMetadata(
        uint256 agentId,
        string memory metadataKey
    ) external view returns (bytes memory);

    /// @notice Set arbitrary on-chain metadata for an agent.
    /// @dev The key "agentWallet" is reserved — use setAgentWallet() instead.
    function setMetadata(
        uint256 agentId,
        string memory metadataKey,
        bytes memory metadataValue
    ) external;

    // ──────────────────────────────────────────────
    //  ERC-8004: Agent Wallet
    // ──────────────────────────────────────────────

    /// @notice Set the agent's payment wallet, verified by EIP-712 or ERC-1271 signature.
    /// @dev Only callable by the token owner or approved operator.
    ///      The signature must be signed by newWallet to prove control.
    ///      Automatically cleared when the NFT is transferred.
    function setAgentWallet(
        uint256 agentId,
        address newWallet,
        uint256 deadline,
        bytes calldata signature
    ) external;

    /// @notice Get the agent's current payment wallet address.
    function getAgentWallet(uint256 agentId) external view returns (address);

    /// @notice Clear the agent's payment wallet.
    /// @dev Only callable by the token owner or approved operator.
    function unsetAgentWallet(uint256 agentId) external;

    // ──────────────────────────────────────────────
    //  Attestations (Codex ID Extension)
    // ──────────────────────────────────────────────

    /// @notice Register a new identity attestation on-chain.
    /// @param subject The address of the identity holder.
    /// @param documentHash Keccak256 hash of the off-chain identity document.
    /// @param schemaId Schema identifier for the attestation type.
    /// @param expiresAt Unix timestamp when the attestation expires.
    /// @return attestationId The unique identifier for the attestation.
    function createAttestation(
        address subject,
        bytes32 documentHash,
        bytes32 schemaId,
        uint64  expiresAt
    ) external returns (bytes32 attestationId);

    /// @notice Revoke an existing attestation.
    function revokeAttestation(bytes32 attestationId) external;

    /// @notice Verify if an attestation is valid and not expired/revoked.
    function verifyAttestation(bytes32 attestationId) external view returns (bool valid);

    /// @notice Get full attestation data.
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
    );

    /// @notice Get all attestation IDs for a subject address.
    function getSubjectAttestations(address subject) external view returns (bytes32[] memory);
}
