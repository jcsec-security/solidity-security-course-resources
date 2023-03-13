# FP_Token
[Git Source](https://github.com/jcr-security/solidity-security-teaching-resources/blob/7024bbd4dfb96e5bd0815e639fbc19b2a524a34b/src/Faillapop_ERC20.sol)

**Inherits:**
ERC20, ERC20Burnable, Pausable, AccessControl


## State Variables
### PAUSER_ROLE

```solidity
bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
```


### MINTER_ROLE

```solidity
bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
```


## Functions
### constructor


```solidity
constructor() ERC20("FaillaPop Token", "FPT");
```

### pause


```solidity
function pause() public onlyRole(PAUSER_ROLE);
```

### unpause


```solidity
function unpause() public onlyRole(PAUSER_ROLE);
```

### mint


```solidity
function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE);
```

### _beforeTokenTransfer


```solidity
function _beforeTokenTransfer(address from, address to, uint256 amount) internal override whenNotPaused;
```

