pragma solidity ^0.6.0;
// SPDX-License-Identifier: MIT
// 配对合约ERC20
interface ILendingPool {

    // 存
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    // 取
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    // 借
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;
    // 还
    function repay(address asset, uint256 amount, uint256 rateMode, address onBehalfOf) external returns (uint256);
    // 清算
    //function liquidationCall(address collateralAsset, address debtAsset, address user, uint256 debtToCover, bool receiveAToken) external;

}