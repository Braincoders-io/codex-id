// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ICodexIdentity
 * @notice Interface for Codex Identity attestation system.
 *         Aligned with ERC-8004 (Decentralized Identity Attestation)
 *         and BAP-578 (BNB Attestation Protocol).
 */
interface ICodexIdentity {
    /// @notice Emitted when a new identity attestation is registered.
    event AttestationCreated(
        bytes32 indexed attestationId,
        address indexed subject,
        address indexed issuer,
        bytes32 documentHash,
        uint64 expiresAt
    );

    /// @notice Emitted when an attestation is revoked by its issuer.
    event AttestationRevoked(
        bytes32 indexed attestationId,
        address indexed revokedBy,
        uint64 revokedAt
    );

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
        uint64 expiresAt
    ) external returns (bytes32 attestationId);

    /// @notice Revoke an existing attestation.
    /// @param attestationId The unique identifier of the attestation.
    function revokeAttestation(bytes32 attestationId) external;

    /// @notice Verify if an attestation is valid and not expired/revoked.
    /// @param attestationId The unique identifier of the attestation.
    /// @return valid Whether the attestation is currently valid.
    function verifyAttestation(bytes32 attestationId) external view returns (bool valid);

    /// @notice Get full attestation data.
    /// @param attestationId The unique identifier of the attestation.
    function getAttestation(
        bytes32 attestationId
    )
        external
        view
        returns (
            address issuer,
            address subject,
            bytes32 documentHash,
            bytes32 schemaId,
            uint64 createdAt,
            uint64 expiresAt,
            bool revoked
        );

    /// @notice Get all attestation IDs for a subject.
    /// @param subject The address of the identity holder.
    /// @return Array of attestation IDs belonging to the subject.
    function getSubjectAttestations(address subject) external view returns (bytes32[] memory);
}
