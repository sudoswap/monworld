// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import "./TerrainType.sol";

struct Terrain {
    TerrainType ttype;
    uint256 blocksToMove;
}

library TerrainLib {
    bytes private constant BLOCKS_TO_MOVE_LOOKUP =
        abi.encode([type(uint128).max, type(uint128).max, 10, 20, type(uint128).max]);

    function ttypeToTerrain(TerrainType ttype) internal pure returns (Terrain memory terrain) {
        uint256[] memory blocksToMoveLookup = abi.decode(BLOCKS_TO_MOVE_LOOKUP, (uint256[]));
        terrain = Terrain({ttype: ttype, blocksToMove: blocksToMoveLookup[uint8(ttype)]});
    }
}
