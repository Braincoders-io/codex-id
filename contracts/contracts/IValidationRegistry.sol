// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IValidationRegistry
 * @notice Interface for the Codex ID Validation Registry.
 *         Implements the ERC-8004 Validation Registry standard.
 *         Allows agent owners to request third-party validator assessments
 *         and validators to submit scored responses.
 *
 * @dev Only the agent owner or operator can submit a validationRequest.
 *      Only the designated validator can submit a validationResponse.
 *      response field ranges from 0 (failed) to 100 (passed).
 *      Multiple responses per request are permitted.
 */
interface IValidationRegistry {

    // ──────────────────────────────────────────────
    //  Events
    // ──────────────────────────────────────────────

    /// @notice Emitted when a validation request is submitted.
    event ValidationRequest(
        address indexed validatorAddress,
        uint256 indexed agentId,
        string requestURI,
        bytes32 indexed requestHash
    );

    /// @notice Emitted when a validator submits a response.
    event ValidationResponse(
        address indexed validatorAddress,
        uint256 indexed agentId,
        bytes32 indexed requestHash,
        uint8 response,
        string responseURI,
        bytes32 responseHash,
        string tag
    );

    // ──────────────────────────────────────────────
    //  Core Functions
    // ──────────────────────────────────────────────

    /// @notice Returns the address of the linked Identity Registry.
    function getIdentityRegistry() external view returns (address identityRegistry);

    /// @notice Submit a validation request for an agent.
    /// @dev Only callable by the agent owner or operator.
    /// @param validatorAddress The address of the designated validator.
    /// @param agentId The agent's numeric ID (mandatory).
    /// @param requestURI URI to the off-chain validation request document (mandatory).
    /// @param requestHash Keccak256 hash of the off-chain request document (mandatory).
    function validationRequest(
        address validatorAddress,
        uint256 agentId,
        string calldata requestURI,
        bytes32 requestHash
    ) external;

    /// @notice Submit a validation response for a pending request.
    /// @dev Only callable by the validator specified in the original request.
    ///      Multiple responses per requestHash are permitted.
    /// @param requestHash The hash identifying the original request (mandatory).
    /// @param response Score from 0 (failed) to 100 (passed) (mandatory).
    /// @param responseURI URI to the off-chain response document (optional).
    /// @param responseHash Keccak256 hash of the off-chain response document (optional).
    /// @param tag Category label for this validation (optional).
    function validationResponse(
        bytes32 requestHash,
        uint8 response,
        string calldata responseURI,
        bytes32 responseHash,
        string calldata tag
    ) external;

    // ──────────────────────────────────────────────
    //  View Functions
    // ──────────────────────────────────────────────

    /// @notice Get the latest status of a validation request.
    /// @param requestHash The hash identifying the request.
    /// @return validatorAddress The designated validator.
    /// @return agentId The agent being validated.
    /// @return response The latest response score (0–100).
    /// @return responseHash Hash of the latest response document.
    /// @return tag Category label of the latest response.
    /// @return lastUpdate Timestamp of the latest response.
    function getValidationStatus(bytes32 requestHash) external view returns (
        address validatorAddress,
        uint256 agentId,
        uint8 response,
        bytes32 responseHash,
        string memory tag,
        uint256 lastUpdate
    );

    /// @notice Get aggregated validation summary for an agent.
    /// @param agentId The agent's numeric ID.
    /// @param validatorAddresses List of validators to include (empty = all).
    /// @param tag Filter by tag category (empty = all).
    /// @return count Number of validation responses matched.
    /// @return averageResponse Average response score (0–100).
    function getSummary(
        uint256 agentId,
        address[] calldata validatorAddresses,
        string calldata tag
    ) external view returns (uint64 count, uint8 averageResponse);

    /// @notice Get all request hashes submitted for an agent.
    function getAgentValidations(uint256 agentId) external view returns (bytes32[] memory requestHashes);

    /// @notice Get all request hashes submitted to a validator.
    function getValidatorRequests(address validatorAddress) external view returns (bytes32[] memory requestHashes);
}
