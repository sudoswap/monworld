// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

library ConstByteArray {
    function get(uint8 idx, bytes32 a, bytes32 b, bytes32 c, bytes32 d, bytes32 e, bytes32 f, bytes32 g, bytes32 h)
        internal
        pure
        returns (uint8)
    {
        if (idx < 32) return uint8(bytes1(a << idx));
        if (idx < 64) return uint8(bytes1(b << (idx - 32)));
        if (idx < 96) return uint8(bytes1(c << (idx - 64)));
        if (idx < 128) return uint8(bytes1(d << (idx - 96)));
        if (idx < 160) return uint8(bytes1(e << (idx - 128)));
        if (idx < 192) return uint8(bytes1(f << (idx - 160)));
        if (idx < 224) return uint8(bytes1(g << (idx - 192)));
        return uint8(bytes1(h << (idx - 224)));
    }
}
