pragma solidity ^0.8.24;

import '../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';
import '../../lib/openzeppelin-contracts/contracts/access/Ownable.sol';

contract KKToken is ERC20, Ownable {
    constructor() ERC20("KK Token", "KK") Ownable(msg.sender) {
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }
}