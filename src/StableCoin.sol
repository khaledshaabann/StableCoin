//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

// This token is run by SCEngine, so only the owner can control it.
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*
* A Decentralized Stable Coin
* By: Khaled Ashraf
* Pegged to USD
* 1 Coin = $1
* Collateral: ETH and BTC
* Mining is Algorithmic
* 
* Is governed by SCEngine. This contract is just the ERC20 implementation of the coin itself.
*/


contract StableCoin is ERC20Burnable, Ownable{

    // Our custom errors
    error SC_MustBeMoreThanZero();
    error SC_InsufficientBalance();
    error SC_AddressNotEqualZero();

    // Our ERC20 constructor (Fix the ownable part later)
    constructor() ERC20("StableCoin", "SC") {}
    
    // Function used to Burn coins
    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0){
            revert SC_MustBeMoreThanZero(); // If the amount is less than or equal to zero we cannot burn.
        }
        if (balance < _amount){
            revert SC_InsufficientBalance(); // If the balance is less than the amount we want to burn, we cannot burn.
        }
        super.burn(_amount); // Here we actually burn the coins.
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool){
        if(_to == address(0)){
            revert SC_MustBeMoreThanZero(); // If the address is 0x0 we cannot mint.
        }

        if(_amount <= 0){
            revert SC_MustBeMoreThanZero(); // If the amount is less than or equal to zero we cannot mint.
        }
        _mint(_to, _amount); // Here we actually mint the coins.
        return true;
    }

}

