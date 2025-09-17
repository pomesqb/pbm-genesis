// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./PBMLogic.sol";
import "./IPBMTokenManager.sol";
import "./StockSettlementPBM.sol";

contract StockSettlementLogic is PBMLogic, ChainlinkClient {
    using Strings for address;

    enum PBMType { None, Settlement, Remittance, Frozen }
    struct RuleInfo { PBMType pbmType; uint256 timeLockTimestamp; }

    address public tdccAddress;
    mapping(address => bool) public isCustodianBank;
    IPBMTokenManager public pbmTokenManager;
    StockSettlementPBM public stockPBM;
    mapping(uint256 => RuleInfo) public tokenRules;

    bytes32 private jobId;
    uint256 private fee;

    mapping(bytes32 => address) private requestToCustodian;
    mapping(bytes32 => uint256) private requestToAmount;

    event PBMRegistrationRequested(bytes32 indexed requestId, address custodian, string transactionId, uint256 amount); 
    event PBMRegisteredAndMinted(uint256 indexed tokenId, PBMType pbmType, uint256 timeLock);

    constructor(address _pbmTokenManagerAddress, address _stockPBMAddress) {
        _setChainlinkToken(0x779877A7B0D9E8603169DdbD7836e478b4624789);
        _setChainlinkOracle(0x6090149792dAaeE9d1d568C9F9A6F6846AA29EFd);
        pbmTokenManager = IPBMTokenManager(_pbmTokenManagerAddress);
        stockPBM = StockSettlementPBM(_stockPBMAddress);
        jobId = "7d80a6386ef543a3abb52817f6707e3b";
        fee = 0.1 * 10**18;
    }

    function setTdccAddress(address _tdcc) external onlyOwner { tdccAddress = _tdcc; }
    function addCustodianBank(address _bank) external onlyOwner { isCustodianBank[_bank] = true; }

    function requestPBMRegistration(string memory _transactionId, uint256 _amount) external {
        require(isCustodianBank[msg.sender], "Caller is not a custodian bank");
        require(LinkTokenInterface(_chainlinkTokenAddress()).balanceOf(address(this)) >= fee, "Not enough LINK");

        Chainlink.Request memory req = _buildChainlinkRequest(jobId, address(this), this.fulfillPBMRequest.selector);
        
        //string memory url = string(abi.encodePacked("https://your-bank.com/api/trades?transactionId=", _transactionId));
        //req.add("get", url);
        //req.add("path", "settlementTimestamp");
        
        bytes32 requestId = _sendChainlinkRequest(req, fee);

        requestToCustodian[requestId] = msg.sender;
        requestToAmount[requestId] = _amount;
        emit PBMRegistrationRequested(requestId, msg.sender, _transactionId, _amount);
    }

    function fulfillPBMRequest(bytes32 _requestId, uint256 _settlementTimestamp) public recordChainlinkFulfillment(_requestId) {
        address custodian = requestToCustodian[_requestId];
        uint256 amount = requestToAmount[_requestId];
        
        string memory tokenName;
        uint256 tokenExpiry;
        PBMType pbmType;

        if (_settlementTimestamp > 0) {
            require(_settlementTimestamp > block.timestamp, "Settlement date must be in the future");
            tokenName = "Settlement PBM";
            tokenExpiry = _settlementTimestamp + 365 days;
            pbmType = PBMType.Settlement;
        } else {
            tokenName = "Frozen PBM";
            tokenExpiry = block.timestamp + 365 days;
            pbmType = PBMType.Frozen;
        }
        
        uint256 newTokenId = stockPBM.executeMintFromLogic(tokenName, custodian, custodian, amount, tokenExpiry, "");
        registerRule(newTokenId, pbmType, _settlementTimestamp);
    }
    
    function registerRule(uint256 _tokenId, PBMType _pbmType, uint256 _timeLockTimestamp) public {
        require(msg.sender == address(stockPBM) || msg.sender == address(this), "Unauthorized caller");
        tokenRules[_tokenId] = RuleInfo({ pbmType: _pbmType, timeLockTimestamp: _timeLockTimestamp });
        emit PBMRegisteredAndMinted(_tokenId, _pbmType, _timeLockTimestamp);
    }

    function unwrapPreCheck(address _unwrapper, uint256 _tokenId, bytes calldata) external view override returns (bool) {
        RuleInfo memory rules = tokenRules[_tokenId];
        if (rules.pbmType == PBMType.None) return false;
        if (rules.pbmType != PBMType.Frozen && block.timestamp < rules.timeLockTimestamp) return false;
        if (rules.pbmType == PBMType.Settlement) return _unwrapper == tdccAddress;
        if (rules.pbmType == PBMType.Remittance) return isCustodianBank[_unwrapper];
        if (rules.pbmType == PBMType.Frozen) return false;
        return false;
    }
    
    function transferPreCheck(address, address, uint256 _tokenId) external view override returns (bool) {
        if (tokenRules[_tokenId].pbmType == PBMType.Frozen) return false;
        return true;
    }

    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(_chainlinkTokenAddress());
        require(link.transfer(msg.sender, link.balanceOf(address(this))), "Unable to transfer");
    }
}