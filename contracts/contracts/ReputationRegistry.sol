// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./IReputationRegistry.sol";

/**
 * @title ReputationRegistry
 * @author Braincoders
 * @notice ERC-8004 Reputation Registry for the Codex ID system.
 *         Allows clients to submit scored feedback about AI agents,
 *         enabling trustless reputation building over time.
 *
 * @dev Linked to CodexIdentity (ERC-721) as the Identity Registry.
 *      agentId = ERC-721 tokenId in CodexIdentity.
 *      Feedback submitters MUST NOT be the agent owner or approved operator.
 *      valueDecimals must be in range 0–18.
 *      feedbackIndex is 1-indexed per the ERC-8004 spec.
 *      endpoint, feedbackURI, feedbackHash are emitted but NOT stored (spec requirement).
 */
contract ReputationRegistry is IReputationRegistry {

    // ──────────────────────────────────────────────
    //  Types
    // ──────────────────────────────────────────────

    /// @dev Only value, valueDecimals, tag1, tag2, revoked are stored.
    ///      endpoint, feedbackURI, feedbackHash are emitted only — per ERC-8004 spec.
    struct FeedbackEntry {
        address client;
        int128  value;
        uint8   valueDecimals;
        string  tag1;
        string  tag2;
        bool    revoked;
    }

    struct ResponseEntry {
        address responder;
        string  responseURI;
        bytes32 responseHash;
    }

    // ──────────────────────────────────────────────
    //  State
    // ──────────────────────────────────────────────

    /// @notice The linked ERC-8004 Identity Registry (CodexIdentity).
    address private _identityRegistry;

    /// @notice agentId => client => list of feedback entries (1-indexed externally).
    mapping(uint256 => mapping(address => FeedbackEntry[])) private _feedback;

    /// @notice agentId => list of clients who have submitted feedback.
    mapping(uint256 => address[]) private _clients;

    /// @notice agentId => client => whether they are already tracked.
    mapping(uint256 => mapping(address => bool)) private _clientTracked;

    /// @notice agentId => client => feedbackIndex (1-indexed) => list of responses.
    mapping(uint256 => mapping(address => mapping(uint64 => ResponseEntry[]))) private _responses;

    // ──────────────────────────────────────────────
    //  Errors
    // ──────────────────────────────────────────────

    error IdentityRegistryNotSet();
    error AgentNotFound();
    error InvalidValueDecimals();
    error SubmitterIsAgentOwner();
    error FeedbackNotFound();
    error NotFeedbackOwner();
    error FeedbackAlreadyRevoked();
    error ClientAddressesRequired();

    // ──────────────────────────────────────────────
    //  Constructor
    // ──────────────────────────────────────────────

    /// @param identityRegistry_ Address of the deployed CodexIdentity contract.
    constructor(address identityRegistry_) {
        if (identityRegistry_ == address(0)) revert IdentityRegistryNotSet();
        _identityRegistry = identityRegistry_;
    }

    // ──────────────────────────────────────────────
    //  View: Identity Registry
    // ──────────────────────────────────────────────

    /// @inheritdoc IReputationRegistry
    function getIdentityRegistry() external view returns (address) {
        return _identityRegistry;
    }

    // ──────────────────────────────────────────────
    //  Write: Feedback
    // ──────────────────────────────────────────────

    /// @inheritdoc IReputationRegistry
    function giveFeedback(
        uint256 agentId,
        int128  value,
        uint8   valueDecimals,
        string calldata tag1,
        string calldata tag2,
        string calldata endpoint,
        string calldata feedbackURI,
        bytes32 feedbackHash
    ) external {
        if (valueDecimals > 18) revert InvalidValueDecimals();
        _requireAgentExists(agentId);
        _requireNotAgentOwner(agentId, msg.sender);

        if (!_clientTracked[agentId][msg.sender]) {
            _clients[agentId].push(msg.sender);
            _clientTracked[agentId][msg.sender] = true;
        }

        // feedbackIndex is 1-indexed per ERC-8004 spec
        uint64 feedbackIndex = uint64(_feedback[agentId][msg.sender].length) + 1;

        // Store only: value, valueDecimals, tag1, tag2, revoked
        // endpoint, feedbackURI, feedbackHash are emitted only (spec requirement)
        _feedback[agentId][msg.sender].push(FeedbackEntry({
            client:        msg.sender,
            value:         value,
            valueDecimals: valueDecimals,
            tag1:          tag1,
            tag2:          tag2,
            revoked:       false
        }));

        emit NewFeedback(
            agentId,
            msg.sender,
            feedbackIndex,
            value,
            valueDecimals,
            tag1,
            tag1,
            tag2,
            endpoint,
            feedbackURI,
            feedbackHash
        );
    }

    /// @inheritdoc IReputationRegistry
    function revokeFeedback(uint256 agentId, uint64 feedbackIndex) external {
        // feedbackIndex is 1-indexed: map to 0-based array index
        if (feedbackIndex == 0) revert FeedbackNotFound();
        FeedbackEntry[] storage entries = _feedback[agentId][msg.sender];
        if (feedbackIndex > entries.length) revert FeedbackNotFound();

        FeedbackEntry storage entry = entries[feedbackIndex - 1];
        if (entry.client != msg.sender) revert NotFeedbackOwner();
        if (entry.revoked) revert FeedbackAlreadyRevoked();

        entry.revoked = true;

        emit FeedbackRevoked(agentId, msg.sender, feedbackIndex);
    }

    /// @inheritdoc IReputationRegistry
    function appendResponse(
        uint256 agentId,
        address clientAddress,
        uint64  feedbackIndex,
        string calldata responseURI,
        bytes32 responseHash
    ) external {
        // feedbackIndex is 1-indexed
        if (feedbackIndex == 0) revert FeedbackNotFound();
        FeedbackEntry[] storage entries = _feedback[agentId][clientAddress];
        if (feedbackIndex > entries.length) revert FeedbackNotFound();

        // Store response keyed by 1-indexed feedbackIndex
        _responses[agentId][clientAddress][feedbackIndex].push(ResponseEntry({
            responder:   msg.sender,
            responseURI: responseURI,
            responseHash: responseHash
        }));

        emit ResponseAppended(
            agentId,
            clientAddress,
            feedbackIndex,
            msg.sender,
            responseURI,
            responseHash
        );
    }

    // ──────────────────────────────────────────────
    //  View: Feedback Reads
    // ──────────────────────────────────────────────

    /// @inheritdoc IReputationRegistry
    function readFeedback(
        uint256 agentId,
        address clientAddress,
        uint64  feedbackIndex
    ) external view returns (
        int128  value,
        uint8   valueDecimals,
        string memory tag1,
        string memory tag2,
        bool    isRevoked
    ) {
        if (feedbackIndex == 0) revert FeedbackNotFound();
        FeedbackEntry[] storage entries = _feedback[agentId][clientAddress];
        if (feedbackIndex > entries.length) revert FeedbackNotFound();
        FeedbackEntry storage e = entries[feedbackIndex - 1];
        return (e.value, e.valueDecimals, e.tag1, e.tag2, e.revoked);
    }

    /// @inheritdoc IReputationRegistry
    function readAllFeedback(
        uint256 agentId,
        address[] calldata clientAddresses,
        string calldata tag1,
        string calldata tag2,
        bool includeRevoked
    ) external view returns (
        address[] memory clients,
        uint64[]  memory feedbackIndexes,
        int128[]  memory values,
        uint8[]   memory valueDecimals,
        string[]  memory tag1s,
        string[]  memory tag2s,
        bool[]    memory revokedStatuses
    ) {
        address[] memory pool = clientAddresses.length > 0
            ? clientAddresses
            : _clients[agentId];

        uint256 total = 0;
        for (uint256 i = 0; i < pool.length; i++) {
            FeedbackEntry[] storage entries = _feedback[agentId][pool[i]];
            for (uint256 j = 0; j < entries.length; j++) {
                if (_matchesFilter(entries[j], tag1, tag2, includeRevoked)) total++;
            }
        }

        clients         = new address[](total);
        feedbackIndexes = new uint64[](total);
        values          = new int128[](total);
        valueDecimals   = new uint8[](total);
        tag1s           = new string[](total);
        tag2s           = new string[](total);
        revokedStatuses = new bool[](total);

        uint256 idx = 0;
        for (uint256 i = 0; i < pool.length; i++) {
            FeedbackEntry[] storage entries = _feedback[agentId][pool[i]];
            for (uint256 j = 0; j < entries.length; j++) {
                if (_matchesFilter(entries[j], tag1, tag2, includeRevoked)) {
                    clients[idx]         = pool[i];
                    feedbackIndexes[idx] = uint64(j) + 1; // return 1-indexed
                    values[idx]          = entries[j].value;
                    valueDecimals[idx]   = entries[j].valueDecimals;
                    tag1s[idx]           = entries[j].tag1;
                    tag2s[idx]           = entries[j].tag2;
                    revokedStatuses[idx] = entries[j].revoked;
                    idx++;
                }
            }
        }
    }

    /// @inheritdoc IReputationRegistry
    function getSummary(
        uint256 agentId,
        address[] calldata clientAddresses,
        string calldata tag1,
        string calldata tag2
    ) external view returns (uint64 count, int128 summaryValue, uint8 summaryValueDecimals) {
        // Per ERC-8004 spec: clientAddresses MUST be non-empty to prevent Sybil attacks
        if (clientAddresses.length == 0) revert ClientAddressesRequired();

        int256 accumulator = 0;
        count = 0;

        for (uint256 i = 0; i < clientAddresses.length; i++) {
            FeedbackEntry[] storage entries = _feedback[agentId][clientAddresses[i]];
            for (uint256 j = 0; j < entries.length; j++) {
                if (_matchesFilter(entries[j], tag1, tag2, false)) {
                    accumulator += entries[j].value;
                    count++;
                }
            }
        }

        summaryValue = count > 0
            ? int128(accumulator / int256(uint256(count)))
            : int128(0);
        summaryValueDecimals = 0;
    }

    /// @inheritdoc IReputationRegistry
    function getResponseCount(
        uint256 agentId,
        address clientAddress,
        uint64  feedbackIndex,
        address[] calldata responders
    ) external view returns (uint64 count) {
        ResponseEntry[] storage responses = _responses[agentId][clientAddress][feedbackIndex];
        if (responders.length == 0) return uint64(responses.length);

        for (uint256 i = 0; i < responses.length; i++) {
            for (uint256 j = 0; j < responders.length; j++) {
                if (responses[i].responder == responders[j]) {
                    count++;
                    break;
                }
            }
        }
    }

    /// @inheritdoc IReputationRegistry
    function getClients(uint256 agentId) external view returns (address[] memory) {
        return _clients[agentId];
    }

    /// @inheritdoc IReputationRegistry
    function getLastIndex(
        uint256 agentId,
        address clientAddress
    ) external view returns (uint64) {
        // Returns the 1-indexed last feedbackIndex
        return uint64(_feedback[agentId][clientAddress].length);
    }

    // ──────────────────────────────────────────────
    //  Internal Helpers
    // ──────────────────────────────────────────────

    /// @dev Confirm the agentId is a valid ERC-721 token in CodexIdentity.
    ///      ownerOf() reverts with ERC721NonexistentToken if the token doesn't exist.
    function _requireAgentExists(uint256 agentId) internal view {
        IERC721(_identityRegistry).ownerOf(agentId);
    }

    /// @dev Per ERC-8004 spec: submitter MUST NOT be the agent owner or approved operator.
    function _requireNotAgentOwner(uint256 agentId, address caller) internal view {
        IERC721 registry = IERC721(_identityRegistry);
        address tokenOwner = registry.ownerOf(agentId);
        if (caller == tokenOwner) revert SubmitterIsAgentOwner();
        if (registry.isApprovedForAll(tokenOwner, caller)) revert SubmitterIsAgentOwner();
        if (registry.getApproved(agentId) == caller) revert SubmitterIsAgentOwner();
    }

    /// @dev Check if a feedback entry passes tag and revocation filters.
    function _matchesFilter(
        FeedbackEntry storage entry,
        string calldata tag1,
        string calldata tag2,
        bool includeRevoked
    ) internal view returns (bool) {
        if (!includeRevoked && entry.revoked) return false;
        if (bytes(tag1).length > 0 && keccak256(bytes(entry.tag1)) != keccak256(bytes(tag1))) return false;
        if (bytes(tag2).length > 0 && keccak256(bytes(entry.tag2)) != keccak256(bytes(tag2))) return false;
        return true;
    }
}
