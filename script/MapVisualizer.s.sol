// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

import "solady/Milady.sol";

import "../src/lib/MapGen.sol";
import "../src/types/Types.sol";

contract MapVisualizerScript is Script {
    using PositionLib for Position;
    using LibString for *;

    function run() public {
        vm.pauseGasMetering();

        // ANSI color codes
        string memory BLUE = "\x1b[34m"; // Water
        string memory GREEN = "\x1b[32m"; // Grassland
        string memory CYAN = "\x1b[36m"; // Forest
        string memory GRAY = "\x1b[90m"; // Mountain
        string memory RESET = "\x1b[0m"; // Reset color

        // Symbols for different terrain types
        string memory WATER_SYMBOL = unicode"██";
        string memory GRASSLAND_SYMBOL = unicode"██";
        string memory FOREST_SYMBOL = unicode"██";
        string memory MOUNTAIN_SYMBOL = unicode"██";
        string memory NONE_SYMBOL = " ";

        int128 mapSize = 50;
        console.log(
            string.concat(
                "Generating map for region x: [-",
                mapSize.toString(),
                ", ",
                mapSize.toString(),
                "], y: [-",
                mapSize.toString(),
                ", ",
                mapSize.toString(),
                "]"
            )
        );

        // Map the region (y decreasing to make north at the top)
        for (int128 y = mapSize; y >= -mapSize; y--) {
            string memory line = "";

            for (int128 x = -mapSize; x <= mapSize; x++) {
                Position pos = PositionLib.fromCoordinates(x, y);
                TerrainType terrainType = MapGen.getTerrainType(pos);

                // Add colored symbol based on terrain type
                if (terrainType == TerrainType.WATER) {
                    line = string(abi.encodePacked(line, BLUE, WATER_SYMBOL, RESET));
                } else if (terrainType == TerrainType.GRASSLAND) {
                    line = string(abi.encodePacked(line, GREEN, GRASSLAND_SYMBOL, RESET));
                } else if (terrainType == TerrainType.FOREST) {
                    line = string(abi.encodePacked(line, CYAN, FOREST_SYMBOL, RESET));
                } else if (terrainType == TerrainType.MOUNTAIN) {
                    line = string(abi.encodePacked(line, GRAY, MOUNTAIN_SYMBOL, RESET));
                } else {
                    line = string(abi.encodePacked(line, NONE_SYMBOL));
                }
            }

            // Print the line
            console.log(line);
        }

        // Create a legend for the terrain types
        console.log("\nLegend:");
        console.log(string(abi.encodePacked(BLUE, WATER_SYMBOL, RESET, " - Water")));
        console.log(string(abi.encodePacked(GREEN, GRASSLAND_SYMBOL, RESET, " - Grassland")));
        console.log(string(abi.encodePacked(CYAN, FOREST_SYMBOL, RESET, " - Forest")));
        console.log(string(abi.encodePacked(GRAY, MOUNTAIN_SYMBOL, RESET, " - Mountain")));
    }
}
