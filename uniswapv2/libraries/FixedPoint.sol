pragma solidity ^0.8.24;

library FixedPoint {
    struct uq112x112 {
        uint224 _x;
    }

    struct uq144x112 {
        uint256 _x;
    }

    uint8 public constant RESOLUTION = 112;
    uint256 public constant Q112 = 0x10000000000000000000000000000;
    uint256 public constant Q224 = 0x10000000000000000000000000000000000000000000000000000;

    function decode112with18(uint224 x) internal pure returns (uint256) {
        return uint256(x) * 1e18 / Q112;
    }

    function wrap(uint224 x) internal pure returns (uq112x112 memory) {
        return uq112x112({_x: x});
    }

    function wrap144(uint256 x) internal pure returns (uq144x112 memory) {
        return uq144x112({_x: x});
    }

    function mul(uq112x112 memory self, uint256 y) internal pure returns (uq144x112 memory) {
        uint256 z = uint256(self._x) * y;
        return uq144x112({_x: z});
    }

    function decode144(uq144x112 memory self) internal pure returns (uint256) {
        return self._x / Q112;
    }

    function fraction(uint256 numerator, uint256 denominator) internal pure returns (uq112x112 memory) {
        require(denominator > 0, 'FixedPoint: DIVISION_BY_ZERO');
        uint256 result = numerator * Q112 / denominator;
        return uq112x112({_x: uint224(result)});
    }
}