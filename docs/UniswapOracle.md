# UniswapOracle









## Methods

### UNISWAP_V3_FACTORY_ADDRESS

```solidity
function UNISWAP_V3_FACTORY_ADDRESS() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### USDC_ADDRESS

```solidity
function USDC_ADDRESS() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### consult

```solidity
function consult(uint32 secondsAgo) external view returns (int24 arithmeticMeanTick, uint128 harmonicMeanLiquidity)
```

Calculates time-weighted means of tick and liquidity for a given Uniswap V3 pool



#### Parameters

| Name | Type | Description |
|---|---|---|
| secondsAgo | uint32 | Number of seconds in the past from which to calculate the time-weighted means |

#### Returns

| Name | Type | Description |
|---|---|---|
| arithmeticMeanTick | int24 | The arithmetic mean tick from (block.timestamp - secondsAgo) to block.timestamp |
| harmonicMeanLiquidity | uint128 | The harmonic mean liquidity from (block.timestamp - secondsAgo) to block.timestamp |

### getTokenPrice

```solidity
function getTokenPrice(uint128 amount, uint32 secondsAgo) external view returns (uint256 amountOut)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| amount | uint128 | undefined |
| secondsAgo | uint32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| amountOut | uint256 | undefined |

### pool

```solidity
function pool() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### tokenAddress

```solidity
function tokenAddress() external view returns (contract IERC20Extented)
```

Address of the token that we&#39;re vesting




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20Extented | undefined |




## Errors

### T

```solidity
error T()
```







