// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ScoreToken is ERC20 {
    constructor() ERC20("Score Token", "SCORE") {
        uint256 totalSupply = 100000000 * (10 ** decimals());
        _mint(msg.sender, totalSupply);
    }
}
