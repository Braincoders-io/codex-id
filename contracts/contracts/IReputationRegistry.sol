// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IReputationRegistry
 * @notice Interface for the Codex ID Reputation Registry.
 *         Implements the ERC-8004 Reputation Registry standard.
 *         Allows clients to submit, revoke, and read feedback about AI agents.
 *
 * @dev agentId = ERC-721 tokenId in CodexIdentity.
 *      Feedback submitters MUST NOT be the agent owner or approved operator.
 *      valueDecimals must be in range 0–18.
 *      feedbackIndex is 1-indexed per the ERC-8004 spec.
 */
interface IReputationRegistry {

    // ──────────────────────────────────────────────
    //  Events
    // ──────────────────────────────────────────────

    /// @notice Emitted when feedback is submitted for an agent.
    event NewFeedback(
        uint256 indexed agentId,
        address indexed clientAddress,
        uint64 feedbackIndex,
        int128 value,
        uint8 valueDecimals,
        string indexed indexedTag1,
        string tag1,
        string tag2,
        string endpoint,
        string feedbackURI,
        bytes32 feedbackHash
    );

    /// @notice Emitted when feedback is revoked by its submitter.
    event FeedbackRevoked(
        uint256 indexed agentId,
        address indexed clientAddress,
        uint64 indexed feedbackIndex
    );

    /// @notice Emitted when the agent appends a response to feedback.
    event ResponseAppended(
        uint256 indexed agentId,
        address indexed clientAddress,
        uint64 feedbackIndex,
        address indexed responder,
        string responseURI,
        bytes32 responseHash
    );

    // ──────────────────────────────────────────────
    //  Core Functions
    // ──────────────────────────────────────────────

    /// @notice Returns the address of the linked Identity Registry.
    function getIdentityRegistry() external view returns (address identityRegistry);

    /// @notice Submit feedback for an AI agent.
    /// @param agentId The agent's ERC-721 tokenId in CodexIdentity.
    /// @param value The feedback score (mandatory). Scale defined by valueDecimals.
    /// @param valueDecimals Decimal places for value. Must be 0–18 (mandatory).
    /// @param tag1 Primary tag category (optional, e.g. "starred", "uptime").
    /// @param tag2 Secondary tag category (optional).
    /// @param endpoint The agent endpoint this feedback applies to (optional).
    /// @param feedbackURI URI to the off-chain feedback document (optional).
    /// @param feedbackHash Keccak256 hash of the off-chain feedback document (optional).
    function giveFeedback(
        uint256 agentId,
        int128 value,
        uint8 valueDecimals,
        string calldata tag1,
        string calldata tag2,
        string calldata endpoint,
        string calldata feedbackURI,
        bytes32 feedbackHash
    ) external;

    /// @notice Revoke previously submitted feedback.
    /// @param agentId The agent's numeric ID.
    /// @param feedbackIndex The index of the feedback to revoke.
    function revokeFeedback(uint256 agentId, uint64 feedbackIndex) external;

    /// @notice Agent appends a response to a feedback entry.
    /// @param agentId The agent's numeric ID.
    /// @param clientAddress The address that submitted the original feedback.
    /// @param feedbackIndex The index of the feedback being responded to.
    /// @param responseURI URI to the off-chain response document.
    /// @param responseHash Keccak256 hash of the off-chain response document.
    function appendResponse(
        uint256 agentId,
        address clientAddress,
        uint64 feedbackIndex,
        string calldata responseURI,
        bytes32 responseHash
    ) external;

    // ──────────────────────────────────────────────
    //  View Functions
    // ──────────────────────────────────────────────

    /// @notice Get aggregated feedback summary for an agent.
    /// @param agentId The agent's numeric ID.
    /// @param clientAddresses List of client addresses to include (empty = all).
    /// @param tag1 Filter by primary tag (empty = all).
    /// @param tag2 Filter by secondary tag (empty = all).
    /// @return count Number of feedback entries matched.
    /// @return summaryValue Aggregated score.
    /// @return summaryValueDecimals Decimal precision of summaryValue.
    function getSummary(
        uint256 agentId,
        address[] calldata clientAddresses,
        string calldata tag1,
        string calldata tag2
    ) external view returns (uint64 count, int128 summaryValue, uint8 summaryValueDecimals);

    /// @notice Read a single feedback entry.
    /// @param agentId The agent's numeric ID.
    /// @param clientAddress The address that submitted the feedback.
    /// @param feedbackIndex The index of the feedback entry.
    function readFeedback(
        uint256 agentId,
        address clientAddress,
        uint64 feedbackIndex
    ) external view returns (
        int128 value,
        uint8 valueDecimals,
        string memory tag1,
        string memory tag2,
        bool isRevoked
    );

    /// @notice Read all feedback entries for an agent.
    /// @param agentId The agent's numeric ID.
    /// @param clientAddresses List of client addresses to filter (empty = all).
    /// @param tag1 Filter by primary tag (empty = all).
    /// @param tag2 Filter by secondary tag (empty = all).
    /// @param includeRevoked Whether to include revoked feedback entries.
    function readAllFeedback(
        uint256 agentId,
        address[] calldata clientAddresses,
        string calldata tag1,
        string calldata tag2,
        bool includeRevoked
    ) external view returns (
        address[] memory clients,
        uint64[] memory feedbackIndexes,
        int128[] memory values,
        uint8[] memory valueDecimals,
        string[] memory tag1s,
        string[] memory tag2s,
        bool[] memory revokedStatuses
    );

    /// @notice Get number of responses for a specific feedback entry.
    function getResponseCount(
        uint256 agentId,
        address clientAddress,
        uint64 feedbackIndex,
        address[] calldata responders
    ) external view returns (uint64 count);

    /// @notice Get all client addresses that have submitted feedback for an agent.
    function getClients(uint256 agentId) external view returns (address[] memory);

    /// @notice Get the last feedback index submitted by a client for an agent.
    function getLastIndex(uint256 agentId, address clientAddress) external view returns (uint64);
}
