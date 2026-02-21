// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ICodexIdentity.sol";

/**
 * @title CodexIdentity
 * @author Braincoders
 * @notice On-chain identity attestation registry for the Codex ID system.
 *         Implements ERC-8004 (Decentralized Identity Attestation) and
 *         BAP-578 (BNB Attestation Protocol) standards.
 *
 * @dev Designed for opBNB deployment. Supports two immediate transactions:
 *      1. createAttestation — Register a notarized identity attestation.
 *      2. revokeAttestation — Revoke a compromised or expired attestation.
 *
 *      Architecture: Minimal on-chain footprint. Document data stays off-chain;
 *      only the keccak256 hash is stored for verification.
 */
contract CodexIdentity is ICodexIdentity {
    // ──────────────────────────────────────────────
    //  Types
    // ──────────────────────────────────────────────

    struct Attestation {
        address issuer;
        address subject;
        bytes32 documentHash;
        bytes32 schemaId;
        uint64 createdAt;
        uint64 expiresAt;
        bool revoked;
    }

    // ──────────────────────────────────────────────
    //  State
    // ──────────────────────────────────────────────

    /// @notice Contract owner (deployer). Can manage authorized issuers.
    address public owner;

    /// @notice Nonce used for deterministic attestation ID generation.
    uint256 private _nonce;

    /// @notice Mapping of attestation ID to its data.
    mapping(bytes32 => Attestation) private _attestations;

    /// @notice Authorized issuers that can create attestations.
    mapping(address => bool) public authorizedIssuers;

    /// @notice Lookup: subject address => list of their attestation IDs.
    mapping(address => bytes32[]) private _subjectAttestations;

    // ──────────────────────────────────────────────
    //  Errors
    // ──────────────────────────────────────────────

    error OnlyOwner();
    error OnlyAuthorizedIssuer();
    error OnlyIssuer();
    error InvalidSubject();
    error InvalidDocumentHash();
    error InvalidExpiration();
    error AttestationNotFound();
    error AttestationAlreadyRevoked();

    // ──────────────────────────────────────────────
    //  Admin Events
    // ──────────────────────────────────────────────

    /// @notice Emitted when an issuer is authorized.
    event IssuerAdded(address indexed issuer);

    /// @notice Emitted when an issuer is removed.
    event IssuerRemoved(address indexed issuer);

    /// @notice Emitted when ownership is transferred.
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

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

    // ──────────────────────────────────────────────
    //  Constructor
    // ──────────────────────────────────────────────

    constructor() {
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

    /// @notice Transfer ownership of the contract.
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidSubject();
        authorizedIssuers[newOwner] = true;
        authorizedIssuers[owner] = false;
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ──────────────────────────────────────────────
    //  Transaction 1: Create Attestation (ERC-8004)
    // ──────────────────────────────────────────────

    /// @inheritdoc ICodexIdentity
    function createAttestation(
        address subject,
        bytes32 documentHash,
        bytes32 schemaId,
        uint64 expiresAt
    ) external onlyAuthorizedIssuer returns (bytes32 attestationId) {
        if (subject == address(0)) revert InvalidSubject();
        if (documentHash == bytes32(0)) revert InvalidDocumentHash();
        if (expiresAt <= block.timestamp) revert InvalidExpiration();

        attestationId = keccak256(
            abi.encodePacked(msg.sender, subject, documentHash, _nonce, block.chainid)
        );
        _nonce++;

        _attestations[attestationId] = Attestation({
            issuer: msg.sender,
            subject: subject,
            documentHash: documentHash,
            schemaId: schemaId,
            createdAt: uint64(block.timestamp),
            expiresAt: expiresAt,
            revoked: false
        });

        _subjectAttestations[subject].push(attestationId);

        emit AttestationCreated(
            attestationId,
            subject,
            msg.sender,
            documentHash,
            expiresAt
        );
    }

    // ──────────────────────────────────────────────
    //  Transaction 2: Revoke Attestation (BAP-578)
    // ──────────────────────────────────────────────

    /// @inheritdoc ICodexIdentity
    function revokeAttestation(bytes32 attestationId) external {
        Attestation storage att = _attestations[attestationId];
        if (att.issuer == address(0)) revert AttestationNotFound();
        if (att.issuer != msg.sender) revert OnlyIssuer();
        if (att.revoked) revert AttestationAlreadyRevoked();

        att.revoked = true;

        emit AttestationRevoked(
            attestationId,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    // ──────────────────────────────────────────────
    //  View / Verify
    // ──────────────────────────────────────────────

    /// @inheritdoc ICodexIdentity
    function verifyAttestation(
        bytes32 attestationId
    ) external view returns (bool valid) {
        Attestation storage att = _attestations[attestationId];
        if (att.issuer == address(0)) return false;
        if (att.revoked) return false;
        if (att.expiresAt <= block.timestamp) return false;
        return true;
    }

    /// @inheritdoc ICodexIdentity
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
        )
    {
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
}
