// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./userContract.sol";

contract FactoryVault {
    address public immutable masterUserContract;
    address public immutable whiteListedTokensAddress;
    address public immutable adminAddress;
    mapping(address => address) public userToUserContractAddress;
    mapping(address => address) public userContractAddressToUser;

    constructor(address _masterUserContract,address _whiteListedTokensAddress) {
        masterUserContract = _masterUserContract;
        whiteListedTokensAddress = _whiteListedTokensAddress;
        adminAddress = msg.sender;
    }

    modifier onlyAdmin() {
        require(
            msg.sender == adminAddress,
            "Only the contract owner can perform this action."
        );
        _;
    }

    function clone(
        address _user
    ) external onlyAdmin returns (address _account) {
        _account = cloneContract();
        userToUserContractAddress[_user] = _account;
        userContractAddressToUser[_account] = _user;
        userContract(_account).initialize(_user, whiteListedTokensAddress);
    }

    function cloneContract() internal returns (address result) {
        bytes20 masterUserContractBytes = bytes20(masterUserContract);
        assembly {
            let clone := mload(0x40)
            mstore(
                clone,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(clone, 0x14), masterUserContractBytes)
            mstore(
                add(clone, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            result := create(0, clone, 0x37)
        }
    }

    function getmasterUserContract() external view returns (address) {
        return masterUserContract;
    }
    function getwhiteListedTokensAddress() external view returns (address) {
        return whiteListedTokensAddress;
    }
}
