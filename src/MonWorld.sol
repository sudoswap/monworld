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
    mapping(Position pos => TerrainType) internal _structures;

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

    function put(MoveDirection dir, TerrainType ttype) public virtual {
        require(ttype.isStructure(), "Not a structure");

        Position pos = getPlayerPosition(msg.sender);
        Position destPos = pos.applyMove(dir);
        _structures[destPos] = ttype;
    }

    function getPlayerPosition(address player) public view virtual returns (Position pos) {
        PlayerPosition memory playerPos = _playerPositions[player];
        pos = (block.number >= playerPos.pendingPosBlock && playerPos.pendingPosBlock != 0)
            ? playerPos.pendingPos
            : playerPos.currentPos;
    }

    function getTileView(Position pos) public view virtual returns (Tile memory tile) {
        TerrainType ttype;

        // check for structures
        ttype = _structures[pos];
        if (ttype != TerrainType.NONE) {
            return Tile({terrain: TerrainLib.ttypeToTerrain(ttype), metadata: ""});
        }

        // get base terrain type
        ttype = _terrainCache[pos];
        if (ttype == TerrainType.NONE) {
            // generate terrain type and cache
            ttype = MapGen.getTerrainType(pos);
        }

        return Tile({terrain: TerrainLib.ttypeToTerrain(ttype), metadata: ""});
    }

    function getTileWrite(Position pos) public virtual returns (Tile memory tile) {
        TerrainType ttype;

        // check for structures
        ttype = _structures[pos];
        if (ttype != TerrainType.NONE) {
            return Tile({terrain: TerrainLib.ttypeToTerrain(ttype), metadata: ""});
        }

        // get base terrain type
        ttype = _terrainCache[pos];
        if (ttype == TerrainType.NONE) {
            // generate terrain type and cache
            ttype = MapGen.getTerrainType(pos);
            _terrainCache[pos] = ttype;
        }

        return Tile({terrain: TerrainLib.ttypeToTerrain(ttype), metadata: ""});
    }
}
