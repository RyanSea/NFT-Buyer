// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { 
    BasicOrderParameters, 
    AdvancedOrder, 
    CriteriaResolver, 
    SeaportInterface 
} from "seaport/interfaces/SeaportInterface.sol";

import { IERC20, SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

contract SeaportModule {

    /*///////////////////////////////////////////////////////////////
                              INITIALIZATION
    //////////////////////////////////////////////////////////////*/ 
    
    using SafeERC20 for IERC20;

    SeaportInterface public immutable seaport;

    constructor(address _seaport) {
        seaport = SeaportInterface(_seaport);
    }

    /*///////////////////////////////////////////////////////////////
                                  ERRORS
    //////////////////////////////////////////////////////////////*/ 

    /// @notice invalid seaport order
    error Seaport_InvalidOrder();

    /// @notice unsupported seaport oder type
    error Seaport_InvalidOrderType();

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

        if (selector == SeaportInterface.fulfillBasicOrder.selector) {
            _fulfillBasicOrder(order);

        } else if (selector == SeaportInterface.fulfillAdvancedOrder.selector) {
            // temp:
            revert Seaport_InvalidOrder(); //_fulfillAdvancedOrder(order);

        } else {
            revert Seaport_InvalidOrder();
        }
    }

    /*///////////////////////////////////////////////////////////////
                            ORDER FULFILLMENT
    //////////////////////////////////////////////////////////////*/ 

    /**
     * @notice routes basic order by OrderType, and executes call to Seaport
     *
     * @param order                         encoded order args w/ selector
    */
    function _fulfillBasicOrder(bytes calldata order) internal {
        BasicOrderParameters memory params = abi.decode(order[4:], (BasicOrderParameters));

        // save 'BasicOrderType' enum as uint
        uint order_type = uint(params.basicOrderType);

        // if trade is NFT <=> ETH/ERC20
        if (order_type >= 16) {
            revert Seaport_InvalidOrderType();

        // if trade is ETH <=> NFT
        } else if (order_type <= 7 ) {
            seaport.fulfillBasicOrder{value: msg.value}(params);

        // if trade is ERC20 <=> NFT
        } else if (order_type >= 8 ) {
            // calculate total price w/ consideration amount + amounts of additional recipients
    
            uint price = params.considerationAmount;
            uint length = params.additionalRecipients.length;

            for (uint i; i < length; ) {
                price += params.additionalRecipients[i].amount;

                unchecked { ++i; }
            }

            IERC20 token = IERC20(params.considerationToken);

            token.safeTransferFrom(msg.sender, address(this), price);

            token.safeApprove(address(seaport), price);

            seaport.fulfillBasicOrder(params); 
        }

    }


    /// review: identify security considerations before implementing.. I'm very new to seaport contracts
    // function _fulfillAdvancedOrder(bytes calldata order) internal {
    //     AdvancedOrder memory params = abi.decode(order[4:], (AdvancedOrder));

    //     uint total_consideration;
    //     uint length = params.parameters.consideration.length;

    //     for (uint i; i < length; ) {
    //         total_consideration += params.parameters.consideration[i].startAmount;

    //         unchecked { ++i; }
    //     }

        
    // }
    
    

}