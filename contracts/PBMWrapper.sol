// File: PBMWrapper.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IPBMRC1.sol";
import "./PBMTokenManager.sol";
import "./PBMLogic.sol";

library ERC20Helper {
    using SafeERC20 for IERC20;

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        SafeERC20.safeTransferFrom(token, from, to, value);
    }

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        SafeERC20.safeTransfer(token, to, value);
    }
}

abstract contract PBMWrapper is ERC1155, Ownable, Pausable, IPBMRC1 {
    address public spotToken;
    address public pbmTokenManager;
    bool public initialised;
    uint256 public contractExpiry;
    PBMLogic public pbmLogic;

    constructor(string memory _uriPostExpiry) ERC1155("") Ownable(msg.sender) {
        pbmTokenManager = address(new PBMTokenManager(_uriPostExpiry));
    }

    modifier whenInitialised() {
        require(initialised, "PBM: Contract not initialised");
        _;
    }

    function serialise(uint256 num) internal pure returns (uint256[] memory) {
        uint256[] memory arr = new uint256[](1);
        arr[0] = num;
        return arr;
    }

    // --- 函式覆寫修正 ---

    // ✅ 修正 1: 實現 uri 函式以解決 ERC1155 和 IPBMRC1 的衝突
    // 我們將呼叫 PBMTokenManager 中的 uri 邏輯
    function uri(uint256 tokenId)
        public
        view
        override(ERC1155, IPBMRC1)
        returns (string memory)
    {
        return PBMTokenManager(pbmTokenManager).uri(tokenId);
    }

    // ✅ 修正 2: 實現 owner 函式以解決 Ownable 和 IPBMRC1 的衝突
    // 我們直接使用 Ownable 已有的功能
    function owner() public view override(Ownable, IPBMRC1) returns (address) {
        return super.owner();
    }

    // ✅ 修正 3: 實現 transferOwnership 以解決 Ownable 和 IPBMRC1 的衝突
    // 我們直接使用 Ownable 已有的功能
    function transferOwnership(address newOwner) public override(Ownable, IPBMRC1) onlyOwner {
        super.transferOwnership(newOwner);
    }

    // ✅ 修正 4: 為 safeTransferFrom 指定覆寫來源
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override(ERC1155, IPBMRC1) whenNotPaused {
        // ... (原有的函式內容保持不變)
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner nor approved"
        );
        require(
            pbmLogic.transferPreCheck(from, to),
            "PBM Logic: transfer preCheck not satisfied."
        );
        if (pbmLogic.unwrapPreCheck(to)) {
            uint256 valueOfTokens = amount *
                (
                    PBMTokenManager(pbmTokenManager).getTokenValue(id)
                );
            _burn(from, id, amount);
            PBMTokenManager(pbmTokenManager).decreaseBalanceSupply(
                serialise(id),
                serialise(amount)
            );
            ERC20Helper.safeTransfer(IERC20(spotToken), to, valueOfTokens);
            emit MerchantPayment(
                from,
                to,
                serialise(id),
                serialise(amount),
                spotToken,
                valueOfTokens
            );
        } else {
            _safeTransferFrom(from, to, id, amount, abi.encodePacked(data));
        }
    }
    
    // --- 其他函式 ---

    // ✅ 修正 5: 移除 mint 和 batchMint 的 override 關鍵字
    function mint(
        uint256 tokenId,
        uint256 amount,
        address receiver
    ) public virtual whenNotPaused whenInitialised {
        uint256 valueOfNewTokens = amount *
            (
                PBMTokenManager(pbmTokenManager).getTokenValue(tokenId)
            );
        require(
            pbmLogic.transferPreCheck(address(0), receiver),
            "PBM: 'to' address blacklisted"
        );
        ERC20Helper.safeTransferFrom(
            IERC20(spotToken),
            msg.sender,
            address(this),
            valueOfNewTokens
        );
        PBMTokenManager(pbmTokenManager).increaseBalanceSupply(
            serialise(tokenId),
            serialise(amount)
        );
        _mint(receiver, tokenId, amount, "");
    }

    function batchMint(
        uint256[] memory tokenIds,
        uint256[] memory amounts,
        address receiver
    ) public virtual whenNotPaused whenInitialised {
         uint256 valueOfNewTokens = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            valueOfNewTokens +=
                amounts[i] *
                (
                    PBMTokenManager(pbmTokenManager).getTokenValue(
                        tokenIds[i]
                    )
                );
        }
        require(
            pbmLogic.transferPreCheck(address(0), receiver),
            "PBM: 'to' address blacklisted"
        );
        ERC20Helper.safeTransferFrom(
            IERC20(spotToken),
            msg.sender,
            address(this),
            valueOfNewTokens
        );
        PBMTokenManager(pbmTokenManager).increaseBalanceSupply(
            tokenIds,
            amounts
        );
        _mintBatch(receiver, tokenIds, amounts, "");
    }
    
    // ... (其他函式 initialise, revokePBM 等保持不變)
}