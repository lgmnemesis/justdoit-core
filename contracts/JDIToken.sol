// SPDX-License-Identifier: MIT
pragma solidity >=0.7 <0.9.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract JDIToken is ERC20 {
    
    address public admin;
    address public miner;

    constructor() ERC20('JDI Token', 'DJI') {
        admin = msg.sender;
    }

    function setMiner(address _miner) external {
        require(msg.sender == admin);
        miner = _miner;
    }

    function mint(address account, uint amount) public {
        require(msg.sender == miner, 'Only Miner');
        _mint(account, amount);
    }

    function burn(address account, uint amount) external {
        require(msg.sender == miner, 'Only Miner');
        _burn(account, amount);
    }
}