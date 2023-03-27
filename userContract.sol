//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";


interface ERC20Interface {
    function allowance(address, address) external view returns (uint);
    function balanceOf(address) external view returns (uint);
    function approve(address, uint) external;
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
}

contract userContract is Initializable{
    address public userOwner;
    uint256 public ORDER_ID =1;
    mapping(uint256 => mapping(string=>int256)) public withdrawAmt;
    mapping(uint256 =>mapping(string=>bool)) public isWithdraw;
    mapping(uint256=>mapping(string=>int256)) public depositAmt;
    mapping(uint256 => bool) public isCanceled;
    mapping(uint256 =>address) public orderIdTokenAddress;
    mapping(uint256 =>bool) public isOrderExecuted;
    // mapping(uint256 =>int256) public orderAmt; // order Amount jaise bhi soch sakta hain



    
    function initialize(address _userOwner) external initializer {
        userOwner = _userOwner;
    }
    mapping(address => string) public tokenName;
    modifier onlyOwner() {
    require(msg.sender == userOwner, "Only the contract user owner can perform this action.");
    _;
    }
    function addOrder(address erc20, int256 amt) external onlyOwner{
        require(amt > 0, "Deposit amount must be greater than zero.");

        string memory tokenString = tokenName[erc20];
        ERC20Interface(erc20).transferFrom(msg.sender,address(this),uint256(amt));
        depositAmt[ORDER_ID][tokenString]=amt;
        orderIdTokenAddress[ORDER_ID] = erc20;
        ORDER_ID++;
    }
    function cancelOrder(uint256 orderId) external onlyOwner {
        require(isOrderExecuted[orderId] == false, "Withdraw amount must be greater than zero.");
        address erc20 = orderIdTokenAddress[orderId];
        string memory tokenString = tokenName[erc20];
        isCanceled[orderId]=true;
        int256 amt = depositAmt[orderId][tokenString];
        depositAmt[orderId][tokenString]=0;
        ERC20Interface(erc20).transfer(msg.sender,uint256(amt));       
    }
    
    function executeOrder(address dexAddrs,uint256 orderId, address buyToken) external {
        // check dexAddrs is valid dex!
        require(!isCanceled[orderId],"order is cancelled");
        address erc20 = orderIdTokenAddress[orderId];
        string memory tokenString = tokenName[erc20];
        int256 amt = depositAmt[orderId][tokenString];
        require(amt>0,"amt is zero");      
        //external call to some contract on decentralised exchange and executing order! 
        // swap()
        int256 amtRecieve = 0;
        string memory buyTokenStr = tokenName[buyToken];
        withdrawAmt[orderId][buyTokenStr] = amtRecieve;
        isWithdraw[orderId][buyTokenStr] = true;
    }

    function withdraw(uint256 orderId) external onlyOwner{
        require(!isCanceled[orderId],"order is cancelled");
        address erc20 = orderIdTokenAddress[orderId];
        string memory tokenString = tokenName[erc20];
        int256 amt = withdrawAmt[orderId][tokenString];
        bool _true = isWithdraw[orderId][tokenString];
        require(_true,"not a valid orderId for withdraw");
        isWithdraw[orderId][tokenString]=false;
        withdrawAmt[orderId][tokenString] =0;
        ERC20Interface(erc20).transfer(msg.sender,uint256(amt));     
    }
    function addpair(address erc20, string memory str) external {
        tokenName[erc20] = str;
    }

}
