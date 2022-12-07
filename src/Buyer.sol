// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IERC20, SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin/utils/Address.sol";

import "solmate/utils/ReentrancyGuard.sol";

import "./market_modules/SudoswapModule.sol";

import "./interfaces/IMarketModule.sol";

contract Buyer is ReentrancyGuard {
    
    /*///////////////////////////////////////////////////////////////
                              INITIALIZATION
    ///////////////////////////////////////////////////////////////*/ 

    using Address for address;
    using SafeERC20 for IERC20;

    constructor() {
        admin = msg.sender;
    }

    /*///////////////////////////////////////////////////////////////
                                  ERRORS
    ///////////////////////////////////////////////////////////////*/ 

    /// @notice permissioned call by non-admin
    error NotAdmin();

    /// @notice unrecognized market module
    error InvalidModule();

    /*///////////////////////////////////////////////////////////////
                          BUYER STATE & PARAMS
    ///////////////////////////////////////////////////////////////*/ 

    /// @notice admin of buyer module
    address public admin;
    
    /// @notice market module address => whether or not it's valid
    mapping(address => bool) public valid;

    /**
     * @notice order info
     *
     * @param order                         encoded market args including selector
     * @param module                        address of market module
    */
    struct OrderData {
        bytes order;
        address module;
    }

    /// @notice require sender == admin
    modifier permissioned {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    /*///////////////////////////////////////////////////////////////
                                PURCHASE
    ///////////////////////////////////////////////////////////////*/ 
    
    /**
     * @notice initiates purchase, delegating call w/ encoded market params to 
     *         a verified market module
     *
     * @dev market module must be verified by admin
     *
     * @param order_data                    OrderData struct
    */
    function initiateOrder(OrderData calldata order_data) external payable nonReentrant {
        if (!valid[order_data.module]) revert InvalidModule();

        //bytes memory payload = abi.encodeWithSelector(IMarketModule.fulfillOrder.selector, order_data.order);
        
        order_data.module.functionDelegateCall(order_data.order);
    }

    /*///////////////////////////////////////////////////////////////
                             ADMIN FUNCTIONS
    ///////////////////////////////////////////////////////////////*/ 

    /**
     * @notice sets module address as valid
     *
     * @dev only callable by admin
     *
     * @param module                        address of market module
    */
    function validateModule(address module) external permissioned {
        valid[module] = true;
    }

    /**
     * @notice sets module address as invalid
     *
     * @dev only callable by admin
     *
     * @param module                        address of market module
    */
    function invalidateModule(address module) external permissioned {
        valid[module] = false;
    }

    /**
     * @notice assigns a new admin
     *
     * @dev only callable by admin
     *
     * @param _admin                        address of new admin
    */
    function setAdmin(address _admin) external permissioned {
        admin = _admin;
    }
}
