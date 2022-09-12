// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Counter.sol";
import "../src/contracts/custom/NamelessSales.sol";

contract NamelessSalesTest is Test {
    NamelessSales namelessSales;

    function setUp() public {
       namelessSales = new NamelessSales();
    }

    function testAssignBenefactor() public {
        assertEq(namelessSales.benefactor(), msg.sender);
    }

    function testSetNumber(uint256 x) public {
        counter.setNumber(x);
        assertEq(counter.number(), x);
    }
}
