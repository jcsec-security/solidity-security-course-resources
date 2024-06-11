// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {ERC1967Proxy} from "@openzeppelin/contracts@v5.0.1/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC1967Utils} from "@openzeppelin/contracts@v5.0.1/proxy/ERC1967/ERC1967Utils.sol";
import {AccessControl} from "@openzeppelin/contracts@v5.0.1/access/AccessControl.sol";

/**
 * @dev This contract implements an upgradeable proxy. 
 * The implementation address is stored in storage in the location specified by https://eips.ethereum.org/EIPS/eip-1967[EIP1967], 
 * so that it doesn't conflict with the storage layout of the implementation behind the proxy.
 */
contract FP_Proxy is ERC1967Proxy, AccessControl {

    /************************************** Constants *******************************************************/

    ///@notice The DAO role ID for the AccessControl contract
    bytes32 public constant DAO_ROLE = keccak256("DAO_ROLE");


    /************************************** External *******************************************************/

    /**
     * @dev Initializes the upgradeable proxy with an initial implementation specified by `implementation`.
     *
     * If `_data` is nonempty, it's used as data in a delegate call to `implementation`. This will typically be an
     * encoded function call, and allows initializing the storage of the proxy like a Solidity constructor.
     *
     * Requirements:
     *
     * - If `data` is empty, `msg.value` must be zero.
     */
    constructor(address implementation, bytes memory _data, address _dao) ERC1967Proxy(implementation, _data) {
        _grantRole(DAO_ROLE, _dao);
    }

    /**
     * @dev Performs implementation upgrade with additional setup call if data is nonempty.
     * This function is payable only if the setup call is performed, otherwise `msg.value` is rejected
     * to avoid stuck value in the contract.
     *
     * Emits an {IERC1967-Upgraded} event.
     */  
    function upgradeToAndCall(address _newImplementation, bytes memory _data) external onlyRole(DAO_ROLE) { 
        ERC1967Utils.upgradeToAndCall(_newImplementation, _data);        
    }

    /**
     * @dev Returns the current implementation address.
     */
    function getImplementation() external view returns (address) {
        return _implementation();
    }
}