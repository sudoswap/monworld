// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {LibMulticaller} from "multicaller/LibMulticaller.sol";
import "solady/Milady.sol";

import "./types/Types.sol";

struct Terrain {
    uint256 id;
    uint256 blocksToMove;
    string name;
}

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

    function move(MoveDirection dir) public virtual {
        address player = LibMulticaller.senderOrSigner();
        Position pos = getPlayerPosition(player);
        Tile memory destTile = getTile(pos.applyMove(dir));
        _playerPositions[player] = PlayerPosition({
            currentPos: pos,
            pendingPos: pos.applyMove(dir),
            pendingPosBlock: block.number + destTile.terrain.blocksToMove
        });
    }

    function getPlayerPosition(address player) public view virtual returns (Position pos) {
        PlayerPosition memory playerPos = _playerPositions[player];
        pos = (block.number >= playerPos.pendingPosBlock && playerPos.pendingPosBlock != 0)
            ? playerPos.pendingPos
            : playerPos.currentPos;
    }

    function getTile(Position pos) public view virtual returns (Tile memory tile) {}
}
