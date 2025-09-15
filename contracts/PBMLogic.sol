// File: PBMLogic.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IPBMAddressList.sol";

abstract contract PBMLogic is IPBMAddressList {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "PBM: caller is not the owner");
        _;
    }

    function transferPreCheck(
        address _from,
        address _to,
        uint256 _tokenId
    ) external view virtual returns (bool) {
        return true;
    }

    function unwrapPreCheck(
        address _unwrapper,
        uint256 _tokenId,
        uint256 _valueDate // Can be used for time-based logic, e.g. settlement date
    ) external view virtual returns (bool) {
        return true;
    }
}