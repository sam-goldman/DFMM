// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import "solstat/Gaussian.sol";
import "./LogNormalMathLib.sol";

using FixedPointMathLib for uint256;
using FixedPointMathLib for int256;

/// @dev Parameterization of the Log Normal curve.
struct Parameters {
    uint256 strikePriceWad;
    uint256 sigmaPercentWad;
    uint256 tauYearsWad;
}

/// @dev Structure to hold reserve information
struct Reserves {
    uint256 rx;
    uint256 ry;
    uint256 L;
}

function tradingFunction(
    uint256 reserveXWad,
    uint256 reserveYWad,
    uint256 totalLiquidity,
    Parameters memory params
) pure returns (int256) {
    require(reserveXWad < totalLiquidity, "tradingFunction: invalid x");

    int256 AAAAA;
    int256 BBBBB;
    if (FixedPointMathLib.divWadDown(reserveXWad, totalLiquidity) >= ONE) {
        AAAAA = int256(2 ** 255 - 1);
    } else {
        AAAAA = Gaussian.ppf(
            int256(FixedPointMathLib.divWadDown(reserveXWad, totalLiquidity))
        );
    }
    if (
        FixedPointMathLib.divWadDown(
            reserveYWad,
            FixedPointMathLib.mulWadDown(params.strikePriceWad, totalLiquidity)
        ) >= ONE
    ) {
        BBBBB = int256(2 ** 255 - 1);
    } else {
        BBBBB = Gaussian.ppf(
            int256(
                FixedPointMathLib.divWadDown(
                    reserveYWad,
                    FixedPointMathLib.mulWadDown(
                        params.strikePriceWad, totalLiquidity
                    )
                )
            )
        );
    }

    int256 CCCCC =
        int256(computeSigmaSqrtTau(params.sigmaPercentWad, params.tauYearsWad));

    return AAAAA + BBBBB + CCCCC;
}

function computeHalfSigmaSquared(uint256 sigmaPercentWad)
    pure
    returns (uint256)
{
    int256 sigmaSquaredWad = int256(sigmaPercentWad).powWad(int256(TWO));
    return HALF.mulWadDown(uint256(sigmaSquaredWad));
}

/// @dev Computes the approximated spot price given current reserves and liquidity.
function computePrice(
    uint256 rx,
    uint256 L,
    uint256 K,
    uint256 sigma,
    uint256 tau
) pure returns (uint256 price) {
    uint256 sigmaSqrtTau = computeSigmaSqrtTau(sigma, tau);
    uint256 halfSigmaSquared = computeHalfSigmaSquared(sigma);
    uint256 halfSigmaSquaredTau = halfSigmaSquared.mulWadDown(tau);

    // Gaussian.ppf has a range of [-inf, inf], so we need to make sure the input is in [0, 1].
    int256 reserveXDivLiquidity = int256(rx.divWadDown(L));
    // As x -> 1, price -> 0.
    if (reserveXDivLiquidity >= int256(ONE)) {
        return 0;
    }
    // As x -> 0, price -> infinity.
    if (reserveXDivLiquidity <= int256(ZERO)) {
        // todo: can returning an infinity price be worse than returning zero or reverting?
        return INFINITY_IS_NOT_REAL;
    }
    // The output can be negative so we have to be careful not to lose that information by casting.
    int256 inverse_cdf_result = Gaussian.ppf(int256(ONE) - reserveXDivLiquidity);
    int256 exponent = inverse_cdf_result * int256(sigmaSqrtTau) / int256(ONE)
        - int256(halfSigmaSquaredTau);

    // This result cannot be negative!
    int256 exp_result = FixedPointMathLib.expWad(exponent);
    uint256 exp_result_uint = toUint(exp_result);
    price = K.mulWadUp(exp_result_uint);
}

/// @dev Casts a positived signed integer to an unsigned integer, reverting if `x` is negative.
function toUint(int256 x) pure returns (uint256) {
    unchecked {
        require(x >= 0, "toUint: negative");
        return uint256(x);
    }
}
