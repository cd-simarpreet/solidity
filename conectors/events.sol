//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Events {
    event LogDeposit(address indexed token, uint256 tokenAmt, uint256 getId, uint256 setId);
    event LogWithdraw(address indexed token, uint256 tokenAmt, uint256 getId, uint256 setId);
    event LogBorrow(address indexed token, uint256 tokenAmt, uint256 indexed rateMode, uint256 getId, uint256 setId);
    event LogPayback(address indexed token, uint256 tokenAmt, uint256 indexed rateMode, uint256 getId, uint256 setId);
    event LogEnableCollateral(address[] tokens);
    event LogSwapRateMode(address indexed token, uint256 rateMode);
    event LogPaybackOnBehalfOf(
		address token,
		uint256 amt,
		uint256 rateMode,
		address onBehalfOf,
		uint256 getId,
		uint256 setId
	);
}