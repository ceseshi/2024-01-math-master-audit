// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.4;

import {Base_Test, console2} from "./Base_Test.t.sol";
import {MathMasters} from "src/MathMasters.sol";

/*
 * PoC before the mitigations
*/
contract MathMastersTestAudit is Base_Test {
    function testMulWadRevert() public {
        uint256 x = type(uint256).max / 2;
        uint256 y = 100;
        vm.expectRevert(0x00000000);
        uint256 r = MathMasters.mulWad(x, y);
        assertEq(r, (x * y - 1) / 1e18 + 1);
    }

    function testMulWadUpRevert() public {
        uint256 x = type(uint256).max / 2;
        uint256 y = 100;
        vm.expectRevert(0x00000000);
        uint256 r = MathMasters.mulWadUp(x, y);
        assertEq(r, (x * y - 1) / 1e18 + 1);
    }

    function testMulWadUpOverflow1() public pure {
        uint256 y = 100;
        uint256 x = (type(uint256).max / y) + 1;
        uint256 r = MathMasters.mulWadUp(x, y);
        console2.log("r", r);
    }

    function testMulWadUpOverflow2() public {
        uint256 x = 149453833408801632100269689951836288089;
        uint256 y = 79700981937175649427451356571001433277;
        assertEq(MathMasters.mulWadUp(x, y), (x * y - 1) / 1e18 + 1);
    }

    function testMulWadUpOverflow3() public {
        uint256 y = MathMasters.sqrt(type(uint256).max);
        uint256 x = type(uint256).max / y + 1;
        uint256 r = MathMasters.mulWadUp(x, y);
        console2.log("r", r);
    }

    function testMulWadUpOverflowFuzz(uint256 x, uint256 y) public {
        vm.assume(x != 0);
        vm.assume(y != 0);
        vm.assume(x <= type(uint256).max / y);
        assertEq(MathMasters.mulWadUp(x, y), (x * y - 1) / 1e18 + 1);
    }
}