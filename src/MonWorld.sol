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
    using DynamicArrayLib for *;
    using EnumerableSetLib for EnumerableSetLib.AddressSet;

    mapping(address player => PlayerPosition) internal _playerPositions;
    mapping(Position pos => TerrainType) internal _terrainCache;
    mapping(Position pos => TerrainType) internal _structures;
    mapping(Position pos => EnumerableSetLib.AddressSet) internal _playersAtPos;

    event Spawn(address indexed player, Position indexed pos);
    event Move(address indexed player, Position indexed from, Position indexed to, uint256 pendingBlock);
    event Put(address indexed player, Position indexed pos, TerrainType indexed ttype);

    function spawn(Position pos) public virtual {
        address player = LibMulticaller.senderOrSigner();
        require(_playerPositions[player].pendingPosBlock == 0, "Already spawned");
        _playerPositions[player] = PlayerPosition({currentPos: pos, pendingPos: pos, pendingPosBlock: block.number});
        _playersAtPos[pos].add(player);

        emit Spawn(player, pos);
    }

    function move(MoveDirection dir) public virtual {
        address player = LibMulticaller.senderOrSigner();
        require(_playerPositions[player].pendingPosBlock != 0, "Not spawned");
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
        _playersAtPos[pos].add(player);

        emit Move(player, pos, destPos, block.number + destTile.terrain.blocksToMove);
    }

    function put(MoveDirection dir, TerrainType ttype) public virtual {
        require(ttype.isStructure(), "Not a structure");

        address player = LibMulticaller.senderOrSigner();
        Position pos = getPlayerPosition(player);
        Position destPos = pos.applyMove(dir);
        _structures[destPos] = ttype;

        emit Put(player, destPos, ttype);
    }

    function getPlayerPosition(address player) public view virtual returns (Position pos) {
        PlayerPosition memory playerPos = _playerPositions[player];
        pos = (block.number >= playerPos.pendingPosBlock && playerPos.pendingPosBlock != 0)
            ? playerPos.pendingPos
            : playerPos.currentPos;
    }

    function getPlayersAtPos(Position pos) public view virtual returns (address[] memory) {
        DynamicArrayLib.DynamicArray memory result;

        // filter out players in pos that have already moved out of it
        {
            address[] memory initialPlayers = _playersAtPos[pos].values();
            Position playerPos;
            for (uint256 i; i < initialPlayers.length; i++) {
                playerPos = getPlayerPosition(initialPlayers[i]);
                if (playerPos == pos) {
                    result.p(initialPlayers[i]);
                }
            }
        }

        // add players in adjacent positions if the pending position is `pos` and it's already been applied
        Position neighbor;
        address[] memory neighborPlayers;
        Position neighborPlayerPos;
        for (uint256 i; i <= uint8(type(MoveDirection).max); i++) {
            neighbor = pos.applyMove(MoveDirection(uint8(i)));
            neighborPlayers = _playersAtPos[neighbor].values();
            for (uint256 j; j < neighborPlayers.length; j++) {
                neighborPlayerPos = getPlayerPosition(neighborPlayers[j]);
                if (neighborPlayerPos == pos) {
                    result.p(neighborPlayers[j]);
                }
            }
        }

        return result.asAddressArray();
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
