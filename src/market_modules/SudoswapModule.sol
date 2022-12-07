// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {
    ERC20,
    ILSSVMRouter,
    ILSSVMPair,
    PairSwapAny,
    PairSwapSpecific,
    RobustPairSwapAny,
    RobustPairSwapSpecific
} from "../interfaces/ILSSVMRouter.sol";

import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";

contract SudoswapModule {

    /*///////////////////////////////////////////////////////////////
                              INITIALIZATION
    //////////////////////////////////////////////////////////////*/ 

    using SafeTransferLib for ERC20;

    address public immutable sudoswap;

    constructor(address _sudoswap) {
        sudoswap = _sudoswap;
    }

    /*///////////////////////////////////////////////////////////////
                                  ERRORS
    //////////////////////////////////////////////////////////////*/ 

    /// @notice invalid sudoswap order
    error Sudoswap_InvalidOrder();

    error Sudoswap_PurchaseFailed();

    /*///////////////////////////////////////////////////////////////
                            ORDER FULFILLMENT
    //////////////////////////////////////////////////////////////*/ 

    /**
     * @notice initiates a sudoswap swapETHForAnyNFTs
     *
     * @dev sudoswap will return any unspent funds to 'recipient'
     * @dev order will revert if any sub-orders are unfilfillable 
     *
     * @param order                         encoded order args w/ selector
    */
    function swapETHForAnyNFTs(bytes calldata order) external payable {
        (bool success , ) = address(sudoswap).call{ value: msg.value }(order);

        if (!success) revert Sudoswap_PurchaseFailed();
    }

    /**
     * @notice initiates a sudoswap swapETHForSpecificNFTs
     *
     * @dev sudoswap will return any unspent funds to 'recipient'
     * @dev order will revert if any sub-orders are unfilfillable 
     *
     * @param order                         encoded order args w/ selector
    */
    function swapETHForSpecificNFTs(bytes calldata order) external payable {
        (bool success , ) = address(sudoswap).call{ value: msg.value }(order);

        if (!success) revert Sudoswap_PurchaseFailed();
    }

    /**
     * @notice initiates a sudoswap swapERC20ForAnyNFTs
     *
     * @dev we return any unspent funds to sender
     * @dev order will revert if any sub-orders are unfilfillable 
     *
     * @param order                         encoded order args w/ selector
    */
    function _swapERC20ForAnyNFTs(bytes calldata order) internal {
        (
            PairSwapAny[] memory swapList,    // NFT order
            uint256 inputAmount, ,            // total amount to spend,            
        ) = abi.decode(order[4:], (PairSwapAny[],uint256,address,uint256));

        // note: the ERC20 is the same for all trades
        ERC20 token = ILSSVMPair(swapList[0].pair).token();

        // transfer from user to Buyer contract
        token.safeTransferFrom(msg.sender, address(this), inputAmount);

        // approve sudoswap
        token.safeApprove(sudoswap, inputAmount);

        // submit order
        (bool success , bytes memory _unspent) = address(sudoswap).call{ value: msg.value }(order);

        if (!success) revert Sudoswap_PurchaseFailed();

        uint unspent = abi.decode(_unspent, (uint256));

        // refund buyer any unspent tokens
        // note: there is no refund address arg for ERC20 trades
        token.safeTransfer(msg.sender, unspent);
    }

    /**
     * @notice initiates a sudoswap swapERC20ForSpecificNFTs
     *
     * @dev we return any unspent funds to sender
     * @dev order will revert if any sub-orders are unfilfillable 
     *
     * @param order                         encoded order args w/ selector
    */
    function _swapERC20ForSpecificNFTs(bytes calldata order) internal {
        (
            PairSwapSpecific[] memory swapList,   // NFT order
            uint256 inputAmount, ,                // total amount to spend

        ) = abi.decode(order[4:], (PairSwapSpecific[],uint256,address,uint256));

        // note: the ERC20 is the same for all trades
        ERC20 token = ILSSVMPair(swapList[0].pair).token();

        // transfer from user to Buyer contract
        token.safeTransferFrom(msg.sender, address(this), inputAmount);

        // approve sudoswap
        token.safeApprove(sudoswap, inputAmount);

        // submit order
        (bool success , bytes memory _unspent) = address(sudoswap).call{ value: msg.value }(order);

        if (!success) revert Sudoswap_PurchaseFailed();

        uint unspent = abi.decode(_unspent, (uint256));

        // refund buyer any unspent tokens
        // note: there is no refund address arg for ERC20 trades
        token.safeTransfer(msg.sender, unspent);
    }

}