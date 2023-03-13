
# Basic solidity security examples!

Here you have multiple small examples of basic security issue of solidity smart contracts to start your security journey. 


:star: `101`

- Logic bug
- Basic reentrancy
- Public data treated as secret
- Weak pseudo-randomness
- Arithmetic overflow
- Access controls (both missing and through `tx.origin`)
- Force feeding ether
- Gas exhaustion


:star: `102`

- Push vs Pull approach (PoC can be found in test/)
- Cross-function reentrancy (PoC can be found in test/)
- Commit and reveal scheme implementations (PoC can be found in test/)
	- Pre-computable 
	- Replayable (+ frontrun)



:boom:DO NOT DEPLOY THIS, IT IS FULL OF SECURITY ISSUES:boom:


## Next steps

The current version is `v0.2`. At the moment I would like to achieve the below in order to upgrade it:

`V1.0`

- Foundry tests of the 101 issues
- Deploy to testnet and add links to etherscan
- Cross-contract reentrancy
- Token-callback reentrancy

