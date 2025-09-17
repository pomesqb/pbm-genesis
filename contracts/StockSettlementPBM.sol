// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./PBMWrapper.sol";
import "./StockSettlementLogic.sol";

contract StockSettlementPBM is PBMWrapper {
    constructor(string memory _uriPostExpiry) PBMWrapper(_uriPostExpiry) {}

    // 內部使用
    function _createAndMintPBM(string memory _tokenName, address _creator, address _recipient, uint256 _amount, uint256 _tokenExpiry, string memory _tokenURI) internal returns (uint256) {
        uint256 newTokenId = IPBMTokenManager(pbmTokenManager).createTokenType(_tokenName, 1, _tokenExpiry, _creator, _tokenURI, contractExpiry);
        _mint(_recipient, newTokenId, _amount, "");
        return newTokenId;
    }
    
    // 「買股票」流程使用
    function executeMintFromLogic(string memory _tokenName, address _fundingSource, address _recipient, uint256 _amount, uint256 _tokenExpiry, string memory _tokenURI) external returns (uint256) {
        require(msg.sender == address(pbmLogic), "Only Logic contract can call");

        ERC20Helper.safeTransferFrom(IERC20(spotToken), _fundingSource, address(this), _amount);

        return _createAndMintPBM(_tokenName, _recipient, _recipient, _amount, _tokenExpiry, _tokenURI);
    }

    //「賣股票」流程使用 (由集保呼叫)
    function createAndMintRemittancePBM(address _custodianRecipient, uint256 _amount, uint256 _settlementTimestamp) external returns (uint256) {
        StockSettlementLogic logic = StockSettlementLogic(address(pbmLogic));
        require(msg.sender == logic.tdccAddress(), "Only TDCC can create remittance PBM");
        ERC20Helper.safeTransferFrom(IERC20(spotToken), msg.sender, address(this), _amount);
        uint256 newTokenId = _createAndMintPBM("Remittance PBM", msg.sender, _custodianRecipient, _amount, _settlementTimestamp + 365 days, "");
        logic.registerRule(newTokenId, StockSettlementLogic.PBMType.Remittance, _settlementTimestamp);
        return newTokenId;
    }
    
    // 「凍結轉交割」流程使用 (由保管行呼叫)
    function convertFrozenToSettlement(uint256 _frozenTokenId, uint256 _amount, uint256 _settlementTimestamp) external returns (uint256) {
        StockSettlementLogic logic = StockSettlementLogic(address(pbmLogic));
        require(logic.isCustodianBank(msg.sender), "Caller is not a custodian bank");

        (StockSettlementLogic.PBMType pbmType, ) = logic.tokenRules(_frozenTokenId);
        require(pbmType == StockSettlementLogic.PBMType.Frozen, "Not a valid Frozen PBM");
        
        _burn(msg.sender, _frozenTokenId, _amount);

        uint256 newSettlementTokenId = _createAndMintPBM("Settlement PBM", msg.sender, msg.sender, _amount, _settlementTimestamp + 365 days, "");
        logic.registerRule(newSettlementTokenId, StockSettlementLogic.PBMType.Settlement, _settlementTimestamp);
        return newSettlementTokenId;
    }
}