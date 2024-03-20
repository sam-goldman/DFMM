// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./SetUp.sol";
import { computeTradingFunction } from "src/LogNormal/LogNormalMath.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

contract LogNormalSwapTest is LogNormalSetUp {
    using FixedPointMathLib for uint256;

    function test_LogNormal_swap_SwapsXforY() public init {
        uint256 preDfmmBalanceX = tokenX.balanceOf(address(dfmm));
        uint256 preDfmmBalanceY = tokenY.balanceOf(address(dfmm));

        uint256 preUserBalanceX = tokenX.balanceOf(address(this));
        uint256 preUserBalanceY = tokenY.balanceOf(address(this));

        uint256 amountIn = 0.1 ether;
        bool swapXForY = true;

        (bool valid, uint256 amountOut,, bytes memory payload) =
            solver.simulateSwap(POOL_ID, swapXForY, amountIn);
        assertEq(valid, true);

        console.log("amountOut:", amountOut);

        (,, uint256 inputAmount, uint256 outputAmount) =
            dfmm.swap(POOL_ID, address(this), payload);
        assertEq(tokenX.balanceOf(address(dfmm)), preDfmmBalanceX + inputAmount);
        assertEq(
            tokenY.balanceOf(address(dfmm)), preDfmmBalanceY - outputAmount
        );
        assertEq(tokenX.balanceOf(address(this)), preUserBalanceX - inputAmount);
        assertEq(
            tokenY.balanceOf(address(this)), preUserBalanceY + outputAmount
        );
    }

    function test_LogNormal_swap_SwapsYforX() public init {
        uint256 preDfmmBalanceX = tokenX.balanceOf(address(dfmm));
        uint256 preDfmmBalanceY = tokenY.balanceOf(address(dfmm));

        uint256 preUserBalanceX = tokenX.balanceOf(address(this));
        uint256 preUserBalanceY = tokenY.balanceOf(address(this));

        uint256 amountIn = 0.1 ether;
        bool swapXForY = false;

        (bool valid,,, bytes memory payload) =
            solver.simulateSwap(POOL_ID, swapXForY, amountIn);
        assertEq(valid, true);
        (,, uint256 inputAmount, uint256 outputAmount) =
            dfmm.swap(POOL_ID, address(this), payload);

        assertEq(tokenY.balanceOf(address(dfmm)), preDfmmBalanceY + inputAmount);
        assertEq(
            tokenX.balanceOf(address(dfmm)), preDfmmBalanceX - outputAmount
        );

        assertEq(tokenY.balanceOf(address(this)), preUserBalanceY - inputAmount);
        assertEq(
            tokenX.balanceOf(address(this)), preUserBalanceX + outputAmount
        );
    }

    // TODO: force payload to yield negative invariant and assert on revert
    function test_LogNormal_swap_RevertsIfInvariantNegative() public init {
        uint256 amountIn = 0.23 ether;

        (uint256[] memory preReserves, uint256 preTotalLiquidity) =
            solver.getReservesAndLiquidity(POOL_ID);

        LogNormalParams memory poolParams = solver.getPoolParams(POOL_ID);
        uint256 startL = solver.getNextLiquidity(
            POOL_ID, preReserves[0], preReserves[1], preTotalLiquidity
        );
        uint256 deltaLiquidity =
            amountIn.mulWadUp(poolParams.swapFee).divWadUp(poolParams.mean);

        uint256 ry = preReserves[1] + amountIn;
        uint256 L = startL + deltaLiquidity;
        uint256 approxPrice = solver.getPriceGivenYL(POOL_ID, ry, L);

        uint256 rx = solver.getNextReserveX(POOL_ID, ry, L, approxPrice);

        int256 invariant = computeTradingFunction(rx, ry, L, poolParams);
        while (invariant >= 0) {
            rx -= 1;
            invariant = computeTradingFunction(rx, ry, L, poolParams);
        }

        console2.log(invariant);

        uint256 amountOut = preReserves[0] - rx;

        bytes memory payload =
            abi.encode(1, 0, amountIn, amountOut, deltaLiquidity);

        vm.expectRevert();
        dfmm.swap(POOL_ID, address(this), payload);
    }

    function test_LogNormal_swap_ChargesCorrectFeesYIn() public deep {
        uint256 amountIn = 1 ether;
        bool swapXForY = false;

        (bool valid,,, bytes memory payload) =
            solver.simulateSwap(POOL_ID, swapXForY, amountIn);

        (,, uint256 inputAmount, uint256 outputAmount) =
            dfmm.swap(POOL_ID, address(this), payload);

        console2.log(inputAmount);
        console2.log(outputAmount);
    }

    function test_LogNormal_swap_ChargesCorrectFeesXIn() public deep {
        uint256 amountIn = 1 ether;
        bool swapXForY = true;

        (bool valid,,, bytes memory payload) =
            solver.simulateSwap(POOL_ID, swapXForY, amountIn);

        (,, uint256 inputAmount, uint256 outputAmount) =
            dfmm.swap(POOL_ID, address(this), payload);

        console2.log(inputAmount);
        console2.log(outputAmount);
    }

    function test_LogNormal_swap_WorksWith0dL() public deep {
        uint256 amountIn = 1 ether;
        bool swapXForY = true;

        (uint256[] memory initialReserves, uint256 initialLiquidity) = solver.getReservesAndLiquidity(POOL_ID);
        LogNormalParams memory initialParams = solver.getPoolParams(POOL_ID);

        int256 initialInvariant = computeTradingFunction(initialReserves[0], initialReserves[1], initialLiquidity, initialParams);

        console2.log("initial invariant: ", initialInvariant);

        (,,, bytes memory payload) =
            solver.simulateSwap(POOL_ID, swapXForY, amountIn);

        (,, uint256 computedDeltaIn, uint256 computedDeltaOut,) = abi.decode(payload, (uint256, uint256, uint256, uint256, uint256));

        bytes memory updatedPayload = abi.encode(0, 1, computedDeltaIn, computedDeltaOut + 0.002999999 ether, 0);

        (,, uint256 inputAmount, uint256 outputAmount) =
            dfmm.swap(POOL_ID, address(this), updatedPayload);

        (uint256[] memory nextReserves, uint256 nextLiquidity) = solver.getReservesAndLiquidity(POOL_ID);
        int256 nextInvariant = computeTradingFunction(nextReserves[0], nextReserves[1], nextLiquidity, initialParams);

        console2.log("next invariant: ", nextInvariant);
    }
}
