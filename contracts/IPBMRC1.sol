// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
import "contracts/IERC173.sol";
import "contracts/IERC5679Ext1155.sol";
interface IPBMRC1 {
    event MerchantPayment(
        address indexed from,
        address indexed to,
        uint256[] tokenIds,
        uint256[] amounts,
        address spotToken,
        uint256 spotTokenAmount
    );

    event PBMrevokeWithdraw(
        address indexed revoker,
        uint256 tokenId,
        address spotToken,
        uint256 spotTokenAmount
    );

    // 我們依然保留 owner 和 transferOwnership 的函式簽名，
    // PBMWrapper 稍後會明確地覆寫它們。
    function owner() external view returns (address owner_);
    function transferOwnership(address _newOwner) external;

    function mint(
        uint256 tokenId,
        uint256 amount,
        address receiver
    ) external;

    function batchMint(
        uint256[] memory tokenIds,
        uint256[] memory amounts,
        address receiver
    ) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;

    function revokePBM(uint256 tokenId) external;

    function uri(uint256 tokenId) external view returns (string memory);
}

