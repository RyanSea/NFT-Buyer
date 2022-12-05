// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "src/Buyer.sol";

import "src/interfaces/IMarketModule.sol";

import { 
    SudoswapModule, 
    ILSSVMPair,
    ILSSVMRouter,
    PairSwapAny, 
    PairSwapSpecific 
} from  "src/market_modules/SudoswapModule.sol";

import {
    SeaportModule,
    BasicOrderParameters, 
    AdvancedOrder, 
    CriteriaResolver, 
    SeaportInterface 
} from "src/market_modules/SeaportModule.sol";

import "openzeppelin/token/ERC721/IERC721.sol";

contract BuyerTest is Test {
    // contracts
    Buyer buyer;
    SudoswapModule sudo_module;
    SeaportModule sea_module;

    // purchaser
    address user;

    // sudo router
    address sudoswap;

    // nfts
    IERC721 milady;

    // sudo pools
    ILSSVMPair otherdeed_pool; // 65679, 86469, 99876, 76017, 72894
    ILSSVMPair ghoul_pool;     // 2367, 3699, 2304, 2219
    ILSSVMPair milady_pool;    // 4307, 5212

    function setUp() public {
        // create Buyer
        buyer = new Buyer();

        // setup sudo
        _sudoSetup();

        // fund user
        user = 0xaB8A7848E9C6E22e52B5e3edf8e2b779727B17Ad;
        vm.prank(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        user.call{value: 500 * 10 ** 18}("");
    }

    function testSudoPurchase() public {
        PairSwapSpecific[] memory swaps = _sudoSetupSpecificOrder();

        uint price = _sudoPairSpecificGetPrice(swaps);

        // bytes memory order_payload = abi.encode(
        //     swaps,
        //     payable(user),
        //     user,
        //     block.timestamp + 10000
        // );

        bytes memory order = abi.encodeWithSelector(
            ILSSVMRouter.swapETHForSpecificNFTs.selector, 
            swaps,
            payable(user),
            user,
            block.timestamp + 10000
        );
        
        Buyer.OrderData memory order_data = Buyer.OrderData(order, address(sudo_module));

        uint bal_before = user.balance;

        vm.prank(user);
        buyer.initiateOrder{ value: price}(order_data);

        uint bal_after = user.balance;

        assertEq(price, bal_before - bal_after);

        assertEq(milady.ownerOf(9397), user);
    }

    /*///////////////////////////////////////////////////////////////
                              INTERNAL SETUPS
    ///////////////////////////////////////////////////////////////*/ 
    
    /// @notice sets up sudoswap
    function _sudoSetup() internal {
        // create market module
        sudo_module = new SudoswapModule(sudoswap);

        // initialize sudo address
        sudoswap = 0x2B2e8cDA09bBA9660dCA5cB6233787738Ad68329;

        // initialize nfts
        milady = IERC721(0x5Af0D9827E0c53E4799BB226655A1de152A425a5);
        
        // initialize pools
        otherdeed_pool = ILSSVMPair(0x188e700338E0C89B82f9171E93D0504aE0105eEE);
        ghoul_pool = ILSSVMPair(0x259524Ed1606F5Ecd39E5815108843d7C8E8Fa78);
        milady_pool = ILSSVMPair(0x83DB008998ffE8D49aD8c81383df2153D8146173);

        // validate market module
        buyer.validateModule(address(sudo_module));
    }

    /// @notice returns price for a PairSwapSpecific[]
    function _sudoPairSpecificGetPrice(PairSwapSpecific[] memory swaps) internal view returns (uint totalPrice) {
        uint price;
        uint fee;

        uint length = swaps.length;

        for (uint i; i < length; ) {
            ( , , , price, fee) = swaps[i].pair.getBuyNFTQuote(swaps[i].nftIds.length);

            totalPrice += price + fee;

            unchecked { ++i; }
        }
    }

    function _sudoSetupSpecificOrder() internal view returns (PairSwapSpecific[] memory swaps) {
        (
            uint256[] memory otherdeed_ids, 
            uint256[] memory ghoul_ids,
            uint256[] memory milady_ids
        ) = _sudoSetupIds();

        swaps = new PairSwapSpecific[](3);
        swaps[0] = PairSwapSpecific(otherdeed_pool, otherdeed_ids);
        swaps[1] = PairSwapSpecific(ghoul_pool, ghoul_ids);
        swaps[2] = PairSwapSpecific(milady_pool, milady_ids);
        
    }

    function _sudoSetupIds() internal pure returns (uint256[] memory, uint256[] memory, uint256[] memory) {
        uint256[] memory otherdeed_ids = new uint256[](5);
        otherdeed_ids[0] = 65679;
        otherdeed_ids[1] = 86469;
        otherdeed_ids[2] = 99876;
        otherdeed_ids[3] = 76017;
        otherdeed_ids[4] = 72894;

        uint256[] memory ghoul_ids = new uint256[](4);
        ghoul_ids[0] = 2367;
        ghoul_ids[1] = 3699;
        ghoul_ids[2] = 2304;
        ghoul_ids[3] = 2219;

        uint256[] memory milady_ids = new uint256[](2);
        milady_ids[0] = 7003;
        milady_ids[1] = 9397;

        return (otherdeed_ids, ghoul_ids, milady_ids);
    }
}
