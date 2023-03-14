
# Basic solidity security examples!

Here you have multiple small examples of basic security issue of solidity smart contracts to start your security journey. 


:star: `101`

- Logic bug
- Basic reentrancy 
	- [Short description at SWC-107](https://swcregistry.io/docs/SWC-107)
- Unencrypted secret data on-chain 
	- [Short description at SWC-136](https://swcregistry.io/docs/SWC-136)
- Weak pseudo-randomness 
	- [Short description at SWC-120](https://swcregistry.io/docs/SWC-120)
- Arithmetic overflow 
	- [Short description at SWC-101](https://swcregistry.io/docs/SWC-101)
- Access controls (both missing and through `tx.origin`) 
	- [Short description at SWC-115](https://swcregistry.io/docs/SWC-115)
- Force feeding ether 
	- [Short description at SWC-132](https://swcregistry.io/docs/SWC-132)
- Gas exhaustion 
	- [Short description at SWC-128](https://swcregistry.io/docs/SWC-128)


:star: `102`

- Push vs Pull approach (PoC can be found in test/)  
	- [Short description at SWC-113](https://swcregistry.io/docs/SWC-113)
- Cross-function reentrancy (PoC can be found in test/)
- Commit and reveal scheme implementations (PoC can be found in test/)
	- Pre-computable 
	- Replayable (+ frontrun)



:warning::warning::warning:DO NOT DEPLOY THIS, IT IS FULL OF SECURITY ISSUES:warning::warning::warning:


## Next steps

The current version is `v0.2`. At the moment I would like to achieve the below in order to upgrade it:

:pushpin:`V1.0`

- Unchecked return value example https://swcregistry.io/docs/SWC-104
- Multiple examples per basic issue
- Foundry tests of the 101 issues
- Deploy to testnet and add etherscan links
- Additional reentrancy options: cross contract and token based


