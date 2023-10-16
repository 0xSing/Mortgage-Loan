// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

//import "../openzeppelin/Ownable.sol";
//import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "../openzeppelin/OwnableUpgradeable.sol";
import "../token/ERC20Interface.sol";
import "./IUniswapV2Router01.sol";

contract QuickSwap is OwnableUpgradeable{

    event NewSwapRouter(IUniswapV2Router01 oldSwapRouter, IUniswapV2Router01 newSwapRouter);

    IUniswapV2Router01 public swapRouter;

    function initialize() public initializer {

        //将 msg.sender 设置为初始所有者。
        super.__Ownable_init();
    }

    //设置SWAP路由地址
    function setSwapRouter(IUniswapV2Router01 newSwapRouter) public onlyOwner {
        IUniswapV2Router01 oldSwapRouter = swapRouter;
        swapRouter = newSwapRouter;
        emit NewSwapRouter(oldSwapRouter, newSwapRouter);
    }

    // 资产授权
    // 资产地址，授权地址，授权数量
    function approve(address token, address spender, uint256 amount) external returns (bool){
        bool success = IEIP20(token).approve(spender, amount);
        return success;
    }

    // 读取 LP 数量
    function balanceOf(IEIP20 token, address owner) external view returns (uint256 balance){
        balance = token.balanceOf(owner);
    }


    // ERC20 添加流动性
    // tokenA，tokenB，A数量，B数量，A * 滑点，B * 滑点，账户地址，最后期限
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity){
        (amountA, amountB, liquidity) = swapRouter.addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, to, deadline);
    }


    // ERC20 赎回流动性
    // 赎回授权，调用配对地址 0x59153f27eefe07e5ece4f9304ebba1da6f53ca88 授权地址 0xa5e0829caced8ffdd4de3c43696c57f7d7a678ff
    // A地址，B地址，LP数量 * 精度，数量A，数量B，账户地址，最后期限
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB) {
        (amountA, amountB) = swapRouter.removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }

    // ERC20兑换路由地址 0xa5e0829caced8ffdd4de3c43696c57f7d7a678ff
    // 兑换金额，获得金额，资产交易对地址数组，账户地址，最后期限 3289541710
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        amounts = swapRouter.swapExactTokensForTokens(amountIn, amountOutMin, path, to, deadline);
    }


    // 先授权ERC20资产，授权地址 0xa5e0829caced8ffdd4de3c43696c57f7d7a678ff
    // 主网添加流动性 路由地址 0xa5e0829caced8ffdd4de3c43696c57f7d7a678ff
    // ERC20地址，ERC20数量 * 精度，ERC20token数量 * 0.005，ETH数量 * 0.005，账户地址，最后期限
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity){
        (amountToken, amountETH, liquidity) = swapRouter.addLiquidityETH(token, amountTokenDesired, amountTokenMin, amountETHMin, to, deadline);
    }

    // 赎回授权，调用配对地址 0x604229c960e5cacf2aaeac8be68ac07ba9df81c3 授权地址 0xa5e0829caced8ffdd4de3c43696c57f7d7a678ff
    // 主网赎回流动性 路由地址 0xa5e0829caced8ffdd4de3c43696c57f7d7a678ff
    // ERC20地址，LP数量 * 精度，ERC20token数量，ETH数量，账户地址，最后期限
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH) {
        (amountToken, amountETH) = swapRouter.removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    // 主网兑换路由地址 0xa5e0829caced8ffdd4de3c43696c57f7d7a678ff
    // WMATIC: 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270
    // QUICK: 0x831753DD7087CaC61aB5644b308642cc1c33Dc13
    // USDT: 0xc2132D05D31c914a87C6611C10748AEb04B58e8F
    // 兑换数量，资产数组，账户地址，最后期限
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts){
        amounts = swapRouter.swapETHForExactTokens(amountOut, path, to, deadline);
    }



    // DP主网兑换路由地址 0xf2ed4ee7f281a7b0c57755c5c330fe13d77fd018
    // WMATIC: 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270
    // NUSD: 0x8E9f2Fcea1D8BCd8a24146Ec5eab821B6cF75214
    // 兑换数量 * 滑点，资产数组，账户地址，最后期限
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts){
        amounts = swapRouter.swapExactETHForTokens(amountOutMin, path, to, deadline);
    }

    // DP 赎回流动性
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH) {
        (amountToken, amountETH) = swapRouter.removeLiquidityETHWithPermit(token, liquidity, amountTokenMin, amountETHMin, to, deadline,
            approveMax, v, r, s);
    }

    // ERC20 赎回流动性
    // DP兑换路由地址 0xf2ed4ee7f281a7b0c57755c5c330fe13d77fd018
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB) {
        (amountA, amountB) = swapRouter.removeLiquidityWithPermit(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline,
            approveMax, v, r, s);
    }
}