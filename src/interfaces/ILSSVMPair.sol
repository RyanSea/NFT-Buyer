// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "sudoswap/bonding-curves/CurveErrorCodes.sol";

import "solmate/tokens/ERC20.sol";

import "openzeppelin/token/ERC721/IERC721.sol";

interface ILSSVMPair {

    enum PoolType {
        TOKEN,
        NFT,
        TRADE
    }

    function nft() external view returns (IERC721 _nft);

    function token() external view returns (ERC20 token);

    function getAllHeldIds() external view returns (uint256[] memory);

    function swapTokenForSpecificNFTs(
        uint256[] calldata nftIds,
        uint256 maxExpectedTokenInput,
        address nftRecipient,
        bool isRouter,
        address routerCaller
    ) external payable returns (uint256 inputAmount);

    function getBuyNFTQuote(uint256 numNFTs)
        external
        view
        returns (
            CurveErrorCodes.Error error,
            uint256 newSpotPrice,
            uint256 newDelta,
            uint256 inputAmount,
            uint256 protocolFee
        );
}