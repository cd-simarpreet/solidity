// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import './BitMath.sol';

/// @title Packed tick initialized state library
/// @notice Stores a packed mapping of tick index to its initialized state
/// @dev The mapping uses int16 for keys since ticks are represented as int24 and there are 256 (2^8) values per word.
library TickBitmap {

    /// @notice The ticks can be imagined as an infinte array fo bits where each bit will represent a tick. 
    /// If a tick has 1 bit, it means the tick is initialised adn when it has 0 bit it means the tick is uninitialised.
    /// The bit array is divided into sub-arrays of 256 bits called words This function calculates the position of a given
    /// tick by calculating the position of the word it lies in and then calculating its position within the word.
    /// @param tick The tick for which to compute the position
    /// @return wordPlace The key in the mapping containing the word in which the bit is stored
    /// @return bitPlace The bit position in the word where the flag is stored
    function place(int24 tick) private pure returns (int16 wordPlace, uint8 bitPlace) {
        wordPlace = int16(tick >> 8);
        bitPlace = uint8(tick % 256);
    }

    /// @notice This function is used to flip a tick from initialized to uninitialized or vice versa.
    /// @param self The mapping in which to flip the tick
    /// @param tick The tick to flip
    /// @param tickSpacing The spacing between usable ticks
    function reverseTheTick(
        mapping(int16 => uint256) storage self,
        int24 tick,
        int24 tickSpacing
    ) internal {
        require(tick % tickSpacing == 0); // ensure that the tick is spaced
        (int16 wordPlace, uint8 bitPlace) = place(tick / tickSpacing);
        uint256 mask = 1 << bitPlace;
        self[wordPlace] ^= mask;
    }

    /// @notice This function is used to find the next initialized tick which is present in the same word( or adjacent word) in either
    /// of the directions i.e left or right.The direction in which we search is decided by the lte parameter.If it is true , it means
    /// we are selling token0 and looking for next tick in the right and if it is false it means we are selling token1 and looking for 
    /// token1 and looking for tick in the left.
    /// @param self The mapping in which to compute the next initialized tick
    /// @param tick The starting tick
    /// @param tickSpacing The spacing between usable ticks
    /// @param lte Whether to search for the next initialized tick to the left (less than or equal to the starting tick)
    /// @return next The next initialized or uninitialized tick up to 256 ticks away from the current tick
    /// @return initialized Whether the next tick is initialized, as the function only searches within up to 256 ticks
    function nextInitializedTickWithinOneWord(
        mapping(int16 => uint256) storage self,
        int24 tick,
        int24 tickSpacing,
        bool lte
    ) internal view returns (int24 next, bool initialized) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--; // round towards negative infinity

        if (lte) {
            (int16 wordPlace, uint8 bitPlace) = place(compressed);
            // all the 1s at or to the right of the current bitPlace
            uint256 mask = (1 << bitPlace) - 1 + (1 << bitPlace);
            uint256 masked = self[wordPlace] & mask;

            // if there are no initialized ticks to the right of or at the current tick, return rightmost in the word
            initialized = masked != 0;
            // overflow/underflow is possible, but prevented externally by limiting both tickSpacing and tick
            next = initialized
                ? (compressed - int24(bitPlace - BitMath.mostSignificantBit(masked))) * tickSpacing
                : (compressed - int24(bitPlace)) * tickSpacing;
        } else {
            // start from the word of the next tick, since the current tick state doesn't matter
            (int16 wordPlace, uint8 bitPlace) = place(compressed + 1);
            // all the 1s at or to the left of the bitPlace
            uint256 mask = ~((1 << bitPlace) - 1);
            uint256 masked = self[wordPlace] & mask;

            // if there are no initialized ticks to the left of the current tick, return leftmost in the word
            initialized = masked != 0;
            // overflow/underflow is possible, but prevented externally by limiting both tickSpacing and tick
            next = initialized
                ? (compressed + 1 + int24(BitMath.leastSignificantBit(masked) - bitPlace)) * tickSpacing
                : (compressed + 1 + int24(type(uint8).max - bitPlace)) * tickSpacing;
        }
    }
}