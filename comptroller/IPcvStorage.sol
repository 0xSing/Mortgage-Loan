// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface IPcvStorage {
    // 校验PCV是否存在
    function pcvIsExsit(address pcv) external view returns(bool);
}
