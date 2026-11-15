// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title Registre public des Passeports : état courant + historique
contract PassportRegistry is AccessControl {
    bytes32 public constant RECORDER_ROLE = keccak256("RECORDER_ROLE"); // PasseportSBT uniquement

    // kind : 0 mint, 1 niveau, 2 contesté, 3 contestation rejetée, 4 rétrogradé, 5 révoqué
    struct Entry { uint64 at; uint8 kind; uint8 level; }
    struct Creator { uint256 tokenId; uint8 level; bool contested; bool revoked; }

    address[] private _creators;
    mapping(address => Creator) public creators;
    mapping(uint256 => Entry[]) private _history;
    uint256 public openContests;

    event Recorded(
        address indexed creator, uint256 indexed tokenId, uint8 indexed kind, uint8 level, string cid, uint64 at
    );

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function record(address creator, uint256 tokenId, uint8 kind, uint8 level, string calldata cid)
        external onlyRole(RECORDER_ROLE)
    {
        Creator storage c = creators[creator];
        if (kind == 0) {
            _creators.push(creator);
            c.tokenId = tokenId;
        }
        c.level = level;
        if (kind == 2) {
            c.contested = true;
            ++openContests;
        } else if (kind >= 3) {
            if (c.contested) {
                c.contested = false;
                --openContests;
            }
            if (kind == 5) c.revoked = true;
        }
        _history[tokenId].push(Entry(uint64(block.timestamp), kind, level));
        emit Recorded(creator, tokenId, kind, level, cid, uint64(block.timestamp));
    }

    // ---------- Vues publiques ----------

    function creatorCount() external view returns (uint256) {
        return _creators.length;
    }

    /// @notice Pagination : évite les lectures trop lourdes.
    function creatorsPage(uint256 offset, uint256 limit)
        external view returns (address[] memory addrs, Creator[] memory data)
    {
        uint256 total = _creators.length;
        if (offset >= total) return (new address[](0), new Creator[](0));
        uint256 end = offset + limit > total ? total : offset + limit;
        addrs = new address[](end - offset);
        data = new Creator[](end - offset);
        for (uint256 i = offset; i < end; ++i) {
            addrs[i - offset] = _creators[i];
            data[i - offset] = creators[_creators[i]];
        }
    }

    function historyOf(uint256 tokenId) external view returns (Entry[] memory) {
        return _history[tokenId];
    }

    function isVerified(address creator) external view returns (bool ok, uint8 level) {
        Creator storage c = creators[creator];
        return (c.tokenId != 0 && !c.revoked && !c.contested, c.level);
    }
}
