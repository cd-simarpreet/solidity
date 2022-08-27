// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/// @title Used in swapping.
/// @notice Used to calculate the range between upper and lower range through spacing. User to get liquidity between the boundries of ranges.
/// @dev Function will provide the usage of certain ranges to provide liquidation to user and to calculate the reward/loss of user investment in there range.

import "@uniswap/contracts/libraries/LowGasSafeMath.sol";
import "@uniswap/contracts/libraries/SafeCast.sol";
import "./Math.sol";
import "@uniswap/contracts/libraries/UnsafeMath.sol";
import "@uniswap/contracts/libraries/FixedPoint96.sol";

library SqrtPriceMath {
    using LowGasSafeMath for uint256;
    using SafeCast for uint256;

    /// @notice Gets the next sqrt price given a delta of token0
    /// @dev Rounding up (Eg; when a user swap Eth >> Dai then the supply of Eth will increase and Supply of Dai decrease in Eth(token1)/Dai(token0) pool.
    /// Making Eth and Dai Price Fluctuations.
    /// Now the reserve from which the user gets the dai in exchange of eth will be of third party user tick range(Eth/Dai) which is known as real reserve(which will be active).
    /// If the user have enough dai in its range then the supply will be from respective reserve.
    /// But if not then the range will go up (increasing price) for the respective demand where liquidity is been used from virtual reserve ) .
    /// Since tick price range has gone up but to make suitable swap with a given Amt of eth wrt dai this calculation takes place.
    /// The most precise formula for this is liquidity * sqrtPX96 / (liquidity +- Amt * sqrtPX96),
    /// if this is impossible because of overflow, we calculate liquidity / (liquidity / sqrtPX96 +- Amt).
    /// In rounding up the tick will work from low to high
    /// @param sqrtPX96 Initial price of user before delta of token0
    /// @param liquidity The Amt of usable liquidity
    /// @param Amt How much of token0 to add or remove from virtual reserves
    /// @param add Whether to add or remove the Amt of token0
    /// @return The price after adding or removing Amt, depending on add
    function NextsqrtPriceForToken0Upwards(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 Amt,
        bool add
    ) internal pure returns (uint160) {
        // If the InputAmt is already in respective reserve
        if (Amt == 0) return sqrtPX96;
        uint256 numerator1 = uint256(liquidity) << FixedPoint96.RESOLUTION;

        if (add) {
            uint256 prod;
            if ((prod = Amt * sqrtPX96) / Amt == sqrtPX96) {
                uint256 denominator = numerator1 + prod;
                if (denominator >= numerator1)
                    // always fits in 160 bits
                    // 160 - 96 = 64 bits
                    return
                        uint160(
                            Math.RoundingUp(numerator1, sqrtPX96, denominator)
                        );
            }

            return
                uint160(
                    UnsafeMath.divRoundingUp(
                        numerator1,
                        (numerator1 / sqrtPX96).add(Amt)
                    )
                );
        } else {
            uint256 prod;
            //denominator or lower fraction must not be underflow
            require(
                (prod = Amt * sqrtPX96) / Amt == sqrtPX96 && numerator1 > prod
            );
            uint256 denominator = numerator1 - prod;
            return
                Math.RoundingUp(numerator1, sqrtPX96, denominator).toUint160();
        }
    }

    /// @notice Gets the next sqrt price given a delta of token1
    /// @dev rounds down, if the liquidity of Eth/Dai if we swap Dai >> Eth . The price of Dai will decrease and price of eth increase
    /// becoz of supply and demand . Now tick which consist of Dai will decrease and ViceVersa for Eth .
    /// Real reserve which have a quantity Dai (DAI/Eth reserve depending upon the tick) but no eth or less eth it will go down to search
    /// other tick range(real reserve). so that it can stabalize the swap.
    /// The formula we compute is within <1 wei of the lossless version: sqrtPX96 +- Amt / liquidity
    /// In this case the ticks will be working high to low
    /// @param sqrtPX96 Initial price of user before delta of token1
    /// @param liquidity The Amt of usable liquidity
    /// @param Amt How much of token1 to add, or remove, from virtual reserves
    /// @param add Whether to add, or remove, the Amt of token1
    /// @return The price after adding or removing `Amt`
    function NextsqrtPriceForToken1Downwards(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 Amt,
        bool add
    ) internal pure returns (uint160) {
        // adding require liquidity , by rounding the tick high to low (increasing the price in a demand and supply manner)
        if (add) {
            uint256 Usage = (
                Amt <= type(uint160).max
                    ? (Amt << FixedPoint96.RESOLUTION) / liquidity
                    : Math.mulDiv(Amt, FixedPoint96.Q96, liquidity)
            );

            return uint256(sqrtPX96).add(Usage).toUint160();
        } else {
            uint256 Usage = (
                Amt <= type(uint160).max
                    ? UnsafeMath.divRoundingUp(
                        Amt << FixedPoint96.RESOLUTION,
                        liquidity
                    )
                    : Math.RoundingUp(Amt, FixedPoint96.Q96, liquidity)
            );

            require(sqrtPX96 > Usage);
            // always fits 160 bits
            return uint160(sqrtPX96 - Usage);
        }
    }

    /// @notice Will take sqrt Price Input of token0 or token1 from suitable range
    /// @dev Throws if price or liquidity are 0, or if the next price is out of bounds
    /// @param sqrtPX96 Initial price of user before input amount(range/tick last price)
    /// @param liquidity The Amt of usable liquidity
    /// @param AmtIn How much of token0, or token1, is being swapped in
    /// @param token0or1 Whether the Amt in is token0 or token1
    /// @return sqrtQX96 The price after adding the input Amt to token0 or token1
    function getNextSqrtPriceFromInput(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 AmtIn,
        bool token0or1
    ) internal pure returns (uint160 sqrtQX96) {
        require(sqrtPX96 > 0);
        require(liquidity > 0);

        // round to make sure that we don't pass the target price
        return
            token0or1
                ? NextsqrtPriceForToken0Upwards(
                    sqrtPX96,
                    liquidity,
                    AmtIn,
                    true
                )
                : NextsqrtPriceForToken1Downwards(
                    sqrtPX96,
                    liquidity,
                    AmtIn,
                    true
                );
    }

    /// @notice Gets the next sqrt price given an output Amt of token0 or token1
    /// @dev Throws if price or liquidity are 0 or the next price is out of bounds
    /// @param sqrtPX96 Initial price of user before output amount(range/tick last price)
    /// @param liquidity The Amt of usable liquidity
    /// @param AmtOut How much of token0, or token1, is being swapped out
    /// @param token0or1 Whether the Amt out is token0 or token1
    /// @return sqrtQX96 The price after removing the output Amt of token0 or token1
    function getNextSqrtPriceFromOutput(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 AmtOut,
        bool token0or1
    ) internal pure returns (uint160 sqrtQX96) {
        require(sqrtPX96 > 0);
        require(liquidity > 0);

        // round to make sure that we pass the target price
        return
            token0or1
                ? NextsqrtPriceForToken1Downwards(
                    sqrtPX96,
                    liquidity,
                    AmtOut,
                    false
                )
                : NextsqrtPriceForToken0Upwards(
                    sqrtPX96,
                    liquidity,
                    AmtOut,
                    false
                );
    }

    /// @notice Gets the Amt0 delta between two prices
    /// @dev Calculates liquidity / sqrt(lower) - liquidity / sqrt(upper),
    /// i.e. liquidity * (sqrt(upper) - sqrt(lower)) / (sqrt(upper) * sqrt(lower))
    /// @param sqrtRatioAX96 A sqrt price
    /// @param sqrtRatioBX96 Another sqrt price
    /// @param liquidity The Amt of usable liquidity
    /// @param roundUp Whether to round the Amt up or down
    /// @return Amt0 Amt of token0 required to cover a position of size liquidity between the two passed prices
    function getAmt0Delta(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 Amt0) {
        if (sqrtRatioAX96 > sqrtRatioBX96)
            (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        uint256 numerator1 = uint256(liquidity) << FixedPoint96.RESOLUTION;
        uint256 numerator2 = sqrtRatioBX96 - sqrtRatioAX96;

        require(sqrtRatioAX96 > 0);

        return
            roundUp
                ? UnsafeMath.divRoundingUp(
                    Math.RoundingUp(numerator1, numerator2, sqrtRatioBX96),
                    sqrtRatioAX96
                )
                : Math.mulDiv(numerator1, numerator2, sqrtRatioBX96) /
                    sqrtRatioAX96;
    }

    /// @notice Gets the Amt1 delta between two prices
    /// @dev Calculates liquidity * (sqrt(upper) - sqrt(lower))
    /// @param sqrtRatioAX96 A sqrt price
    /// @param sqrtRatioBX96 Another sqrt price
    /// @param liquidity The Amt of usable liquidity
    /// @param roundUp Whether to round the Amt up, or down
    /// @return Amt1 Amt of token1 required to cover a position of size liquidity between the two passed prices
    function getAmt1Delta(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 Amt1) {
        if (sqrtRatioAX96 > sqrtRatioBX96)
            (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        return
            roundUp
                ? Math.RoundingUp(
                    liquidity,
                    sqrtRatioBX96 - sqrtRatioAX96,
                    FixedPoint96.Q96
                )
                : Math.mulDiv(
                    liquidity,
                    sqrtRatioBX96 - sqrtRatioAX96,
                    FixedPoint96.Q96
                );
    }

    /// @notice liquidity tick provider of respective token0 that gets signed token0 delta
    /// @param sqrtRatioAX96 A sqrt price
    /// @param sqrtRatioBX96 Another sqrt price
    /// @param liquidity The change in liquidity for which to compute the Amt0 delta
    /// @return Amt0 Amt of token0 corresponding to the passed liquidityDelta between the two prices
    function getAmt0Delta(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        int128 liquidity
    ) internal pure returns (int256 Amt0) {
        return
            liquidity < 0
                ? -getAmt0Delta(
                    sqrtRatioAX96,
                    sqrtRatioBX96,
                    uint128(-liquidity),
                    false
                ).toInt256()
                : getAmt0Delta(
                    sqrtRatioAX96,
                    sqrtRatioBX96,
                    uint128(liquidity),
                    true
                ).toInt256();
    }

    /// @notice liquidity tick provider of respective token1 that gets signed token1 delta
    /// @param sqrtRatioAX96 A sqrt price
    /// @param sqrtRatioBX96 Another sqrt price
    /// @param liquidity The change in liquidity for which to compute the Amt1 delta
    /// @return Amt1 Amt of token1 corresponding to the passed liquidityDelta between the two prices
    function getAmt1Delta(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        int128 liquidity
    ) internal pure returns (int256 Amt1) {
        return
            liquidity < 0
                ? -getAmt1Delta(
                    sqrtRatioAX96,
                    sqrtRatioBX96,
                    uint128(-liquidity),
                    false
                ).toInt256()
                : getAmt1Delta(
                    sqrtRatioAX96,
                    sqrtRatioBX96,
                    uint128(liquidity),
                    true
                ).toInt256();
    }
}
