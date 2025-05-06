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

contract MonWorld {
    using DynamicArrayLib for *;
    using EnumerableSetLib for EnumerableSetLib.AddressSet;

    mapping(address player => bool) internal _hasSpawned;
    mapping(address player => Position) internal _playerPositions;
    mapping(address player => mapping(uint256 blockNum => uint256)) internal _playerEnergySpentInBlock;
    mapping(Position pos => TerrainType) internal _terrainCache;
    mapping(Position pos => TerrainType) internal _structures;
    mapping(Position pos => EnumerableSetLib.AddressSet) internal _playersAtPos;

    event Spawn(address indexed player, Position indexed pos);
    event Move(address indexed player, Position indexed from, Position indexed to);
    event Put(address indexed player, Position indexed pos, TerrainType indexed ttype);

    function spawn(int128 x, int128 y) public virtual {
        address player = LibMulticaller.senderOrSigner();

        require(!_hasSpawned[player], "Already spawned");

        Position pos = PositionLib.fromCoordinates(x, y);
        _playerPositions[player] = pos;
        _playersAtPos[pos].add(player);
        _hasSpawned[player] = true;

        emit Spawn(player, pos);
    }

    function move(MoveDirection dir) public virtual {
        address player = LibMulticaller.senderOrSigner();
        require(_hasSpawned[player], "Not spawned");

        // read player position & tile info
        Position pos = _playerPositions[player];
        Position destPos = pos.applyMove(dir);
        Tile memory destTile = getTileWrite(destPos.x(), destPos.y());

        // expend energy
        uint256 energySpent = _playerEnergySpentInBlock[player][block.number] + destTile.terrain.energyCost;
        require(energySpent <= TerrainLib.ENERGY_PER_BLOCK, "Not enough energy");
        _playerEnergySpentInBlock[player][block.number] = energySpent;

        // move player
        _playerPositions[player] = destPos;
        _playersAtPos[pos].remove(player);
        _playersAtPos[destPos].add(player);

        emit Move(player, pos, destPos);
    }

    function put(MoveDirection dir, TerrainType ttype) public virtual {
        require(ttype.isStructure(), "Not a structure");

        address player = LibMulticaller.senderOrSigner();
        Position pos = _playerPositions[player];
        Position destPos = pos.applyMove(dir);
        _structures[destPos] = ttype;

        emit Put(player, destPos, ttype);
    }

    /// -----------------------------------------------------------------------
    /// Getters
    /// -----------------------------------------------------------------------

    function getHasSpawned(address player) public view virtual returns (bool) {
        return _hasSpawned[player];
    }

    function getPlayerPosition(address player) public view virtual returns (int128 x, int128 y) {
        return (_playerPositions[player].x(), _playerPositions[player].y());
    }

    function getEnergySpentInBlock(address player, uint256 blockNum) public view virtual returns (uint256) {
        return _playerEnergySpentInBlock[player][blockNum];
    }

    function getPlayersAtPos(int128 x, int128 y) public view virtual returns (address[] memory) {
        DynamicArrayLib.DynamicArray memory result;
        Position pos = PositionLib.fromCoordinates(x, y);

        // filter out players in pos that have already moved out of it
        {
            address[] memory initialPlayers = _playersAtPos[pos].values();
            Position playerPos;
            for (uint256 i; i < initialPlayers.length; i++) {
                playerPos = _playerPositions[initialPlayers[i]];
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
                neighborPlayerPos = _playerPositions[neighborPlayers[j]];
                if (neighborPlayerPos == pos) {
                    result.p(neighborPlayers[j]);
                }
            }
        }

        return result.asAddressArray();
    }

    function getTileView(int128 x, int128 y) public view virtual returns (Tile memory tile) {
        Position pos = PositionLib.fromCoordinates(x, y);
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

    function getTtypeView(int128 x, int128 y) public view virtual returns (TerrainType ttype) {
        Position pos = PositionLib.fromCoordinates(x, y);

        // check for structures
        ttype = _structures[pos];
        if (ttype != TerrainType.NONE) {
            return ttype;
        }

        // get base terrain type
        ttype = _terrainCache[pos];
        if (ttype == TerrainType.NONE) {
            // generate terrain type
            return MapGen.getTerrainType(pos);
        }

        return ttype;
    }

    function getTtypesPacked(int128[] calldata xList, int128[] calldata yList)
        external
        view
        virtual
        returns (bytes memory packedTtypes)
    {
        require(xList.length == yList.length, "Length mismatch");
        packedTtypes = new bytes(xList.length);
        for (uint256 i; i < xList.length; i++) {
            packedTtypes[i] = bytes1(uint8(getTtypeView(xList[i], yList[i])));
        }
    }

    function getTileWrite(int128 x, int128 y) public virtual returns (Tile memory tile) {
        Position pos = PositionLib.fromCoordinates(x, y);
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
