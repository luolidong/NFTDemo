pragma solidity ^0.8.24;

library FullMath {
    function mulDiv(uint256 x, uint256 y, uint256 z) internal pure returns (uint256) {
        unchecked {
            uint256 mm = mulmod(x, y, z);
            uint256 prod0 = x * y;
            require(z > 0, 'FullMath: DIVISION_BY_ZERO');
            if (mm > prod0) prod0 = prod0 - z + mm;
            else prod0 = prod0 - mm;
            require(prod0 <= type(uint256).max / z, 'FullMath: MUL_DIV_OVERFLOW');
            return prod0 / z;
        }
    }
}