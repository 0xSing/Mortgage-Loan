// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface DeveloperLendPriceOracleInterface {

    function getPrice(address token) external view returns (uint);

    function setPrice(address token, uint price, bool force) external;

}