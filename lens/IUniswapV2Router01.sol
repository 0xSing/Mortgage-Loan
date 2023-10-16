// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface IUniswapV2Router01 {

    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    // ERC20 添加流动性
    // tokenA，tokenB，A数量，B数量，A * 0.005，B * 0.005，账户地址，最后期限
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

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
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

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
    ) external returns (uint amountA, uint amountB);

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
    ) external returns (uint amountToken, uint amountETH);

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
    ) external returns (uint amountA, uint amountB);

    // DP 赎回流动性
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);

    // ERC20兑换路由地址 0xa5e0829caced8ffdd4de3c43696c57f7d7a678ff
    // 兑换金额，获得金额，资产交易对地址数组，账户地址，最后期限 3289541710
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    // DP主网兑换路由地址 0xf2ed4ee7f281a7b0c57755c5c330fe13d77fd018
    // WMATIC: 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270
    // NUSD: 0x8E9f2Fcea1D8BCd8a24146Ec5eab821B6cF75214
    // 兑换数量，资产数组，账户地址，最后期限
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);

    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
    external
    returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    returns (uint[] memory amounts);

    // 主网兑换路由地址 0xa5e0829caced8ffdd4de3c43696c57f7d7a678ff
    // WMATIC: 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270
    // QUICK: 0x831753DD7087CaC61aB5644b308642cc1c33Dc13
    // USDT: 0xc2132D05D31c914a87C6611C10748AEb04B58e8F
    // 兑换数量，资产数组，账户地址，最后期限
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}