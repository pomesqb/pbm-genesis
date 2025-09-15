// File: IPBMTokenManager.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPBMTokenManager {
    struct TokenConfig {
        string name;
        uint256 amount;
        uint256 balanceSupply;
        uint256 expiry;
        address creator;
        string uri;
    }

    event NewPBMTypeCreated(
        uint256 indexed tokenId,
        string tokenName,
        uint256 spotAmount,
        uint256 tokenExpiry,
        address creator
    );

    event PBMRevoked(uint256 indexed tokenId, address sender);

    function createTokenType(
        string memory tokenName,
        uint256 spotAmount,
        uint256 tokenExpiry,
        address creator,
        string memory tokenURI,
        uint256 contractExpiry
    ) external returns (uint256 tokenId);

    function revokePBM(uint256 tokenId, address sender) external;

    function increaseBalanceSupply(
        uint256[] memory tokenIds,
        uint256[] memory amounts
    ) external;

    function decreaseBalanceSupply(
        uint256[] memory tokenIds,
        uint256[] memory amounts
    ) external;
        
    function uri(uint256 tokenId) external view returns (string memory);

    function getTokenDetails(uint256 tokenId)
        external
        view
        returns (
            string memory name,
            uint256 amount,
            uint256 balanceSupply,
            uint256 expiry,
            address creator
        );

    function getTokenValue(uint256 tokenId) external view returns (uint256);
        
    function getPBMRevokeValue(uint256 tokenId)
        external
        view
        returns (uint256);
}