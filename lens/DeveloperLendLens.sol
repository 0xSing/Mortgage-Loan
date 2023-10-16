// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../oracle/IPriceOracle.sol";
import "../token/ERC20Interface.sol";
//import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../openzeppelin/SafeMath.sol";
import "../libs/Exponential.sol";

interface ComptrollerLensInterface {
    function markets(address) external view returns (bool, uint);

    function oracle() external view returns (IPriceOracle);

    function getAccountLiquidity(address) external view returns (uint, uint, uint);

    function getAssetsIn(address) external view returns (PTokenLensInterface[] memory);
}

interface PTokenLensInterface {
    function exchangeRateStored() external view returns (uint256);

    function comptroller() external view returns (address);

    function supplyRatePerBlock() external view returns (uint256);

    function borrowRatePerBlock() external view returns (uint256);

    function reserveFactorMantissa() external view returns (uint256);

    function totalBorrows() external view returns (uint256);

    function totalReserves() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function getCash() external view returns (uint256);

    function underlying() external view returns (address);

    function decimals() external view returns (uint8);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function allowance(address owner, address spender) external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function getAccountSnapshot(address account) external virtual view returns (uint256, uint256, uint256, uint256);
    // 获取最新数据
    function accrueInterestSnapshot() public view returns (uint[] memory);
}

interface DeveloperDpDistributionLensInterface {
    function pendingDpAccrued(address holder, bool borrowers, bool suppliers) external view returns (uint256);
}


interface DeveloperDpBreederLensInterface {
    function pendingDeveloperDp(uint256 _pid, address _user) external view returns (uint256);
}

contract DeveloperLendLens is Exponential{

    event NewUnderlyingToken(address newUnderlying, address newPToken);

    mapping(address => address) public underlyingToken;

    using SafeMath for uint256;

    address public owner;

    struct PTokenMetadata {
        address pToken;
        uint exchangeRateCurrent;
        uint supplyRatePerBlock;
        uint borrowRatePerBlock;
        uint reserveFactorMantissa;
        uint totalBorrows;
        uint totalReserves;
        uint totalSupply;
        uint totalCash;
        bool isListed;
        uint collateralFactorMantissa;
        address underlyingAssetAddress;
        uint pTokenDecimals;
        uint underlyingDecimals;
    }

    constructor() public {
        owner = msg.sender;
    }

    // 设置代币地址映射资金池
    function _setUnderlying(address newUnderlying, address newPToken) public {
        require(msg.sender == owner, "sender is not owner");
        underlyingToken[newUnderlying] = newPToken;
        emit NewUnderlyingToken(newUnderlying, newPToken);
    }

    // 获取pToken
    function getUnderlyingByPToken(address underlying) public view returns (address pToken){
       pToken = underlyingToken[underlying];
    }

    // 获取最新区块资产汇率
    function currentExchangeRateStored(address pToken) public view returns (uint) {
        uint[] memory res = new uint[](6);
        res = PTokenLensInterface(pToken).accrueInterestSnapshot();
        uint totalSupply = PTokenLensInterface(pToken).totalSupply();

        // 0 最新区块，1 资产余额，2 存款利息积累，3 总借款，4 总准备金，5 借款指数
        //uint currentBlockNumber = res[0];
        uint cashPrior = res[1];
        //uint interestAccumulated = res[2];
        uint totalBorrowsNew = res[3];
        uint totalReservesNew = res[4];
        //uint borrowIndexNew = res[5];

        // exchangeRate = (totalCash + totalBorrows - totalReserves) / totalSupply
        uint cashPlusBorrowsMinusReserves;
        Exp memory exchangeRate;
        MathError mathErr;

        (mathErr, cashPlusBorrowsMinusReserves) = addThenSubUInt(cashPrior, totalBorrowsNew, totalReservesNew);
        if (mathErr != MathError.NO_ERROR) {
            return 0;
        }

        (mathErr, exchangeRate) = getExp(cashPlusBorrowsMinusReserves, totalSupply);
        if (mathErr != MathError.NO_ERROR) {
            return 0;
        }

        return exchangeRate.mantissa;
    }


    function pTokenMetadata(PTokenLensInterface pToken) public view returns (PTokenMetadata memory){

        uint exchangeRateCurrent = pToken.exchangeRateStored();
        ComptrollerLensInterface comptroller = ComptrollerLensInterface(pToken.comptroller());
        (bool isListed, uint collateralFactorMantissa) = comptroller.markets(address(pToken));

        address underlyingAssetAddress;
        uint underlyingDecimals;

        if (compareStrings(pToken.symbol(), "pMATIC")) {
            underlyingAssetAddress = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
            underlyingDecimals = 18;
        } else {
            PTokenLensInterface pErc20 = PTokenLensInterface(address(pToken));
            underlyingAssetAddress = pErc20.underlying();
            underlyingDecimals = IEIP20(pErc20.underlying()).decimals();
        }

        return PTokenMetadata({
        pToken : address(pToken),
        exchangeRateCurrent : exchangeRateCurrent,
        supplyRatePerBlock : pToken.supplyRatePerBlock(),
        borrowRatePerBlock : pToken.borrowRatePerBlock(),
        reserveFactorMantissa : pToken.reserveFactorMantissa(),
        totalBorrows : pToken.totalBorrows(),
        totalReserves : pToken.totalReserves(),
        totalSupply : pToken.totalSupply(),
        totalCash : pToken.getCash(),
        isListed : isListed,
        collateralFactorMantissa : collateralFactorMantissa,
        underlyingAssetAddress : underlyingAssetAddress,
        pTokenDecimals : pToken.decimals(),
        underlyingDecimals : underlyingDecimals
        });
    }

    function pTokenMetadataAll(PTokenLensInterface[] calldata pTokens) public view returns (PTokenMetadata[] memory) {
        uint pTokenCount = pTokens.length;
        PTokenMetadata[] memory res = new PTokenMetadata[](pTokenCount);
        for (uint i = 0; i < pTokenCount; i++) {
            res[i] = pTokenMetadata(pTokens[i]);
        }
        return res;
    }

    struct PTokenBalances {
        address pToken;
        uint balance;
        uint borrowBalance; //用户的借款
        uint exchangeRateMantissa;
    }

    function pTokenBalances(PTokenLensInterface pToken, address payable account) public view returns (PTokenBalances memory) {

        (,uint tokenBalance,uint borrowBalance,uint exchangeRateMantissa) = pToken.getAccountSnapshot(account);

        return PTokenBalances({
        pToken : address(pToken),
        balance : tokenBalance,
        borrowBalance : borrowBalance,
        exchangeRateMantissa : exchangeRateMantissa
        });

    }

    function pTokenBalancesAll(PTokenLensInterface[] calldata pTokens, address payable account) public view returns (PTokenBalances[] memory) {
        uint pTokenCount = pTokens.length;
        PTokenBalances[] memory res = new PTokenBalances[](pTokenCount);
        for (uint i = 0; i < pTokenCount; i++) {
            res[i] = pTokenBalances(pTokens[i], account);
        }
        return res;
    }

    struct AccountLimits {
        PTokenLensInterface[] markets;
        uint liquidity;
        uint shortfall;
    }


    function getAccountLimits(ComptrollerLensInterface comptroller, address account) public view returns (AccountLimits memory) {
        (uint errorCode, uint liquidity, uint shortfall) = comptroller.getAccountLiquidity(account);
        require(errorCode == 0);

        return AccountLimits({
        markets : comptroller.getAssetsIn(account),
        liquidity : liquidity,
        shortfall : shortfall
        });
    }


    function pendingDpAccrued(DeveloperDpDistributionLensInterface developerDpDistribution, address account, bool borrowers, bool suppliers) public view returns (uint256){
        return developerDpDistribution.pendingDpAccrued(account, borrowers, suppliers);
    }

    function pendingDeveloperLend(DeveloperDpBreederLensInterface developerDpBreeder, address _user, uint256 _pid) public view returns (uint256){
        return developerDpBreeder.pendingDeveloperDp(_pid, _user);
    }

    function pendingDeveloperLendAll(DeveloperDpBreederLensInterface developerDpBreeder, address _user, uint256[] calldata _pids) public view returns (uint256[] memory){
        uint count = _pids.length;
        uint256[] memory res = new uint256[](count);
        for (uint i = 0; i < count; i++) {
            res[i] = pendingDeveloperLend(developerDpBreeder, _user, _pids[i]);
        }
        return res;
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }
}
