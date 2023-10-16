// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

//import "../openzeppelin/Ownable.sol";
//import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "../openzeppelin/OwnableUpgradeable.sol";
import "../token/IPERC20.sol";
import "../token/PEther.sol";
import "../token/Maximillion.sol";
import "../libs/ErrorReporter.sol";
import "./PERC20TokenInterface.sol";
import "./IPEtherToken.sol";
import "../token/ERC20Interface.sol";

contract PERC20Token is OwnableUpgradeable, TokenErrorReporter{

    event NewUnderlyingToken(address newUnderlying, IPERC20 newPToken);
    event NewMaximillion(Maximillion oldMaximillion, Maximillion newMaximillion);
    event NewPEther(IPEtherToken oldPEther, IPEtherToken newPEther);

    mapping(address => IPERC20) public underlyingToken;

    Maximillion public maximillion;

    IPEtherToken public pEther;

    function initialize() public initializer {

        //将 msg.sender 设置为初始所有者。
        super.__Ownable_init();
    }


    //设置token地址
    function _setUnderlying(address newUnderlying, IPERC20 newPToken) public onlyOwner returns (uint) {
        underlyingToken[newUnderlying] = newPToken;
        emit NewUnderlyingToken(newUnderlying, newPToken);
        return uint(Error.NO_ERROR);
    }

    // 设置WETH地址
    function setPEther(IPEtherToken newPEther) public onlyOwner {
        IPEtherToken oldPEther = pEther;
        pEther = newPEther;
        emit NewPEther(oldPEther, newPEther);
    }

    // 设置WETH最大还款
    function setMaximillion(Maximillion newMaximillion) public onlyOwner {
        Maximillion oldMaximillion = maximillion;
        maximillion = newMaximillion;
        emit NewMaximillion(oldMaximillion, newMaximillion);
    }

    // 资产授权
    // 资产地址，授权地址，授权数量
    function approve(IEIP20 token, address spender, uint256 amount) external returns (bool){
        bool success = token.approve(spender, amount);
        return success;
    }

    // 通过底层代币 获取 资金池地址
    function getPToken(address underlying) public view returns (address) {
        address PToken = underlyingToken[underlying];
        return PToken;
    }

    // 存
    function mint(address token, uint mintAmount) external override returns (uint) {
        IPERC20 PToken = underlyingToken[token];
        uint err = PToken.mint(mintAmount);
        return err;
    }

    // 全部取
    function redeem(address token, uint redeemTokens) external override returns (uint) {
        IPERC20 PToken = underlyingToken[token];
        uint err = PToken.redeem(redeemTokens);
        return err;
    }

    // 部分取
    function redeemUnderlying(address token, uint redeemAmount) external override returns (uint) {
        IPERC20 PToken = underlyingToken[token];
        uint err = PToken.redeemUnderlying(redeemAmount);
        return err;
    }

    // 借
    function borrow(address token, uint borrowAmount) external override returns (uint) {
        IPERC20 PToken = underlyingToken[token];
        uint err = PToken.borrow(borrowAmount);
        return err;
    }

    // 还
    function repayBorrow(address token, uint repayAmount) external override returns (uint) {
        IPERC20 PToken = underlyingToken[token];
        uint err = PToken.repayBorrow(repayAmount);
        return err;
    }


    function repayBehalf(address borrower) public payable {
        repayBehalfExplicit(borrower, pEther);
    }
    // ETH 最大还款
    function repayBehalfExplicit(address borrower, PEther pEther_) external payable {
        Maximillion.repayBehalfExplicit(borrower, pEther_);
    }

    // 存 ETH
    function mintETH() external payable {
        pEther.mint();
    }

    // 还 ETH
    function repayBorrow() external payable{
        pEther.repayBorrow();
    }

    // 清算
    /*function liquidateBorrow(address borrower, address tokenLiquidate, uint repayAmount, address tokenCollateral) external override returns (uint) {
        IPERC20 PToken = underlyingToken[tokenLiquidate];
        IPToken collateral = underlyingToken[tokenCollateral];
        uint err = PToken.liquidateBorrow(borrower, repayAmount, collateral);
        return err;
    }*/
}