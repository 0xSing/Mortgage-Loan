// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import {Exponential} from "../openzeppelin/Exponential.sol";
import {PToken} from "../token/PToken.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {OwnableUpgradeable} from "../openzeppelin/OwnableUpgradeable.sol";
import {ComptrollerStorage} from "../comptroller/ComptrollerStorage.sol";
import {Comptroller} from "../comptroller/Comptroller.sol";


interface IDeveloperDpDistribution {

    function distributeMintDp(address pToken, address minter, bool distributeAll) external;

    function distributeRedeemDp(address pToken, address redeemer, bool distributeAll) external;

    function distributeBorrowDp(address pToken, address borrower, bool distributeAll) external;

    function distributeRepayBorrowDp(address pToken, address borrower, bool distributeAll) external;

    function distributeSeizeDp(address pTokenCollateral, address borrower, address liquidator, bool distributeAll) external;

    function distributeTransferDp(address pToken, address src, address dst, bool distributeAll) external;

}

interface IDeveloperDpBreeder {
    function stake(uint256 _pid, uint256 _amount) external;

    function unStake(uint256 _pid, uint256 _amount) external;

    function claim(uint256 _pid) external;

    function emergencyWithdraw(uint256 _pid) external;
}

contract DeveloperDpDistribution is IDeveloperDpDistribution, Exponential, OwnableUpgradeable {

    IERC20 public dp;

    IDeveloperDpBreeder public dpBreeder;

    Comptroller public comptroller;

    //DP-MODIFY: Copy and modify from ComptrollerV3Storage

    struct DpMarketState {
        uint224 index;
        uint32 block;
    }

    /// @notice The portion of compRate that each market currently receives
    mapping(address => uint) public dpSpeeds;

    /// @notice The Dp market supply state for each market
    mapping(address => DpMarketState) public dpSupplyState;

    /// @notice The Dp market borrow state for each market
    mapping(address => DpMarketState) public dpBorrowState;

    /// @notice The Dp borrow index for each market for each supplier as of the last time they accrued Dp
    mapping(address => mapping(address => uint)) public dpSupplierIndex;

    /// @notice The Dp borrow index for each market for each borrower as of the last time they accrued Dp
    mapping(address => mapping(address => uint)) public dpBorrowerIndex;

    /// @notice The Dp accrued but not yet transferred to each user
    mapping(address => uint) public dpAccrued;

    /// @notice The threshold above which the flywheel transfers Dp, in wei
    uint public constant dpClaimThreshold = 0.001e18;

    /// @notice The initial Dp index for a market
    uint224 public constant dpInitialIndex = 1e36;

    bool public enableDpClaim;
    bool public enableDistributeMintDp;
    bool public enableDistributeRedeemDp;
    bool public enableDistributeBorrowDp;
    bool public enableDistributeRepayBorrowDp;
    bool public enableDistributeSeizeDp;
    bool public enableDistributeTransferDp;


    /// @notice Emitted when a new Dp speed is calculated for a market
    event DpSpeedUpdated(PToken indexed pToken, uint newSpeed);

    /// @notice Emitted when Dp is distributed to a supplier
    event DistributedSupplierDp(PToken indexed pToken, address indexed supplier, uint dpDelta, uint dpSupplyIndex);

    /// @notice Emitted when Dp is distributed to a borrower
    event DistributedBorrowerDp(PToken indexed pToken, address indexed borrower, uint dpDelta, uint dpBorrowIndex);

    event StakeTokenToDpBreeder(IERC20 token, uint pid, uint amount);

    event ClaimDpFromDpBreeder(uint pid);

    event EnableState(string action, bool state);

    function initialize(IERC20 _dp, IDeveloperDpBreeder _dpBreeder, Comptroller _comptroller) public initializer {

        dp = _dp;
        dpBreeder = _dpBreeder;
        comptroller = _comptroller;

        enableDpClaim = false;
        enableDistributeMintDp = false;
        enableDistributeRedeemDp = false;
        enableDistributeBorrowDp = false;
        enableDistributeRepayBorrowDp = false;
        enableDistributeSeizeDp = false;
        enableDistributeTransferDp = false;

        super.__Ownable_init();
    }

    function distributeMintDp(address pToken, address minter, bool distributeAll) public override(IDeveloperDpDistribution) {
        require(msg.sender == address(comptroller) || msg.sender == owner(), "only comptroller or owner");
        if (enableDistributeMintDp) {
            updateDpSupplyIndex(pToken);
            distributeSupplierDp(pToken, minter, distributeAll);
        }
    }

    function distributeRedeemDp(address pToken, address redeemer, bool distributeAll) public override(IDeveloperDpDistribution) {
        require(msg.sender == address(comptroller) || msg.sender == owner(), "only comptroller or owner");
        if (enableDistributeRedeemDp) {
            updateDpSupplyIndex(pToken);
            distributeSupplierDp(pToken, redeemer, distributeAll);
        }
    }

    function distributeBorrowDp(address pToken, address borrower, bool distributeAll) public override(IDeveloperDpDistribution) {

        require(msg.sender == address(comptroller) || msg.sender == owner(), "only comptroller or owner");

        if (enableDistributeBorrowDp) {
            Exp memory borrowIndex = Exp({mantissa : PToken(pToken).borrowIndex()});
            updateDpBorrowIndex(pToken, borrowIndex);
            distributeBorrowerDp(pToken, borrower, borrowIndex, distributeAll);
        }


    }

    function distributeRepayBorrowDp(address pToken, address borrower, bool distributeAll) public override(IDeveloperDpDistribution) {

        require(msg.sender == address(comptroller) || msg.sender == owner(), "only comptroller or owner");

        if (enableDistributeRepayBorrowDp) {
            Exp memory borrowIndex = Exp({mantissa : PToken(pToken).borrowIndex()});
            updateDpBorrowIndex(pToken, borrowIndex);
            distributeBorrowerDp(pToken, borrower, borrowIndex, distributeAll);
        }

    }

    function distributeSeizeDp(address pTokenCollateral, address borrower, address liquidator, bool distributeAll) public override(IDeveloperDpDistribution) {

        require(msg.sender == address(comptroller) || msg.sender == owner(), "only comptroller or owner");

        if (enableDistributeSeizeDp) {
            updateDpSupplyIndex(pTokenCollateral);
            distributeSupplierDp(pTokenCollateral, borrower, distributeAll);
            distributeSupplierDp(pTokenCollateral, liquidator, distributeAll);
        }

    }

    function distributeTransferDp(address pToken, address src, address dst, bool distributeAll) public override(IDeveloperDpDistribution) {

        require(msg.sender == address(comptroller) || msg.sender == owner(), "only comptroller or owner");

        if (enableDistributeTransferDp) {
            updateDpSupplyIndex(pToken);
            distributeSupplierDp(pToken, src, distributeAll);
            distributeSupplierDp(pToken, dst, distributeAll);
        }

    }

    function _stakeTokenToDpBreeder(IERC20 token, uint pid) public onlyOwner {
        uint amount = token.balanceOf(address(this));
        token.approve(address(dpBreeder), amount);
        dpBreeder.stake(pid, amount);
        emit StakeTokenToDpBreeder(token, pid, amount);
    }

    function _claimDpFromDpBreeder(uint pid) public onlyOwner {
        dpBreeder.claim(pid);
        emit ClaimDpFromDpBreeder(pid);
    }

    function setDpSpeedInternal(PToken pToken, uint dpSpeed) internal {
        uint currentDpSpeed = dpSpeeds[address(pToken)];
        if (currentDpSpeed != 0) {
            // note that Dp speed could be set to 0 to halt liquidity rewards for a market
            Exp memory borrowIndex = Exp({mantissa : pToken.borrowIndex()});
            updateDpSupplyIndex(address(pToken));
            updateDpBorrowIndex(address(pToken), borrowIndex);
        } else if (dpSpeed != 0) {

            require(comptroller.isMarketListed(address(pToken)), "dp market is not listed");

            if (comptroller.isMarketMinted(address(pToken)) == false) {
                comptroller._setMarketMinted(address(pToken), true);
            }

            if (dpSupplyState[address(pToken)].index == 0 && dpSupplyState[address(pToken)].block == 0) {
                dpSupplyState[address(pToken)] = DpMarketState({
                index : dpInitialIndex,
                block : safe32(block.number, "block number exceeds 32 bits")
                });
            }

            if (dpBorrowState[address(pToken)].index == 0 && dpBorrowState[address(pToken)].block == 0) {
                dpBorrowState[address(pToken)] = DpMarketState({
                index : dpInitialIndex,
                block : safe32(block.number, "block number exceeds 32 bits")
                });
            }

        }

        if (currentDpSpeed != dpSpeed) {
            dpSpeeds[address(pToken)] = dpSpeed;
            emit DpSpeedUpdated(pToken, dpSpeed);
        }

    }

    /**
     * @notice Accrue Dp to the market by updating the supply index
     * @param pToken The market whose supply index to update
     */
    function updateDpSupplyIndex(address pToken) internal {
        DpMarketState storage supplyState = dpSupplyState[pToken];
        uint supplySpeed = dpSpeeds[pToken];
        uint blockNumber = block.number;
        uint deltaBlocks = sub_(blockNumber, uint(supplyState.block));
        if (deltaBlocks > 0 && supplySpeed > 0) {
            uint supplyTokens = PToken(pToken).totalSupply();
            uint dpAccrued = mul_(deltaBlocks, supplySpeed);
            Double memory ratio = supplyTokens > 0 ? fraction(dpAccrued, supplyTokens) : Double({mantissa : 0});
            Double memory index = add_(Double({mantissa : supplyState.index}), ratio);
            dpSupplyState[pToken] = DpMarketState({
            index : safe224(index.mantissa, "new index exceeds 224 bits"),
            block : safe32(blockNumber, "block number exceeds 32 bits")
            });
        } else if (deltaBlocks > 0) {
            supplyState.block = safe32(blockNumber, "block number exceeds 32 bits");
        }
    }

    /**
     * @notice Accrue Dp to the market by updating the borrow index
     * @param pToken The market whose borrow index to update
     */
    function updateDpBorrowIndex(address pToken, Exp memory marketBorrowIndex) internal {
        DpMarketState storage borrowState = dpBorrowState[pToken];
        uint borrowSpeed = dpSpeeds[pToken];
        uint blockNumber = block.number;
        uint deltaBlocks = sub_(blockNumber, uint(borrowState.block));
        if (deltaBlocks > 0 && borrowSpeed > 0) {
            uint borrowAmount = div_(PToken(pToken).totalBorrows(), marketBorrowIndex);
            uint dpAccrued = mul_(deltaBlocks, borrowSpeed);
            Double memory ratio = borrowAmount > 0 ? fraction(dpAccrued, borrowAmount) : Double({mantissa : 0});
            Double memory index = add_(Double({mantissa : borrowState.index}), ratio);
            dpBorrowState[pToken] = DpMarketState({
            index : safe224(index.mantissa, "new index exceeds 224 bits"),
            block : safe32(blockNumber, "block number exceeds 32 bits")
            });
        } else if (deltaBlocks > 0) {
            borrowState.block = safe32(blockNumber, "block number exceeds 32 bits");
        }
    }

    /**
     * @notice Calculate Dp accrued by a supplier and possibly transfer it to them
     * @param pToken The market in which the supplier is interacting
     * @param supplier The address of the supplier to distribute Dp to
     */
    function distributeSupplierDp(address pToken, address supplier, bool distributeAll) internal {
        DpMarketState storage supplyState = dpSupplyState[pToken];
        Double memory supplyIndex = Double({mantissa : supplyState.index});
        Double memory supplierIndex = Double({mantissa : dpSupplierIndex[pToken][supplier]});
        dpSupplierIndex[pToken][supplier] = supplyIndex.mantissa;

        if (supplierIndex.mantissa == 0 && supplyIndex.mantissa > 0) {
            supplierIndex.mantissa = dpInitialIndex;
        }

        Double memory deltaIndex = sub_(supplyIndex, supplierIndex);
        uint supplierTokens = PToken(pToken).balanceOf(supplier);
        uint supplierDelta = mul_(supplierTokens, deltaIndex);
        uint supplierAccrued = add_(dpAccrued[supplier], supplierDelta);
        dpAccrued[supplier] = grantDpInternal(supplier, supplierAccrued, distributeAll ? 0 : dpClaimThreshold);
        emit DistributedSupplierDp(PToken(pToken), supplier, supplierDelta, supplyIndex.mantissa);
    }


    /**
     * @notice Calculate Dp accrued by a borrower and possibly transfer it to them
     * @dev Borrowers will not begin to accrue until after the first interaction with the protocol.
     * @param pToken The market in which the borrower is interacting
     * @param borrower The address of the borrower to distribute Dp to
     */
    function distributeBorrowerDp(address pToken, address borrower, Exp memory marketBorrowIndex, bool distributeAll) internal {
        DpMarketState storage borrowState = dpBorrowState[pToken];
        Double memory borrowIndex = Double({mantissa : borrowState.index});
        Double memory borrowerIndex = Double({mantissa : dpBorrowerIndex[pToken][borrower]});
        dpBorrowerIndex[pToken][borrower] = borrowIndex.mantissa;

        if (borrowerIndex.mantissa > 0) {
            Double memory deltaIndex = sub_(borrowIndex, borrowerIndex);
            uint borrowerAmount = div_(PToken(pToken).borrowBalanceStored(borrower), marketBorrowIndex);
            uint borrowerDelta = mul_(borrowerAmount, deltaIndex);
            uint borrowerAccrued = add_(dpAccrued[borrower], borrowerDelta);
            dpAccrued[borrower] = grantDpInternal(borrower, borrowerAccrued, distributeAll ? 0 : dpClaimThreshold);
            emit DistributedBorrowerDp(PToken(pToken), borrower, borrowerDelta, borrowIndex.mantissa);
        }
    }


    /**
     * @notice Transfer Dp to the user, if they are above the threshold
     * @dev Note: If there is not enough Dp, we do not perform the transfer all.
     * @param user The address of the user to transfer Dp to
     * @param userAccrued The amount of Dp to (possibly) transfer
     * @return The amount of Dp which was NOT transferred to the user
     */
    function grantDpInternal(address user, uint userAccrued, uint threshold) internal returns (uint) {

        if (userAccrued >= threshold && userAccrued > 0) {
            uint dpRemaining = dp.balanceOf(address(this));
            if (userAccrued <= dpRemaining) {
                dp.transfer(user, userAccrued);
                return 0;
            }
        }
        return userAccrued;
    }

    /**
     * @notice Claim all the Dp accrued by holder in all markets
     * @param holder The address to claim Dp for
     */
    function claimDp(address holder) public {
        claimDp(holder, comptroller.getAllMarkets());
    }

    /**
     * @notice Claim all the comp accrued by holder in the specified markets
     * @param holder The address to claim Dp for
     * @param pTokens The list of markets to claim Dp in
     */
    function claimDp(address holder, PToken[] memory pTokens) public {
        address[] memory holders = new address[](1);
        holders[0] = holder;
        claimDp(holders, pTokens, true, false);
    }

    /**
     * @notice Claim all dp accrued by the holders
     * @param holders The addresses to claim Dp for
     * @param pTokens The list of markets to claim Dp in
     * @param borrowers Whether or not to claim Dp earned by borrowing
     * @param suppliers Whether or not to claim Dp earned by supplying
     */
    function claimDp(address[] memory holders, PToken[] memory pTokens, bool borrowers, bool suppliers) public {
        require(enableDpClaim, "Claim is not enabled");

        for (uint i = 0; i < pTokens.length; i++) {
            PToken pToken = pTokens[i];
            require(comptroller.isMarketListed(address(pToken)), "market must be listed");
            if (borrowers == true) {
                Exp memory borrowIndex = Exp({mantissa : pToken.borrowIndex()});
                updateDpBorrowIndex(address(pToken), borrowIndex);
                for (uint j = 0; j < holders.length; j++) {
                    distributeBorrowerDp(address(pToken), holders[j], borrowIndex, true);
                }
            }
            if (suppliers == true) {
                updateDpSupplyIndex(address(pToken));
                for (uint j = 0; j < holders.length; j++) {
                    distributeSupplierDp(address(pToken), holders[j], true);
                }
            }
        }

    }

    /*** Dp Distribution Admin ***/

    function _setDpSpeed(PToken pToken, uint dpSpeed) public onlyOwner {
        setDpSpeedInternal(pToken, dpSpeed);
    }

    function _setEnableDpClaim(bool state) public onlyOwner {
        enableDpClaim = state;
        emit EnableState("enableDpClaim", state);
    }

    function _setEnableDistributeMintDp(bool state) public onlyOwner {
        enableDistributeMintDp = state;
        emit EnableState("enableDistributeMintDp", state);
    }

    function _setEnableDistributeRedeemDp(bool state) public onlyOwner {
        enableDistributeRedeemDp = state;
        emit EnableState("enableDistributeRedeemDp", state);
    }

    function _setEnableDistributeBorrowDp(bool state) public onlyOwner {
        enableDistributeBorrowDp = state;
        emit EnableState("enableDistributeBorrowDp", state);
    }

    function _setEnableDistributeRepayBorrowDp(bool state) public onlyOwner {
        enableDistributeRepayBorrowDp = state;
        emit EnableState("enableDistributeRepayBorrowDp", state);
    }

    function _setEnableDistributeSeizeDp(bool state) public onlyOwner {
        enableDistributeSeizeDp = state;
        emit EnableState("enableDistributeSeizeDp", state);
    }

    function _setEnableDistributeTransferDp(bool state) public onlyOwner {
        enableDistributeTransferDp = state;
        emit EnableState("enableDistributeTransferDp", state);
    }

    function _setEnableAll(bool state) public onlyOwner {
        _setEnableDistributeMintDp(state);
        _setEnableDistributeRedeemDp(state);
        _setEnableDistributeBorrowDp(state);
        _setEnableDistributeRepayBorrowDp(state);
        _setEnableDistributeSeizeDp(state);
        _setEnableDistributeTransferDp(state);
        _setEnableDpClaim(state);
    }

    function _transferDp(address to, uint amount) public onlyOwner {
        _transferToken(address(dp), to, amount);
    }

    function _transferToken(address token, address to, uint amount) public onlyOwner {
        IERC20 erc20 = IERC20(token);

        uint balance = erc20.balanceOf(address(this));
        if (balance < amount) {
            amount = balance;
        }

        erc20.transfer(to, amount);
    }

    function pendingDpAccrued(address holder, bool borrowers, bool suppliers) public view returns (uint256){
        return pendingDpInternal(holder, borrowers, suppliers);
    }

    function pendingDpInternal(address holder, bool borrowers, bool suppliers) internal view returns (uint256){

        uint256 pendingDp = dpAccrued[holder];

        PToken[] memory pTokens = comptroller.getAllMarkets();
        for (uint i = 0; i < pTokens.length; i++) {
            address pToken = address(pTokens[i]);
            uint tmp = 0;
            if (borrowers == true) {
                tmp = pendingDpBorrowInternal(holder, pToken);
                pendingDp = add_(pendingDp, tmp);
            }
            if (suppliers == true) {
                tmp = pendingDpSupplyInternal(holder, pToken);
                pendingDp = add_(pendingDp, tmp);
            }
        }

        return pendingDp;
    }

    function pendingDpBorrowInternal(address borrower, address pToken) internal view returns (uint256){
        if (enableDistributeBorrowDp && enableDistributeRepayBorrowDp) {
            Exp memory marketBorrowIndex = Exp({mantissa : PToken(pToken).borrowIndex()});
            DpMarketState memory borrowState = pendingDpBorrowIndex(pToken, marketBorrowIndex);

            Double memory borrowIndex = Double({mantissa : borrowState.index});
            Double memory borrowerIndex = Double({mantissa : dpBorrowerIndex[pToken][borrower]});
            if (borrowerIndex.mantissa > 0) {
                Double memory deltaIndex = sub_(borrowIndex, borrowerIndex);
                uint borrowerAmount = div_(PToken(pToken).borrowBalanceStored(borrower), marketBorrowIndex);
                uint borrowerDelta = mul_(borrowerAmount, deltaIndex);
                return borrowerDelta;
            }
        }
        return 0;
    }

    function pendingDpBorrowIndex(address pToken, Exp memory marketBorrowIndex) internal view returns (DpMarketState memory){
        DpMarketState memory borrowState = dpBorrowState[pToken];
        uint borrowSpeed = dpSpeeds[pToken];
        uint blockNumber = block.number;
        uint deltaBlocks = sub_(blockNumber, uint(borrowState.block));
        if (deltaBlocks > 0 && borrowSpeed > 0) {
            uint borrowAmount = div_(PToken(pToken).totalBorrows(), marketBorrowIndex);
            uint dpAccrued = mul_(deltaBlocks, borrowSpeed);
            Double memory ratio = borrowAmount > 0 ? fraction(dpAccrued, borrowAmount) : Double({mantissa : 0});
            Double memory index = add_(Double({mantissa : borrowState.index}), ratio);
            borrowState = DpMarketState({
            index : safe224(index.mantissa, "new index exceeds 224 bits"),
            block : safe32(blockNumber, "block number exceeds 32 bits")
            });
        } else if (deltaBlocks > 0) {
            borrowState = DpMarketState({
            index : borrowState.index,
            block : safe32(blockNumber, "block number exceeds 32 bits")
            });
        }
        return borrowState;
    }

    function pendingDpSupplyInternal(address supplier, address pToken) internal view returns (uint256){
        if (enableDistributeMintDp && enableDistributeRedeemDp) {
            DpMarketState memory supplyState = pendingDpSupplyIndex(pToken);
            Double memory supplyIndex = Double({mantissa : supplyState.index});
            Double memory supplierIndex = Double({mantissa : dpSupplierIndex[pToken][supplier]});
            if (supplierIndex.mantissa == 0 && supplyIndex.mantissa > 0) {
                supplierIndex.mantissa = dpInitialIndex;
            }
            Double memory deltaIndex = sub_(supplyIndex, supplierIndex);
            uint supplierTokens = PToken(pToken).balanceOf(supplier);
            uint supplierDelta = mul_(supplierTokens, deltaIndex);
            return supplierDelta;
        }
        return 0;
    }

    function pendingDpSupplyIndex(address pToken) internal view returns (DpMarketState memory){
        DpMarketState memory supplyState = dpSupplyState[pToken];
        uint supplySpeed = dpSpeeds[pToken];
        uint blockNumber = block.number;
        uint deltaBlocks = sub_(blockNumber, uint(supplyState.block));

        if (deltaBlocks > 0 && supplySpeed > 0) {
            uint supplyTokens = PToken(pToken).totalSupply();
            uint dpAccrued = mul_(deltaBlocks, supplySpeed);
            Double memory ratio = supplyTokens > 0 ? fraction(dpAccrued, supplyTokens) : Double({mantissa : 0});
            Double memory index = add_(Double({mantissa : supplyState.index}), ratio);
            supplyState = DpMarketState({
            index : safe224(index.mantissa, "new index exceeds 224 bits"),
            block : safe32(blockNumber, "block number exceeds 32 bits")
            });
        } else if (deltaBlocks > 0) {
            supplyState = DpMarketState({
            index : supplyState.index,
            block : safe32(blockNumber, "block number exceeds 32 bits")
            });
        }
        return supplyState;
    }

}