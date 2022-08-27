// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import "../Libraries/Math.sol";
import "../Libraries/SqrtPriceMath.sol";

/// @title Used for swapping the amount within ticks
/// @notice Will compute particular tick from which the swapping will be done

library SwapMath {
    /// @notice Used for swapping the amount in or out , with given parameters
    /// @dev fee and amount which is to be swapped , will never exceed the amount
    /// @param sqrtCurrentPX96 Pool current price
    /// @param sqrtTargetPX96 Price cannot exceed from where the last swapping has been made
    /// @param liquidity Liquidity which is usable inside pool
    /// @param amtRemaining Remaining input and output amount which will be used for swapping
    /// @param fee Fee which is taken from the input amount , expressed in Basis Point(bp) interest rate
    /// @return sqrtNextPX96 The price after swapping the amount in/out, not to exceed the price from the last swap price
    /// @return amountIn The amount to be swapped in, of either token0 or token1, based on the direction of the swap
    /// @return amountOut The amount to be received, of either token0 or token1, based on the direction of the swap
    /// @return feeAmount The amount of input that will be taken as a fee

    function Swapping(
        uint160 sqrtCurrentPX96,
        uint160 sqrtTargetPX96,
        uint128 liquidity,
        int256 amtRemaining,
        uint24 fee
    )
        internal
        pure
        returns (
            uint160 sqrtNextPX96,
            uint256 amountIn,
            uint256 amountOut,
            uint256 feeAmount
        )
    {
        bool Check = sqrtCurrentPX96 >= sqrtTargetPX96;
        bool Inputamount = amtRemaining >= 0;

        if (Inputamount) {
            uint256 amtwithlessfee = Math.mulDiv(
                uint256(amtRemaining),
                1e6 - fee,
                1e6
            );
            amountIn = Check
                ? SqrtPriceMath.getAmt0Delta(
                    sqrtTargetPX96,
                    sqrtCurrentPX96,
                    liquidity,
                    true
                )
                : SqrtPriceMath.getAmt1Delta(
                    sqrtCurrentPX96,
                    sqrtTargetPX96,
                    liquidity,
                    true
                );
            if (amtwithlessfee >= amountIn) sqrtNextPX96 = sqrtTargetPX96;
            else
                sqrtNextPX96 = SqrtPriceMath.getNextSqrtPriceFromInput(
                    sqrtCurrentPX96,
                    liquidity,
                    amtwithlessfee,
                    Check
                );
        } else {
            amountOut = Check
                ? SqrtPriceMath.getAmt1Delta(
                    sqrtTargetPX96,
                    sqrtCurrentPX96,
                    liquidity,
                    false
                )
                : SqrtPriceMath.getAmt1Delta(
                    sqrtCurrentPX96,
                    sqrtTargetPX96,
                    liquidity,
                    false
                );
        }
        bool max = sqrtTargetPX96 == sqrtNextPX96;
        // get the amount for Input and Output
        if (Check) {
            amountIn = max && Inputamount
                ? amountIn
                : SqrtPriceMath.getAmt0Delta(
                    sqrtNextPX96,
                    sqrtCurrentPX96,
                    liquidity,
                    true
                );
            amountOut = max && !Inputamount // ! will reverse the function and work as per the usecase
                ? amountOut
                : SqrtPriceMath.getAmt1Delta(
                    sqrtNextPX96,
                    sqrtCurrentPX96,
                    liquidity,
                    false
                );
        } else {
            amountIn = max && Inputamount
                ? amountIn
                : SqrtPriceMath.getAmt1Delta(
                    sqrtCurrentPX96,
                    sqrtNextPX96,
                    liquidity,
                    false
                );
        }
        // amount which is to be recieve must not be more than the recieve amount(calculation must be correct)
        if (!Inputamount && amountOut > uint256(-amtRemaining)) {
            amountOut = uint256(-amtRemaining);
        }
        if (Inputamount && sqrtNextPX96 != sqrtTargetPX96) {
            // will cover the fee amount , if there is no tick/target for that required token
            feeAmount = uint256(amtRemaining) - amountIn;
        } else {
            feeAmount = Math.RoundingUp(amountIn, fee, 1e6 - fee);
        }
    }
}
