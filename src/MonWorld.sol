// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {LibMulticaller} from "multicaller/LibMulticaller.sol";
import "solady/Milady.sol";

import "./types/Types.sol";
import {MapGen} from "./lib/MapGen.sol";

struct Tile {
    Terrain terrain;
    bytes metadata;
}

struct PlayerPosition {
    Position currentPos;
    Position pendingPos;
    uint256 pendingPosBlock;
}

contract MonWorld {
    mapping(address player => PlayerPosition) internal _playerPositions;
    mapping(Position pos => TerrainType) internal _terrainCache;

    function move(MoveDirection dir) public virtual {
        address player = LibMulticaller.senderOrSigner();
        Position pos = getPlayerPosition(player);
        Position destPos = pos.applyMove(dir);
        // early return if already moving to that position
        if (_playerPositions[player].pendingPos == destPos) return;
        Tile memory destTile = getTileWrite(destPos);
        _playerPositions[player] = PlayerPosition({
            currentPos: pos,
            pendingPos: destPos,
            pendingPosBlock: block.number + destTile.terrain.blocksToMove
        });
    }

    function getPlayerPosition(address player) public view virtual returns (Position pos) {
        PlayerPosition memory playerPos = _playerPositions[player];
        pos = (block.number >= playerPos.pendingPosBlock && playerPos.pendingPosBlock != 0)
            ? playerPos.pendingPos
            : playerPos.currentPos;
    }

    function getTileView(Position pos) public view virtual returns (Tile memory tile) {
        // get base terrain type
        TerrainType ttype = _terrainCache[pos];
        if (ttype == TerrainType.NONE) {
            // generate terrain type and cache
            ttype = MapGen.getTerrainType(pos);
        }

        // TODO: apply overrides (e.g. buildings)

        return Tile({terrain: TerrainLib.ttypeToTerrain(ttype), metadata: ""});
    }

    function getTileWrite(Position pos) public virtual returns (Tile memory tile) {
        // get base terrain type
        TerrainType ttype = _terrainCache[pos];
        if (ttype == TerrainType.NONE) {
            // generate terrain type and cache
            ttype = MapGen.getTerrainType(pos);
            _terrainCache[pos] = ttype;
        }

        // TODO: apply overrides (e.g. buildings)

        return Tile({terrain: TerrainLib.ttypeToTerrain(ttype), metadata: ""});
    }
}
