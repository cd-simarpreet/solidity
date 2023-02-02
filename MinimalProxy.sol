// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
import "./index.sol";

contract MinimalProxy {
    // add comments !!
    address CloneContract;
    address indexContract;
    function build(
        address _user
    ) external returns (address _account){
        _account = cloneContract();
        uint64 id = Index(indexContract).init(_account);
        Index(indexContract).addAccount(_user,id);
        // Index(indexContract).addUser(_user,id);
    }
  function cloneContract() internal returns (address result) {
    bytes20 CloneContractBytes = bytes20(CloneContract);
    assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), CloneContractBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            result := create(0, clone, 0x37)
        }
  }

  function setCloneContract(address _contract) external{
      CloneContract = _contract;
  }
  
  function setindexContract(address _indexContract) external{
      indexContract = _indexContract;
  }
}

