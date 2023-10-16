// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

//import "../openzeppelin/Ownable.sol";
//import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "../openzeppelin/Ownable.sol";
import "../libs/Exponential.sol";

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint);

    function balanceOf(address owner) external view returns (uint);

    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);

    function transfer(address to, uint value) external returns (bool);

    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function price0CumulativeLast() external view returns (uint);

    function price1CumulativeLast() external view returns (uint);

    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);

    function burn(address to) external returns (uint amount0, uint amount1);

    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;

    function skim(address to) external;

    function sync() external;

    function initialize(address, address) external;
}

interface AggregatorV3Interface {

    function decimals()
    external
    view
    returns (
        uint8
    );

    function description()
    external
    view
    returns (
        string memory
    );

    function version()
    external
    view
    returns (
        uint256
    );

    // getRoundData and latestRoundData should both raise "No data present"
    // if they do not have data to report, instead of returning unset values
    // which could be misinterpreted as actual reported values.
    function getRoundData(
        uint80 _roundId
    )
    external
    view
    returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );

    function latestRoundData()
    external
    view
    returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );

}

// 新版LP预言机，兼容DP-SWAP
contract NewUniSwapPriceOracle is OwnableUpgradeSafe, Exponential {

    event ConfigUpdated(address token, string symbol, address source0, address source1, uint256 baseUnit, bool available);
    event TokenPriceConfig(address underlying, string symbol, address source, uint256 baseUnit);
    event TokenConfigUpdated(address underlying, string symbol, address pair, address source, uint256 baseUnit, bool available);


    function initialize() public initializer {

        //将 msg.sender 设置为初始所有者。
        super.__Ownable_init();
    }

    uint internal constant scale = 1e18;
    // LP列表
    mapping(address => LpConfig) public lpConfigs;
    // token列表
    mapping(address => TokenConfig) public tokenConfigs;
    // Token 价格配置列表
    mapping(address => PriceConfig) public priceConfigs;

    //Config for pToken
    struct LpConfig {
        address token;
        string symbol;
        address source0;
        address source1;
        uint256 baseUnit;
        bool available;
    }

    struct TokenConfig {
        address underlying;
        string symbol;
        address pair;
        address source;
        uint256 baseUnit; //example: 1e18
        bool available;
    }

    struct PriceConfig {
        address underlying;
        string symbol;
        address source;
        uint256 baseUnit; //example: 1e18
    }

    struct LpPrice {
        uint reserve0;
        uint reserve1;
        uint8 tokenDecimals0;
        uint8 tokenDecimals1;
        uint baseUnit1;
        uint baseUnit0;
        int price0;
        int price1;
        uint totalAmount;
        uint256 totalSupply;
    }

    // 查询LP-Token总份额
    function swapTotalSupply(address pair) external view returns (uint amount) {
        amount = IUniswapV2Pair(pair).totalSupply();
    }

    // 查询账户拥有的LP数量
    function swapBalanceOf(address pair, address owner) external view returns (uint amount) {
        amount = IUniswapV2Pair(pair).balanceOf(owner);
    }

    // 查看LP双资产数量
    function swapGetReserves(address pair) external view returns (uint112 reserve0, uint112 reserve1) {
        (reserve0, reserve1,) = IUniswapV2Pair(pair).getReserves();
    }

    // 计算LP价格
    function getSwapLpPrice(address pair) external view returns (uint){
        LpConfig storage lpConfig = lpConfigs[pair];
        require(lpConfig.available == true, "token stop using");
        LpPrice memory lp;
        (lp.reserve0, lp.reserve1,) = IUniswapV2Pair(pair).getReserves();
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();

        if (lpConfig.source0 != address(0)) {
            AggregatorV3Interface priceFeed0 = AggregatorV3Interface(lpConfig.source0);
            (, lp.price0,,,) = priceFeed0.latestRoundData();
        }
        if (lpConfig.source1 != address(0)) {
            AggregatorV3Interface priceFeed1 = AggregatorV3Interface(lpConfig.source1);
            (, lp.price1,,,) = priceFeed1.latestRoundData();
        }

        // 精度转换成18位
        lp.tokenDecimals0 = IUniswapV2Pair(token0).decimals();
        lp.baseUnit0 = sub_(uint8(18), lp.tokenDecimals0);
        if (lp.baseUnit0 > 0) {
            lp.reserve0 = mul_(lp.reserve0, 1*10**lp.baseUnit0);
        }

        lp.tokenDecimals1 = IUniswapV2Pair(token1).decimals();
        lp.baseUnit1 = sub_(uint8(18), lp.tokenDecimals1);
        if (lp.baseUnit1 > 0) {
            lp.reserve1 = mul_(lp.reserve1, 1*10**lp.baseUnit1);
        }

        uint amount0 = 0;
        uint amount1 = 0;
        if (lp.price0 > 0) {
            //lp.reserve0 = mul_(lp.reserve0, lpConfig.baseUnit0);
            amount0 = mul_(lp.reserve0, mul_(uint(lp.price0), 1e10));
        } else {
            uint priceA = div_(mul_(lp.reserve1, scale), lp.reserve0);
            amount0 = mul_(lp.reserve0, priceA);
        }
        if (lp.price1 > 0) {
            //lp.reserve1 = mul_(lp.reserve1, lpConfig.baseUnit1);
            amount1 = mul_(lp.reserve1, mul_(uint(lp.price1), 1e10));
        } else {
            uint priceB = div_(mul_(lp.reserve0, scale), lp.reserve1);
            amount1 = mul_(lp.reserve1, priceB);
        }
        // tokenA总金额 + tokenB总金额
        lp.totalAmount = add_(amount0, amount1);
        //lp.totalAmount = div_(lp.totalAmount, 1e18);
        lp.totalSupply = IUniswapV2Pair(pair).totalSupply();
        // LP价格 = 总净资产 / 总份额
        uint price = div_(lp.totalAmount, lp.totalSupply);
        if (price <= 0) {
            return 0;
            //return (0,0,0,0,0,0,0,0);
        } else {//return: (price / 1e8) * (1e36 / baseUnit) ==> price * 1e28 / baseUnit
            //return (lp.price0, lp.price1, amount0, amount1, lp.totalAmount, lp.totalSupply, price, div_(mul_(price, 1e28), lpConfig.priceBaseUnit));
            return div_(mul_(price, 1e18), lpConfig.baseUnit);
        }
    }

    // 计算SWAP中代币价格
    function getSwapTokenPrice(address underlying) external view returns (uint){
        TokenConfig storage tokenConfig = tokenConfigs[underlying];
        require(tokenConfig.available == true, "token stop using");

        LpPrice memory lp;
        IUniswapV2Pair swapPair = IUniswapV2Pair(tokenConfig.pair);
        (lp.reserve0, lp.reserve1,) = swapPair.getReserves();
        address token0 = swapPair.token0();
        address token1 = swapPair.token1();

        lp.tokenDecimals0 = IUniswapV2Pair(token0).decimals();
        lp.baseUnit0 = sub_(uint8(18), lp.tokenDecimals0);
        if (lp.baseUnit0 > 0) {
            lp.reserve0 = mul_(lp.reserve0, 1*10**lp.baseUnit0);
        }

        lp.tokenDecimals1 = IUniswapV2Pair(token1).decimals();
        lp.baseUnit1 = sub_(uint8(18), lp.tokenDecimals1);
        if (lp.baseUnit1 > 0) {
            lp.reserve1 = mul_(lp.reserve1, 1*10**lp.baseUnit1);
        }

        int pr;
        uint price;
        if (token0 == underlying) {
            if (tokenConfig.source != address(0)){
                AggregatorV3Interface priceFeed0 = AggregatorV3Interface(tokenConfig.source);
                (, pr,,,) = priceFeed0.latestRoundData();
                price = uint(pr);
            }

            if (price <= 0) {
                price = div_(mul_(lp.reserve1, scale), lp.reserve0);
            }
        }

        if (token1 == underlying) {
            if (tokenConfig.source != address(0)) {
                AggregatorV3Interface priceFeed1 = AggregatorV3Interface(tokenConfig.source);
                (, pr,,,) = priceFeed1.latestRoundData();
                price = uint(pr);
            }

            if (price <= 0) {
                price = div_(mul_(lp.reserve0, scale), lp.reserve1);
            }
        }

        if (price <= 0) {
            return 0;
        } else {//return: (price / 1e8) * (1e36 / baseUnit) ==> price * 1e28 / baseUnit
            return div_(mul_(price, 1e28), tokenConfig.baseUnit);
        }
    }

    // 配置Lp
    function addLpConfig(address lpToken, string memory symbol, address source0, address source1, uint256 baseUnit) public onlyOwner {
        // add TokenConfig
        LpConfig storage lpConfig = lpConfigs[lpToken];
        require(lpConfig.token != lpToken, "The lpToken already exists");
        lpConfig.token = lpToken;
        lpConfig.symbol = symbol;
        lpConfig.source0 = source0;
        lpConfig.source1 = source1;
        lpConfig.baseUnit = baseUnit;
        lpConfig.available = true;

        emit ConfigUpdated(lpToken, symbol, source0, source1, baseUnit, lpConfig.available);
    }

    // 更新LP配置
    function updateLpConfig(address lpToken, address source0, address source1, uint256 baseUnit, bool available) public onlyOwner {
        // add TokenConfig
        LpConfig storage lpConfig = lpConfigs[lpToken];
        require(lpConfig.token == lpToken, "lpToken does not exist");
        lpConfig.token = lpToken;
        lpConfig.source0 = source0;
        lpConfig.source1 = source1;
        lpConfig.baseUnit = baseUnit;
        lpConfig.available = available;

        emit ConfigUpdated(lpToken, lpConfig.symbol, source0, source1, baseUnit, available);
    }

    // 配置token
    function addTokenConfig(address underlying, string memory symbol, address pair, address source, uint256 baseUnit) public onlyOwner {
        // source,价格来源没有时，填写零地址
        // add TokenConfig
        TokenConfig storage tokenConfig = tokenConfigs[underlying];
        require(tokenConfig.underlying != underlying, "The Underlying already exists");
        tokenConfig.underlying = underlying;
        tokenConfig.symbol = symbol;
        tokenConfig.pair = pair;
        tokenConfig.source = source;
        tokenConfig.baseUnit = baseUnit;
        tokenConfig.available = true;

        emit TokenConfigUpdated(underlying, symbol, pair, source, baseUnit, tokenConfig.available);
    }

    // 更新token
    function updateTokenConfig(address underlying, address pair, address source, uint256 baseUnit, bool available) public onlyOwner {
        // source,价格来源没有时，填写零地址
        TokenConfig storage tokenConfig = tokenConfigs[underlying];
        require(tokenConfig.underlying == underlying, "underlying does not exist");
        tokenConfig.pair = pair;
        tokenConfig.source = source;
        tokenConfig.baseUnit = baseUnit;
        tokenConfig.available = available;

        emit TokenConfigUpdated(underlying, tokenConfig.symbol, pair, source, baseUnit, available);
    }

    // 配置Token价格
    function addTokenPriceConfig(address underlying, string memory symbol, address source, uint256 baseUnit) public onlyOwner {
        // add TokenPriceConfig
        PriceConfig storage config = priceConfigs[underlying];
        require(config.underlying != underlying, "The Underlying already exists");
        config.underlying = underlying;
        config.symbol = symbol;
        config.source = source;
        config.baseUnit = baseUnit;
        emit TokenPriceConfig(underlying, symbol, source, baseUnit);
    }

    // 修改Token价格配置
    function updateTokenPriceConfig(address underlying, address source, uint256 baseUnit) public onlyOwner {
        PriceConfig storage config = priceConfigs[underlying];
        require(config.underlying == underlying, "underlying does not exist");
        config.underlying = underlying;
        config.source = source;
        config.baseUnit = baseUnit;
        emit TokenPriceConfig(underlying, config.symbol, source, baseUnit);
    }

    // 获取Token价格,目前使用在FARMS结算合约中，查询奖励代币价格
    function getTokenPrice(address underlying) external view returns (uint){
        PriceConfig memory config = priceConfigs[underlying];

        AggregatorV3Interface priceFeed0 = AggregatorV3Interface(config.source);
        (, int pr,,,) = priceFeed0.latestRoundData();
        uint price = uint(pr);

        if (price <= 0) {
            return 0;
        } else {//return: (price / 1e8) * (1e36 / baseUnit) ==> price * 1e28 / baseUnit
            return div_(mul_(price, 1e28), config.baseUnit);
        }
    }

}