// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import "solady/Milady.sol";

import "./ConstByteArray.sol";

library SimplexNoise {
    using SafeCastLib for *;
    using FixedPointMathLib for *;

    int256 internal constant WAD = 1 ether;
    int256 internal constant PERIOD = 256;

    // Simplex skew constants
    // Scaled by 1e18 (WAD)
    int256 internal constant _F2 = 366025403784438646;
    int256 internal constant _G2 = 211324865405187117;

    function noise(int128 x, int128 y, bytes32 permA, bytes32 permB, bytes32 permC, bytes32 permD)
        internal
        pure
        returns (int256 noise)
    {
        // Skew input space to determine which simplex (triangle) we are in
        int256 sWad = (x + y) * _F2;
        int256 i = divWadDown(x * WAD + sWad);
        int256 j = divWadDown(y * WAD + sWad);
        int256 tWad = (i + j) * _G2;

        // "Unskewed" distances from cell origin
        int256 x0Wad = x * WAD - (i * WAD - tWad);
        int256 y0Wad = y * WAD - (j * WAD - tWad);

        (int256 i1Wad, int256 j1Wad, uint8 i1, uint8 j1) = x0Wad > y0Wad ? (WAD, 0, 1, 0) : (0, WAD, 0, 1);

        // Offsets for middle corner in (x,y) unskewed coords
        int256 x1Wad = x0Wad - i1Wad + _G2;
        int256 y1Wad = y0Wad - j1Wad + _G2;

        // Offsets for last corner in (x,y) unskewed coords
        int256 x2Wad = x0Wad + _G2 * 2 - WAD;
        int256 y2Wad = y0Wad + _G2 * 2 - WAD;

        // Determine hashed gradient indices of the three simplex corners
        uint8 ii = uint8(int8(i % PERIOD));
        uint8 jj = uint8(int8(j % PERIOD));
        uint8 gi0;
        uint8 gi1;
        uint8 gi2;
        unchecked {
            gi0 = ConstByteArray.get(
                ii + ConstByteArray.get(jj, permA, permB, permC, permD), permA, permB, permC, permD
            ) % 12;
            gi1 = ConstByteArray.get(
                ii + i1 + ConstByteArray.get(jj + j1, permA, permB, permC, permD), permA, permB, permC, permD
            ) % 12;
            gi2 = ConstByteArray.get(
                ii + 1 + ConstByteArray.get(jj + 1, permA, permB, permC, permD), permA, permB, permC, permD
            ) % 12;
        }

        // Calculate the contribution from the three corners
        int256 ttWad = WAD / 2 - x0Wad.sMulWad(x0Wad) - y0Wad.sMulWad(y0Wad);
        uint256 ttWadAbs = FixedPointMathLib.abs(ttWad);
        int256 gx;
        int256 gy;
        if (ttWad > 0) {
            (gx, gy) = grad3(gi0);
            noise = ttWadAbs.rpow(4, FixedPointMathLib.WAD).toInt256() * (gx * x0Wad + gy * y0Wad);
        } else {
            noise = 0;
        }

        ttWad = WAD / 2 - x1Wad.sMulWad(x1Wad) - y1Wad.sMulWad(y1Wad);
        ttWadAbs = FixedPointMathLib.abs(ttWad);
        if (ttWad > 0) {
            (gx, gy) = grad3(gi1);
            noise += ttWadAbs.rpow(4, FixedPointMathLib.WAD).toInt256() * (gx * x1Wad + gy * y1Wad);
        }

        ttWad = WAD / 2 - x2Wad.sMulWad(x2Wad) - y2Wad.sMulWad(y2Wad);
        ttWadAbs = FixedPointMathLib.abs(ttWad);
        if (ttWad > 0) {
            (gx, gy) = grad3(gi2);
            noise += ttWadAbs.rpow(4, FixedPointMathLib.WAD).toInt256() * (gx * x2Wad + gy * y2Wad);
        }

        // Scale noise to [-WAD, WAD]
        return noise * 70;
    }

    /// @dev 3D Gradient vectors
    /// _GRAD3 = ((1,1,0),(-1,1,0),(1,-1,0),(-1,-1,0),
    /// 	(1,0,1),(-1,0,1),(1,0,-1),(-1,0,-1),
    /// 	(0,1,1),(0,-1,1),(0,1,-1),(0,-1,-1),
    /// 	(1,1,0),(0,-1,1),(-1,1,0),(0,-1,-1),
    /// )
    function grad3(uint8 idx) internal pure returns (int256 gx, int256 gy) {
        // compute gx
        gx = idx < 8 ? (idx % 2 == 0 ? 1 : -1) : 0;

        // compute gy
        gy = idx < 2 ? 1 : (idx < 4 ? -1 : (idx < 8 ? 0 : (idx % 2 == 0 ? 1 : -1)));
    }

    function divWadDown(int256 a) internal pure returns (int256 z) {
        z = a / WAD;
        if (a < 0 && a % WAD != 0) z--; // round towards negative infinity
    }
}
