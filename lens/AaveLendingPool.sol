// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

//import "../openzeppelin/Ownable.sol";
//import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "../openzeppelin/OwnableUpgradeable.sol";
import "../token/ERC20Interface.sol";
import "./IAaveLendingPool.sol";
import "./ILendingPool.sol";
import "./IWETHGateway.sol";

contract AaveLendingPool is OwnableUpgradeable{

    event NewAaveLendingPool(ILendingPool oldLendingPool, ILendingPool newLendingPool);

    event NewWETH(IWETHGateway oldWETH, IWETHGateway newWETH);

    ILendingPool public lendingPool;

    IWETHGateway public wETH;

    function initialize() public initializer {

        //将 msg.sender 设置为初始所有者。
        super.__Ownable_init();
    }

    //设置lendingPool地址
    function setAaveLendingPool(ILendingPool newLendingPool) public onlyOwner {
        ILendingPool oldLendingPool = lendingPool;
        lendingPool = newLendingPool;
        emit NewAaveLendingPool(oldLendingPool, newLendingPool);
    }

    // 设置WETH网关地址
    function setWETH(IWETHGateway newWETH) public onlyOwner {
        IWETHGateway oldWETH = wETH;
        wETH = newWETH;
        emit NewWETH(oldWETH, newWETH);
    }


    // 存
    // 入参：底层代币地址，存款数量 * 代币精度，账户地址，代码类型
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external override {
        lendingPool.deposit(asset, amount, onBehalfOf, referralCode);
    }

    // 取 DAI：0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063
    // 入参：底层代币地址，取款数量 * 精度，账户地址
    function withdraw(address asset, uint256 amount, address to) external override returns (uint256){
        uint256 err = lendingPool.withdraw(asset, amount, to);
        return err;
    }

    // 借
    // 底层代币地址，数量 * 精度，利率模型2，类型代码0，账户地址
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external override {
        lendingPool.borrow(asset, amount, interestRateMode, referralCode, onBehalfOf);
    }

    // 还
    // 底层代币地址，数量 * 精度，利率模型2，账户地址
    function repay(address asset, uint256 amount, uint256 rateMode, address onBehalfOf) external override returns (uint256){
        uint256 err = lendingPool.repay(asset, amount, rateMode, onBehalfOf);
        return err;
    }


    // 存
    // 入参：借贷池地址，账户地址，代码类型
    function depositETH(address onBehalfOf, uint16 referralCode) external payable override {
        wETH.depositETH(address(lendingPool), onBehalfOf, referralCode);
    }

    // 取
    // 入参：借贷池地址，取款数量 * 精度，账户地址
    function withdrawETH(uint256 amount, address onBehalfOf) external override{
        wETH.withdrawETH(lendingPool, amount, onBehalfOf);
    }

    // 借
    // 借贷池地址，数量 * 精度，利率模型2，类型代码0，账户地址
    function borrowETH(uint256 amount, uint256 interestRateMode, uint16 referralCode) external override {
        wETH.borrowETH(lendingPool, amount, interestRateMode, referralCode);
    }

    // 还
    // 借贷池地址，数量 * 精度，利率模型2，账户地址
    function repayETH(uint256 amount, uint256 rateMode, address onBehalfOf) external payable override{
        wETH.repayETH(lendingPool, amount, rateMode, onBehalfOf);
    }

    // 资产授权
    // 资产地址，授权地址，授权数量
    function approve(address token, address spender, uint256 amount) external returns (bool){
        bool success = IEIP20(token).approve(spender, amount);
        return success;
    }

}