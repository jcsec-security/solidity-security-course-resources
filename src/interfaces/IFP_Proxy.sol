// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

interface IFP_Proxy {
    /**
     * @dev Performs implementation upgrade with additional setup call if data is nonempty.
     * This function is payable only if the setup call is performed, otherwise `msg.value` is rejected
     * to avoid stuck value in the contract.
     *
     * Emits an {IERC1967-Upgraded} event.
     */  
    function upgradeToAndCall(address _newImplementation, bytes memory _data) external;

    /**
     * @dev Returns the current implementation address.
     */
    function getImplementation() external view returns (address);
}