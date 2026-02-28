// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./IValidationRegistry.sol";

/**
 * @title ValidationRegistry
 * @author Braincoders
 * @notice ERC-8004 Validation Registry for the Codex ID system.
 *         Allows AI agent owners to request third-party validator assessments,
 *         and validators to respond with a score from 0 (failed) to 100 (passed).
 *
 * @dev Linked to CodexIdentity (ERC-721) as the Identity Registry.
 *      agentId = ERC-721 tokenId in CodexIdentity.
 *      Only the agent owner or approved operator can submit validationRequest.
 *      Only the designated validator can submit validationResponse.
 *      Multiple responses per request are permitted.
 *      response field must be in range 0–100.
 */
contract ValidationRegistry is IValidationRegistry {

    // ──────────────────────────────────────────────
    //  Types
    // ──────────────────────────────────────────────

    struct ValidationRequestData {
        address requester;
        address validatorAddress;
        uint256 agentId;
        string requestURI;
        bytes32 requestHash;
        bool exists;
    }

    struct ValidationResponseData {
        address validatorAddress;
        uint8 response;
        string responseURI;
        bytes32 responseHash;
        string tag;
        uint256 timestamp;
    }

    // ──────────────────────────────────────────────
    //  State
    // ──────────────────────────────────────────────

    /// @notice The linked ERC-8004 Identity Registry (CodexIdentity).
    address private _identityRegistry;

    /// @notice requestHash => ValidationRequestData.
    mapping(bytes32 => ValidationRequestData) private _requests;

    /// @notice requestHash => list of responses (multiple allowed).
    mapping(bytes32 => ValidationResponseData[]) private _responses;

    /// @notice agentId => list of requestHashes.
    mapping(uint256 => bytes32[]) private _agentValidations;

    /// @notice validatorAddress => list of requestHashes assigned to them.
    mapping(address => bytes32[]) private _validatorRequests;

    // ──────────────────────────────────────────────
    //  Errors
    // ──────────────────────────────────────────────

    error IdentityRegistryNotSet();
    error AgentNotFound();
    error NotAgentOwnerOrOperator();
    error RequestNotFound();
    error NotDesignatedValidator();
    error InvalidResponseScore();
    error RequestAlreadyExists();

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

    /// @inheritdoc IValidationRegistry
    function getIdentityRegistry() external view returns (address) {
        return _identityRegistry;
    }

    // ──────────────────────────────────────────────
    //  Write: Validation Request
    // ──────────────────────────────────────────────

    /// @inheritdoc IValidationRegistry
    function validationRequest(
        address validatorAddress,
        uint256 agentId,
        string calldata requestURI,
        bytes32 requestHash
    ) external {
        if (_requests[requestHash].exists) revert RequestAlreadyExists();
        _requireAgentOwnerOrOperator(agentId);

        _requests[requestHash] = ValidationRequestData({
            requester: msg.sender,
            validatorAddress: validatorAddress,
            agentId: agentId,
            requestURI: requestURI,
            requestHash: requestHash,
            exists: true
        });

        _agentValidations[agentId].push(requestHash);
        _validatorRequests[validatorAddress].push(requestHash);

        emit ValidationRequest(validatorAddress, agentId, requestURI, requestHash);
    }

    // ──────────────────────────────────────────────
    //  Write: Validation Response
    // ──────────────────────────────────────────────

    /// @inheritdoc IValidationRegistry
    function validationResponse(
        bytes32 requestHash,
        uint8 response,
        string calldata responseURI,
        bytes32 responseHash,
        string calldata tag
    ) external {
        ValidationRequestData storage req = _requests[requestHash];
        if (!req.exists) revert RequestNotFound();
        if (req.validatorAddress != msg.sender) revert NotDesignatedValidator();
        if (response > 100) revert InvalidResponseScore();

        _responses[requestHash].push(ValidationResponseData({
            validatorAddress: msg.sender,
            response: response,
            responseURI: responseURI,
            responseHash: responseHash,
            tag: tag,
            timestamp: block.timestamp
        }));

        emit ValidationResponse(
            msg.sender,
            req.agentId,
            requestHash,
            response,
            responseURI,
            responseHash,
            tag
        );
    }

    // ──────────────────────────────────────────────
    //  View: Validation Reads
    // ──────────────────────────────────────────────

    /// @inheritdoc IValidationRegistry
    function getValidationStatus(bytes32 requestHash) external view returns (
        address validatorAddress,
        uint256 agentId,
        uint8 response,
        bytes32 responseHash,
        string memory tag,
        uint256 lastUpdate
    ) {
        ValidationRequestData storage req = _requests[requestHash];
        if (!req.exists) revert RequestNotFound();

        validatorAddress = req.validatorAddress;
        agentId = req.agentId;

        ValidationResponseData[] storage responses = _responses[requestHash];
        if (responses.length > 0) {
            ValidationResponseData storage latest = responses[responses.length - 1];
            response     = latest.response;
            responseHash = latest.responseHash;
            tag          = latest.tag;
            lastUpdate   = latest.timestamp;
        }
    }

    /// @inheritdoc IValidationRegistry
    function getSummary(
        uint256 agentId,
        address[] calldata validatorAddresses,
        string calldata tag
    ) external view returns (uint64 count, uint8 averageResponse) {
        bytes32[] storage hashes = _agentValidations[agentId];
        uint256 total = 0;
        uint256 sum = 0;

        for (uint256 i = 0; i < hashes.length; i++) {
            ValidationRequestData storage req = _requests[hashes[i]];

            // Filter by validator if specified
            if (validatorAddresses.length > 0 && !_inArray(req.validatorAddress, validatorAddresses)) {
                continue;
            }

            ValidationResponseData[] storage responses = _responses[hashes[i]];
            for (uint256 j = 0; j < responses.length; j++) {
                if (bytes(tag).length > 0 &&
                    keccak256(bytes(responses[j].tag)) != keccak256(bytes(tag))) {
                    continue;
                }
                sum += responses[j].response;
                total++;
            }
        }

        count = uint64(total);
        averageResponse = total > 0 ? uint8(sum / total) : 0;
    }

    /// @inheritdoc IValidationRegistry
    function getAgentValidations(uint256 agentId) external view returns (bytes32[] memory) {
        return _agentValidations[agentId];
    }

    /// @inheritdoc IValidationRegistry
    function getValidatorRequests(address validatorAddress) external view returns (bytes32[] memory) {
        return _validatorRequests[validatorAddress];
    }

    // ──────────────────────────────────────────────
    //  Internal Helpers
    // ──────────────────────────────────────────────

    /// @dev Per ERC-8004 spec: validationRequest MUST be called by the owner or operator of agentId.
    ///      ownerOf() reverts with ERC721NonexistentToken if the token doesn't exist.
    function _requireAgentOwnerOrOperator(uint256 agentId) internal view {
        IERC721 registry = IERC721(_identityRegistry);
        address tokenOwner = registry.ownerOf(agentId); // reverts if nonexistent
        if (
            msg.sender != tokenOwner &&
            !registry.isApprovedForAll(tokenOwner, msg.sender) &&
            registry.getApproved(agentId) != msg.sender
        ) revert NotAgentOwnerOrOperator();
    }

    /// @dev Check if an address exists in an array.
    function _inArray(address target, address[] calldata arr) internal pure returns (bool) {
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == target) return true;
        }
        return false;
    }
}
