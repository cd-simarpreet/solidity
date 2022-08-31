// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/// @title Oracle
/// @notice Provide Liquidity and Price data of tokens
/// @dev Stored Oracle data . Every single Pool which will be initialized will contain the length of 1.New Array slots will
/// gets increase if anyone want to add liquidity to increase the array length to its max.But as the function new slots will
/// gets add when any slots gets filled or populated .Data will be revised once again when the oracle array gets filled or populated.
/// In the initial length will be 0.
library Oracle {
    struct Data {
        uint32 blockTimestamp; // Timestamp when the price feeds gets updated for every pool
        int56 tickAccumulate; // tick * time elapsed since the pool was first initialized
        uint160 secondsPerLiquidityX128; // seconds elapsed / max(1,liquidity) first initialized
        bool initialized; //whether or not initialized
    }

    /// @notice UpdateObservation will update the Data with the new Data.
    /// @dev blockTimestamp must be greater than or equal to lastUpdate.
    /// @param lastUpdate last data Timestamp which is to be update.
    /// @param blockTimestamp Timestamp of new observation.
    /// @param active_tick Active tick at the time of new observation.
    /// @param liquidity liquidity in that tick range in that new observation
    /// @return Data in memory which will be filled or populated
    function UpdateObservation(
        Data memory lastUpdate,
        uint32 blockTimestamp,
        int24 active_tick,
        uint128 liquidity
    ) private pure returns (Data memory) {
        uint32 delta = blockTimestamp - lastUpdate.blockTimestamp;
        return
            Data({
                blockTimestamp: blockTimestamp,
                tickAccumulate: lastUpdate.tickAccumulate +
                    int56(active_tick) *
                    delta,
                secondsPerLiquidityX128: lastUpdate.secondsPerLiquidityX128 +
                    ((uint160(delta) << 128) / (liquidity > 0 ? liquidity : 1)),
                initialized: true
            });
    }

    /// @notice Initializing the slot for the first pool array.
    /// @param pool stored array >> 65535 is the memory size upto which a device can hold if crosses 65535 then it will repopulate itself to the null Index.
    /// @param time of the Initialization of stored array
    /// @return grouping the numbers of array which are filled or populated
    /// @return groupingNext the new array index which will be independent or not fully populated yet with data
    function InitializingSlot(Data[65535] storage pool, uint32 time)
        internal
        returns (uint16 grouping, uint16 groupingNext)
    {
        pool[0] = Data({
            blockTimestamp: time,
            tickAccumulate: 0,
            secondsPerLiquidityX128: 0,
            initialized: true
        });
        return (1, 1);
    }

    /// @notice will store/write the Data to the array.
    /// @dev write after every block is been executed.Index represents the most recently written element.
    /// If the grouping is at its end , then nextgrouping must be greater then the current grouping,which means grouping will be increased.
    /// @param pool stored array
    /// @param index The index of the observation that was most recently written to the Data array
    /// @param blockTimestamp The timestamp of the new Data
    /// @param active_tick The active tick at the time of the new observation
    /// @param liquidity liquidity in that tick range in that new observation
    /// @param grouping number of filled /populated in pool array
    /// @param groupingNext new number which will be used to fill/populate , independent of population
    /// @return indexUpdated new Index of most recently written element in the pool array
    /// @return final_group new grouping in the pool array
    function write(
        Data[65535] storage pool,
        uint16 index,
        uint32 blockTimestamp,
        int24 active_tick,
        uint128 liquidity,
        uint16 grouping,
        uint16 groupingNext
    ) internal returns (uint16 indexUpdated, uint16 final_group) {
        Data memory lastUpdate = pool[index];

        // if Data is already up to date
        if (lastUpdate.blockTimestamp == blockTimestamp)
            return (index, grouping);
        // if above condition gets true
        if (groupingNext > grouping && index == (grouping - 1)) {
            final_group = groupingNext;
        } else {
            final_group = grouping;
        }
        indexUpdated = (index + 1) % groupingNext;
        pool[indexUpdated] = UpdateObservation(
            lastUpdate,
            blockTimestamp,
            active_tick,
            liquidity
        );
    }

    /// @notice to store the next Data in pool array
    /// @param pool stored array
    /// @param recent recent/current grouping in the pool storage
    /// @param next next proposed grouping in the pool storage
    /// @return next The next grouping which will be populated in the pool array
    function next_Observation(
        Data[65535] storage pool,
        uint16 recent,
        uint16 next
    ) internal returns (uint16) {
        require(recent > 0, "Not Initialized");
        if (next <= recent) return recent;
        for (uint16 i = recent; i < next; i++) pool[i].blockTimestamp = 1;
        return next;
    }

    /// @notice comparison between previous(x) and next(y) Timestamp
    /// @dev x and y must be recorded as per required.
    /// @param time A timestamp truncated to 32 bits
    /// @param x A comparison timestamp from which to determine the relative position of `time
    /// @param y From which to determine the relative position of `time`
    /// @return bool Whether x <= y
    function Adjust_Time(
        uint32 time,
        uint32 x,
        uint32 y
    ) private pure returns (bool) {
        // if there hasn't been overflow, no need to adjust
        if (x <= time && y <= time) return x <= y;
        uint256 x_adjust = x > time ? x : x + 2**32;
        uint256 y_adjust = y > time ? y : y + 2**32;

        return x_adjust <= y_adjust;
    }

    /// @notice Fetches the Data Btarget and Atarget a target, i.e. where [Btarget, Atarget] is satisfied.
    /// The result may be the same Data, or adjacent Data.
    /// @dev The answer must be contained in the array, used when the target is located within the stored Data
    /// boundaries: older than the most recent Data and younger, or the same age as, the oldest Data
    /// @param pool stored array
    /// @param current_block current Timestamp
    /// @param reserved_time The timestamp at which the reserved Data should be for
    /// @param index The index of the Data that was most recently written to the Data array
    /// @param grouping The number of populated elements in the oracle array
    /// @return Btarget The observation recorded before, or at, the target
    /// @return Atarget The observation recorded at, or after, the target

    function SearchArray(
        Data[65535] storage pool,
        uint32 current_block,
        uint32 reserved_time,
        uint16 index,
        uint16 grouping
    ) private view returns (Data memory Btarget, Data memory Atarget) {
        uint256 old = (index + 1) % grouping; // oldest Data
        uint256 latest = old + grouping - 1; // newest Data
        for (uint256 i; true; i = (old + latest) / 2) {
            Btarget = pool[i % grouping];
            // if uninitialized,keeping searching higher (more recently)
            if (!Btarget.initialized) {
                old = latest + 1;
                continue;
            }

            Atarget = pool[(i + 1) % grouping];

            bool at_Atarget_or_after = Adjust_Time(
                current_block,
                Btarget.blockTimestamp,
                reserved_time
            );
            // check if we've found the answer!
            if (
                at_Atarget_or_after &&
                Adjust_Time(
                    current_block,
                    reserved_time,
                    Atarget.blockTimestamp
                )
            ) break;

            if (!at_Atarget_or_after) latest = i - 1;
            else old = i + 1;
        }
    }

    /// @notice Fetches the Data Btarget and Atarget a given target, i.e. where [Btarget, Atarget] is satisfied
    /// @dev Assumes there is at least 1 initialized Data.
    /// Used by ObservePrevious() to compute the related blockTimestamp values as of a given block timestamp.
    /// @param pool stored array
    /// @param current_block current Timestamp
    /// @param reserved_time The timestamp at which the reserved Data should be for
    /// @param active_tick The active tick at the time of the returned or simulated Data
    /// @param index The index of the Data that was most recently written to the Data array
    /// @param liquidity The total pool liquidity at the time of the call
    /// @param grouping The number of populated elements in the pool array
    /// @return Btarget The Data which occurred at, or before, the given timestamp
    /// @return Atarget The Data which occurred at, or after, the given timestamp
    function getReliableObservation(
        Data[65535] storage pool,
        uint32 current_block,
        uint32 reserved_time,
        int24 active_tick,
        uint16 index,
        uint128 liquidity,
        uint16 grouping
    ) private view returns (Data memory Btarget, Data memory Atarget) {
        // optimistically set before to the newest Data
        Btarget = pool[index];
        // if the target is chronologically at or after the newest Data, we can early return
        if (Adjust_Time(current_block, Btarget.blockTimestamp, reserved_time)) {
            if (Btarget.blockTimestamp == reserved_time) {
                // if newest Data equals target, we're in the same block, so we can ignore Atarget
                return (Btarget, Atarget);
            } else {
                // otherwise, we need to UpdateObservation
                return (
                    Btarget,
                    UpdateObservation(
                        Btarget,
                        reserved_time,
                        active_tick,
                        liquidity
                    )
                );
            }
        }
        // now, set before to the oldest Data
        Btarget = pool[(index + 1) % grouping];
        if (!Btarget.initialized) Btarget = pool[0];
        // ensure that the target is chronologically at or after the oldest Data
        require(
            Adjust_Time(current_block, Btarget.blockTimestamp, reserved_time),
            "Before the recent observation"
        );
        // if we've reached this point, we have to search array
        return SearchArray(pool, current_block, reserved_time, index, grouping);
    }

    /// @notice Reverts if Data at or before the desired observation timestamp does not exist
    /// 0 may be passed as `secondsAgo' to return the current cumulative values.
    /// If called with a timestamp falling between two Data observations, returns the recorded values
    /// at exactly the timestamp between the two observed data.
    /// @param pool stored array
    /// @param current_block current block timestamp
    /// @param secondsAgo The amount of time to look back, in seconds, at which point to return an Data
    /// @param active_tick current tick
    /// @param index The index of the observation that was most recently written to the Data array
    /// @param liquidity  current in-range pool liquidity
    /// @param grouping The number of populated elements in the pool array
    /// @return ticksPerSeconds The tick * time elapsed since the pool was first initialized, as of `secondsAgo`
    /// @return LiquidityPerSeconds The time elapsed / max(1, liquidity) since the pool was first initialized, as of `secondsAgo`
    function ObservePrevious(
        Data[65535] storage pool,
        uint32 current_block,
        uint32 secondsAgo,
        int24 active_tick,
        uint16 index,
        uint128 liquidity,
        uint16 grouping
    )
        internal
        view
        returns (int56 ticksPerSeconds, uint160 LiquidityPerSeconds)
    {
        if (secondsAgo == 0) {
            Data memory lastUpdate = pool[index];
            if (lastUpdate.blockTimestamp != current_block)
                lastUpdate = UpdateObservation(
                    lastUpdate,
                    current_block,
                    active_tick,
                    liquidity
                );
            return (
                lastUpdate.tickAccumulate,
                lastUpdate.secondsPerLiquidityX128
            );
        }

        uint32 reserved_time = current_block - secondsAgo;

        (Data memory Btarget, Data memory Atarget) = getReliableObservation(
            pool,
            current_block,
            reserved_time,
            active_tick,
            index,
            liquidity,
            grouping
        );
        if (reserved_time == Btarget.blockTimestamp) {
            // we're at the left boundary
            return (Btarget.tickAccumulate, Btarget.secondsPerLiquidityX128);
        } else if (reserved_time == Atarget.blockTimestamp) {
            // we're at the right boundary
            return (Atarget.tickAccumulate, Atarget.secondsPerLiquidityX128);
        } else {
            // we're in the middle
            uint32 TimestampDelta = Atarget.blockTimestamp -
                Btarget.blockTimestamp;
            uint32 mainDelta = reserved_time - Btarget.blockTimestamp;
            return (
                Btarget.tickAccumulate +
                    ((Atarget.tickAccumulate - Btarget.tickAccumulate) /
                        TimestampDelta) *
                    mainDelta,
                Btarget.secondsPerLiquidityX128 +
                    uint160(
                        (uint256(
                            Atarget.secondsPerLiquidityX128 -
                                Btarget.secondsPerLiquidityX128
                        ) * mainDelta) / TimestampDelta
                    )
            );
        }
    }

    /// @notice Returns the accumulator values as of each time seconds ago from the given time in the array of `secondsAgos`
    /// @dev Reverts if `secondsAgos` > old Data
    /// @param pool The stored oracle array
    /// @param current_block The current block.timestamp
    /// @param new_seconds Each amount of time to look back, in seconds, at which point to return an Data
    /// @param active_tick The current tick
    /// @param index The index of the Data that was most recently written to the Datas array
    /// @param liquidity The current in-range pool liquidity
    /// @param grouping The number of populated elements in the oracle array
    /// @return ticksPerSeconds the return variables of a contract’s function state variable
    /// @return LiquidityPerSeconds the return variables of a contract’s function state variable
    function Conclusion(
        Data[65535] storage pool,
        uint32 current_block,
        uint32[] memory new_seconds,
        int24 active_tick,
        uint16 index,
        uint128 liquidity,
        uint16 grouping
    )
        internal
        view
        returns (
            int56[] memory ticksPerSeconds,
            uint160[] memory LiquidityPerSeconds
        )
    {
        require(grouping > 0, "Pool Hasn't Initialized");

        ticksPerSeconds = new int56[](new_seconds.length);
        LiquidityPerSeconds = new uint160[](new_seconds.length);
        for (uint256 x = 0; x < new_seconds.length; x++) {
            (ticksPerSeconds[x], LiquidityPerSeconds[x]) = ObservePrevious(
                pool,
                current_block,
                new_seconds[x],
                active_tick,
                index,
                liquidity,
                grouping
            );
        }
    }
}
