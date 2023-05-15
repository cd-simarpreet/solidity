//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface ERC20Interface {
    function allowance(address, address) external view returns (uint);

    function balanceOf(address) external view returns (uint);

    function approve(address, uint) external;

    function transfer(address, uint) external returns (bool);

    function transferFrom(address, address, uint) external returns (bool);
}


contract vault {
    mapping(address=>mapping(address=>uint256)) userERC20Bal;
    
    function deposit(address token, uint256 amt)  public payable {
        ERC20Interface(token).transferFrom(
            msg.sender,
            address(this),
            amt
        );
        userERC20Bal[msg.sender][token] = amt;
    }

    function getBalance(address user, address token) public view returns(uint256){
        return userERC20Bal[user][token];
    }

    function increaseBalance(address user, address token, uint256 amt) public {
        userERC20Bal[user][token]+=amt;
    }

    function decreaseBalance(address user, address token, uint256 amt) public {
        userERC20Bal[user][token]-=amt;
    }

}