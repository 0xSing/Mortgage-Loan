pragma solidity ^0.6.0;
// SPDX-License-Identifier: MIT
// 配对合约ERC20
interface IPEtherToken {

    // 存
    function mint() external;
    // 还
    function repayBorrow() external;
    // 清算
    //function liquidationCall(address collateralAsset, address debtAsset, address user, uint256 debtToCover, bool receiveAToken) external;
}