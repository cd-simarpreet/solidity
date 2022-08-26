// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.4.0;

/// @title Provide user investment update
/// @notice Will update the user investment By providing the range limits where user have invested there liquidity.

import "../libraries/Math.sol";
import "@uniswap/contracts/libraries/FixedPoint128.sol";
import "@uniswap/contracts/libraries/LiquidityMath.sol";

library UserInvestment {
    // Description of the user liquidity
    struct Desc {
        // user liquidity amount
        uint128 User_Liquidity;
        // Will update the user fee from last update
        // Highest Order 128 Bit
        uint256 feeUpdationInside0lastx128;
        uint256 feeUpdationInside1lastx128;
        // amount owed by the user token0/token1 during Investment
        uint128 token0;
        uint128 token1;
    }

    /// @notice Returns the record of the User
    /// @param User mapping of the user in bytes32 from Desc
    /// @param owner Address of the Investor
    /// @param lowerrange lower range of the liquidity amount
    /// @param upperrange upper range of the liquidity amount
    /// @return investment Will give the description of the user investment
    function getRecord(
        mapping(bytes32 => Desc) storage User,
        address owner,
        int24 lowerrange,
        int24 upperrange
    ) internal view returns (UserInvestment.Desc storage investment) {
        investment = User[
            keccak256(abi.encodePacked(owner, lowerrange, upperrange))
        ];
    }

    /// @notice Will update the user Range/Investments
    /// @param User Will update the user investment
    /// @param feeUpdateInside0firstx128 Inside Growth of fee in token0(feeUpdateInside0firstx128 = global - outside)
    /// @param feeUpdateInside1firstx128 Inside Growth of fee in token1(feeUpdateInside1firstx128 = global - outside)
    /// @param Total_liquidation User Liquidity Delta
    function updateRecord(
        Desc storage User,
        uint256 feeUpdateInside0firstx128,
        uint256 feeUpdateInside1firstx128,
        int128 Total_liquidation
    ) internal {
        Desc memory _user = User; //_user not stored in blockchain

        uint128 liquidity_update;

        if (Total_liquidation == 0) {
            require(_user.User_Liquidity > 0, "No Problem"); // No Poke For 0 Liquidity
            liquidity_update = _user.User_Liquidity;
        } else {
            liquidity_update = LiquidityMath.addDelta(
                _user.User_Liquidity,
                Total_liquidation
            );
        }

        // Update/calculate the token0/token1 fees
        uint128 token0 = uint128(
            Math.mulDiv(
                feeUpdateInside0firstx128 - _user.feeUpdationInside0lastx128, // will give us the amount remaing amount of the user fees
                _user.User_Liquidity, // amount of liquidity which the user invested
                FixedPoint128.Q128 // Q128 -  Notation unsigned integer type . Q128 - 2**128
            )
        );
        uint128 token1 = uint128(
            Math.mulDiv(
                feeUpdateInside1firstx128 - _user.feeUpdationInside1lastx128,
                _user.User_Liquidity,
                FixedPoint128.Q128
            )
        );

        // Update User Final Investment
        if (Total_liquidation != 0) User.User_Liquidity = liquidity_update;
        User.feeUpdationInside0lastx128 = feeUpdateInside0firstx128;
        User.feeUpdationInside1lastx128 = feeUpdateInside1firstx128;
        if (token0 > 0 || token1 > 0) {
            // overflow is acceptable, have to withdraw before you hit type(uint128).max fees
            User.token0 += token0;
            User.token1 += token1;
        }
    }
}
