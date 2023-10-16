pragma solidity ^0.6.0;
// SPDX-License-Identifier: MIT
// 配对合约ERC20
interface PERC20TokenInterface {

    // 存
    function mint(address token, uint256 mintAmount) external returns (uint256);
    // 取
    function redeem(address token, uint256 redeemTokens) external returns (uint256);
    // 取
    function redeemUnderlying(address token, uint256 redeemAmount) external returns (uint256);
    // 借
    function borrow(address token, uint256 borrowAmount) external returns (uint256);
    // 还
    function repayBorrow(address token, uint256 repayAmount) external returns (uint256);
    // 清算资产,借款人，清算资产地址，清算数量，获取奖励地址
    //function LiquidateBorrow(address borrower, address tokenLiquidate, uint256 repayAmount, address tokenCollateral) external returns (uint256);
}