// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IskoAkoFundLedger (v2)
 * @notice Immutable on-chain ledger for IskoAko scholarship fund releases
 *         AND scholar profile identity anchoring.
 *
 *         v2 additions:
 *         - anchorScholarProfile()  — records a keccak256 hash of verified scholar identity
 *         - getProfileAnchor()     — reads a profile anchor by index
 *         - getTotalProfileAnchors() — returns total profile anchors count
 *         - getProfileAnchorByScholarId() — looks up the latest anchor for a scholar
 *
 * @dev    Deploy this contract and update CONTRACT_ADDRESS in Supabase secrets.
 *         The existing fund release functions remain unchanged.
 */
contract IskoAkoFundLedger {
    // ─── Fund Release (existing, unchanged) ─────────────────────────────────

    struct Release {
        string scholarshipId;
        string scholarId;
        uint256 amountCentavos;
        uint256 releasedAt;
        string paymongoPaymentId;
        string status;
    }

    Release[] public releases;

    event ReleaseRecorded(
        uint256 indexed releaseId,
        string scholarshipId,
        string scholarId,
        uint256 amountCentavos,
        string paymongoPaymentId
    );

    function recordRelease(
        string calldata scholarshipId,
        string calldata scholarId,
        uint256 amountCentavos,
        string calldata paymongoPaymentId
    ) external returns (uint256) {
        releases.push(Release({
            scholarshipId: scholarshipId,
            scholarId: scholarId,
            amountCentavos: amountCentavos,
            releasedAt: block.timestamp,
            paymongoPaymentId: paymongoPaymentId,
            status: "released"
        }));

        uint256 releaseId = releases.length - 1;
        emit ReleaseRecorded(releaseId, scholarshipId, scholarId, amountCentavos, paymongoPaymentId);
        return releaseId;
    }

    function getRelease(uint256 index) external view returns (Release memory) {
        require(index < releases.length, "Release index out of bounds");
        return releases[index];
    }

    function getTotalReleases() external view returns (uint256) {
        return releases.length;
    }

    // ─── Scholar Profile Anchor (NEW in v2) ──────────────────────────────────

    struct ProfileAnchor {
        string scholarId;       // UUID of the scholar (no PII)
        bytes32 profileHash;    // keccak256 hash of canonical identity fields
        uint256 anchoredAt;     // block.timestamp when anchored
    }

    ProfileAnchor[] public profileAnchors;

    // Mapping: keccak256(scholarId) => latest anchor index + 1 (0 means no anchor)
    mapping(bytes32 => uint256) private _latestAnchorIndex;

    event ProfileAnchored(
        uint256 indexed anchorId,
        string scholarId,
        bytes32 profileHash,
        uint256 anchoredAt
    );

    /**
     * @notice Record a scholar's verified profile hash on-chain.
     * @param scholarId  The scholar's UUID (from Supabase).
     * @param profileHash  keccak256 hash of the canonical identity string:
     *                     "scholarId|FIRST_NAME|LAST_NAME|MIDDLE_NAME|SUFFIX|BIRTH_DATE|GENDER|FACE_STATUS|VERIFIED_AT"
     * @return anchorId  The index of the new anchor in the profileAnchors array.
     */
    function anchorScholarProfile(
        string calldata scholarId,
        bytes32 profileHash
    ) external returns (uint256) {
        profileAnchors.push(ProfileAnchor({
            scholarId: scholarId,
            profileHash: profileHash,
            anchoredAt: block.timestamp
        }));

        uint256 anchorId = profileAnchors.length - 1;

        // Update the latest anchor mapping for this scholar
        bytes32 scholarKey = keccak256(abi.encodePacked(scholarId));
        _latestAnchorIndex[scholarKey] = anchorId + 1; // +1 so 0 means "not found"

        emit ProfileAnchored(anchorId, scholarId, profileHash, block.timestamp);
        return anchorId;
    }

    /**
     * @notice Read a profile anchor by its index.
     */
    function getProfileAnchor(uint256 index) external view returns (ProfileAnchor memory) {
        require(index < profileAnchors.length, "Profile anchor index out of bounds");
        return profileAnchors[index];
    }

    /**
     * @notice Get the total number of profile anchors.
     */
    function getTotalProfileAnchors() external view returns (uint256) {
        return profileAnchors.length;
    }

    /**
     * @notice Look up the latest profile anchor for a given scholarId.
     * @return found  Whether an anchor exists for this scholar.
     * @return anchor The latest ProfileAnchor (empty if not found).
     */
    function getProfileAnchorByScholarId(string calldata scholarId)
        external
        view
        returns (bool found, ProfileAnchor memory anchor)
    {
        bytes32 scholarKey = keccak256(abi.encodePacked(scholarId));
        uint256 indexPlusOne = _latestAnchorIndex[scholarKey];
        if (indexPlusOne == 0) {
            return (false, ProfileAnchor("", bytes32(0), 0));
        }
        return (true, profileAnchors[indexPlusOne - 1]);
    }

    /**
     * @notice Helper to decode anchorScholarProfile arguments from raw tx input.
     *         Used by the mobile app's blockchain_service.dart for on-chain audit.
     */
    function decodeAnchorProfileHelper()
        external
        pure
        returns (string memory scholarId, bytes32 profileHash)
    {
        // This function is never actually called on-chain.
        // Its ABI output types are used by web3dart to decode raw tx input data.
        return ("", bytes32(0));
    }
}
