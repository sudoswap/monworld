// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

library ConstByteArray {
    function get(uint8 idx, bytes32 a, bytes32 b, bytes32 c, bytes32 d) internal pure returns (uint8) {
        if (idx < 32) return uint8(bytes1(a << idx));
        if (idx < 64) return uint8(bytes1(b << (idx - 32)));
        if (idx < 96) return uint8(bytes1(c << (idx - 64)));
        return uint8(bytes1(d << (idx - 96)));
    }
}
