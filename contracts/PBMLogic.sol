// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IPBMAddressList.sol";

/**
 * @title PBMLogic
 * @author Monetary Authority of Singapore
 * @notice Abstract contract for PBM Logic
 */
abstract contract PBMLogic is IPBMAddressList {
    address public owner;
    mapping(address => bool) public isBlacklistedAddress;
    mapping(address => bool) public isMerchantAddress;
    mapping(address => bool) public isWhitelistedAddress;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "PBM: caller is not the owner");
        _;
    }

    function transferPreCheck(address, address) external view virtual returns (bool) {
        return true;
    }

    function unwrapPreCheck(address) external view virtual returns (bool) {
        return true;
    }

    function blacklistAddresses(address[] memory addresses, string memory metadata) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            isBlacklistedAddress[addresses[i]] = true;
        }
        emit Blacklist("add",addresses, metadata);
    }

    function unBlacklistAddresses(address[] memory addresses, string memory metadata) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            isBlacklistedAddress[addresses[i]] = false;
        }
        emit Blacklist("remove",addresses, metadata);
    }

    function isBlacklisted(address _address) external view returns (bool) {
        return isBlacklistedAddress[_address];
    }

    function addMerchantAddresses(address[] memory addresses, string memory metadata) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            isMerchantAddress[addresses[i]] = true;
        }
        emit MerchantList("add",addresses, metadata);
    }

    function removeMerchantAddresses(address[] memory addresses, string memory metadata) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            isMerchantAddress[addresses[i]] = false;
        }
        emit MerchantList("remove",addresses, metadata);
    }

    function isMerchant(address _address) external view returns (bool) {
        return isMerchantAddress[_address];
    }

    function whitelistAddresses(address[] memory addresses, string memory metadata) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            isWhitelistedAddress[addresses[i]] = true;
        }
        emit Whitelist("add",addresses, metadata);
    }

    function unWhitelistAddresses(address[] memory addresses, string memory metadata) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            isWhitelistedAddress[addresses[i]] = false;
        }
        emit Whitelist("remove",addresses, metadata);
    }

    function isWhitelisted(address _address) external view returns (bool) {
        return isWhitelistedAddress[_address];
    }
}