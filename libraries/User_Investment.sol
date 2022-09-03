// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import './Math.sol';
import './FixedPoint128.sol';
import './LiquidityMath.sol';

/// @title Investment
/// @notice Investments represent an owner address' liquidity between a lower and upper tick boundary
/// @dev Investments store additional state for tracking fees owed to the investment
library Investment {
    // desc stored for each user's position
    struct Desc {
        // the amount of liquidity owned by this position
        uint128 amountOfLiquidity;
        // fee growth per unit of liquidity as of the last update to liquidity or fees owed
        uint256 feeGrowthInside0LastX128PerUnit;
        uint256 feeGrowthInside1LastX128PerUnit;
        // the fees owed to the position owner in token0/token1
        uint128 tokensOwed0ToOwner;
        uint128 tokensOwed1ToOwner;
    }

    /// @notice Returns the Desc struct of a investment, given an owner and investment boundaries
    /// @param self The mapping containing all user investments
    /// @param owner The address of the investment owner
    /// @param tickLower The lower tick boundary of the investment
    /// @param tickUpper The upper tick boundary of the investment
    /// @return investment The investment desc struct of the given owners' investment
    function get(
        mapping(bytes32 => Desc) storage self,
        address owner,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (Investment.Desc storage investment) {
        investment = self[keccak256(abi.encodePacked(owner, tickLower, tickUpper))];
    }

    /// @notice Credits accumulated fees to a user's investment
    /// @param self The individual investment to update
    /// @param liquidityDelta The change in pool liquidity as a result of the investment update
    /// @param feeGrowthInside0X128 The all-time fee growth in token0, per unit of liquidity, inside the investment's tick boundaries
    /// @param feeGrowthInside1X128 The all-time fee growth in token1, per unit of liquidity, inside the investment's tick boundaries
    function update(
        Desc storage self,
        int128 liquidityDelta,
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128
    ) internal {
        Desc memory _self = self;

        uint128 liquidityNext;
        if (liquidityDelta == 0) {
            require(_self.amountOfLiquidity > 0, 'NP'); // disallow pokes for 0 liquidity investments
            liquidityNext = _self.amountOfLiquidity;
        } else {
            liquidityNext = LiquidityMath.addDeltaToLiquidity(_self.amountOfLiquidity, liquidityDelta);
        }

        // calculate accumulated fees
        uint128 tokensOwed0 =
            uint128(
                Math.mulDiv(
                    feeGrowthInside0X128 - _self.feeGrowthInside0LastX128PerUnit,
                    _self.amountOfLiquidity,
                    FixedPoint128.Q128
                )
            );
        uint128 tokensOwed1 =
            uint128(
                Math.mulDiv(
                    feeGrowthInside1X128 - _self.feeGrowthInside1LastX128PerUnit,
                    _self.amountOfLiquidity,
                    FixedPoint128.Q128
                )
            );

        // update the position
        if (liquidityDelta != 0) self.amountOfLiquidity = liquidityNext;
        self.feeGrowthInside0LastX128PerUnit = feeGrowthInside0X128;
        self.feeGrowthInside1LastX128PerUnit = feeGrowthInside1X128;
        if (tokensOwed0 > 0 || tokensOwed1 > 0) {
            // overflow is acceptable, have to withdraw before you hit type(uint128).max fees
            self.tokensOwed0ToOwner += tokensOwed0;
            self.tokensOwed1ToOwner += tokensOwed1;
        }
    }
}
