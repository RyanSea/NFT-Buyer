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

    ILSSVMRouter public immutable sudoswap;

    constructor(address _sudoswap) {
        sudoswap = ILSSVMRouter(_sudoswap);
    }

    /*///////////////////////////////////////////////////////////////
                                  ERRORS
    //////////////////////////////////////////////////////////////*/ 

    /// @notice invalid sudoswap order
    error Sudoswap_InvalidOrder();

    /*///////////////////////////////////////////////////////////////
                              ORDER ROUTER
    //////////////////////////////////////////////////////////////*/ 

    /**
     * @notice routes order
     *
     * @dev will revert if selector isn't a supported sudoswap function
     *
     * @param order                         encoded order args w/ selector
    */
    function fulfillOrder(bytes calldata order) external virtual {
        bytes4 selector = bytes4(order[:4]);

        if (selector == ILSSVMRouter.swapETHForAnyNFTs.selector) {
            _swapETHForAnyNFTs(order);
        } else if (selector == ILSSVMRouter.swapETHForSpecificNFTs.selector) {
            _swapETHForSpecificNFTs(order);
        } else if (selector == ILSSVMRouter.swapERC20ForAnyNFTs.selector) {
            _swapERC20ForAnyNFTs(order);
        } else if (selector == ILSSVMRouter.swapERC20ForSpecificNFTs.selector) {
            _swapERC20ForSpecificNFTs(order);
        } else {
            revert Sudoswap_InvalidOrder();
        }
    }

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
    function _swapETHForAnyNFTs(bytes calldata order) internal {
        (
            PairSwapAny[] memory swapList,  // NFT order
            address payable recipient,      // recipient of unspent funds
            address nftRecipient,           // recipient of NFTs
            uint256 deadline                // epoch deadline for order
        ) = abi.decode(order[4:], (PairSwapAny[],address,address,uint256));

        uint256 unspent = sudoswap.swapETHForAnyNFTs{ value : msg.value }(
            swapList, 
            recipient, 
            nftRecipient, 
            deadline
        );

        // refund sender any unspent tokens
        if (unspent > 0) msg.sender.call{ value: unspent }("");
    }

    /**
     * @notice initiates a sudoswap swapETHForSpecificNFTs
     *
     * @dev sudoswap will return any unspent funds to 'recipient'
     * @dev order will revert if any sub-orders are unfilfillable 
     *
     * @param order                         encoded order args w/ selector
    */
    function _swapETHForSpecificNFTs(bytes calldata order) internal {
        (
            PairSwapSpecific[] memory swapList,  // NFT order
            address payable recipient,           // recipient of unspent funds
            address nftRecipient,                // recipient of NFTs
            uint256 deadline                     // epoch deadline for order
        ) = abi.decode(order[4:], (PairSwapSpecific[],address,address,uint256));

        uint256 unspent = sudoswap.swapETHForSpecificNFTs{ value : msg.value }(
            swapList, 
            recipient, 
            nftRecipient, 
            deadline
        );

        // refund sender any unspent tokens
        if (unspent > 0) msg.sender.call{ value: unspent }("");
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
            uint256 inputAmount,              // total amount to spend
            address nftRecipient,             // receiver of NFT's
            uint256 deadline                  // deadline for trade
        ) = abi.decode(order[4:], (PairSwapAny[],uint256,address,uint256));

        // note: the ERC20 is the same for all trades
        ERC20 token = ILSSVMPair(swapList[0].pair).token();

        // transfer from user to Buyer contract
        token.safeTransferFrom(msg.sender, address(this), inputAmount);

        // approve pools
        _approvePairSwapAny(token, swapList);

        // submit order
        sudoswap.swapERC20ForAnyNFTs(
            swapList,
            inputAmount,
            nftRecipient,
            deadline
        );
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
            uint256 inputAmount,                  // total amount to spend
            address nftRecipient,                 // receiver of NFT's
            uint256 deadline                      // deadline for trade
        ) = abi.decode(order[4:], (PairSwapSpecific[],uint256,address,uint256));

        // note: the ERC20 is the same for all trades
        ERC20 token = ILSSVMPair(swapList[0].pair).token();

        // transfer from user to Buyer contract
        token.safeTransferFrom(msg.sender, address(this), inputAmount);

        // approve pools
        _approvePairSwapSpecific(token, swapList);

        // submit order
        sudoswap.swapERC20ForSpecificNFTs(
            swapList,
            inputAmount,
            nftRecipient,
            deadline
        );
    }

    /*///////////////////////////////////////////////////////////////
                              PAIR APPROVALS
    //////////////////////////////////////////////////////////////*/ 

    /**
     * @notice approves each pool in a PairSwapAny[] by getting a quote for each order
     *
     * @dev not very optimal gas-wise, exploring a solution for this in the upgrade
     *
     * @param swapList                      PairSwapAny[] containing order
    */
    function _approvePairSwapAny(ERC20 token, PairSwapAny[] memory swapList) internal {
        uint length = swapList.length;

        ILSSVMPair pair;
        uint256 price;
        uint256 fee;

        // iterate through swapList, get pool price for NFTs, and approve pool
        for (uint i; i < length; ) {
            pair = swapList[i].pair;

            ( , , , price, fee) = pair.getBuyNFTQuote(swapList[i].numItems);

            token.safeApprove(address(pair), price + fee);

            unchecked { ++i; }
        }
    }

    /**
     * @notice approves each pool in a PairSwapSpecific[] by getting a quote for each order
     *
     * @dev not very optimal gas-wise, exploring a solution for this in the upgrade
     *
     * @param swapList                      PairSwapSpecific[] containing order
    */
    function _approvePairSwapSpecific( ERC20 token, PairSwapSpecific[] memory swapList) internal {
        uint length = swapList.length;

        ILSSVMPair pair;
        uint256 price;
        uint256 fee;

        // iterate through swapList, get pool price for NFTs, and approve pool
        for (uint i; i < length; ) {
            pair = swapList[i].pair;

            ( , , , price, fee) = pair.getBuyNFTQuote(swapList[i].nftIds.length);

            token.safeApprove(address(pair), price + fee);

            unchecked { ++i; }
        }
    }

}