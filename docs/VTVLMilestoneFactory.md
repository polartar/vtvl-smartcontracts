# VTVLMilestoneFactory



> Milestone Vesting Factory contract

Create Milestone contracts



## Methods

### createSimpleMilestones

```solidity
function createSimpleMilestones(contract IERC20 _tokenAddress, uint256 _allocation, uint256[] _allocationPercents, address[] _recipients) external nonpayable
```

Create simple milestones.

*All recipients will have the same milestones.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenAddress | contract IERC20 | Vesting fund token address. |
| _allocation | uint256 | The total allocation amount for the milestones. |
| _allocationPercents | uint256[] | undefined |
| _recipients | address[] | The addresses of the recipients. |

### createVestingMilestone

```solidity
function createVestingMilestone(contract IERC20 _tokenAddress, uint256 _allocation, InputMilestone[] _milestones, address[] _recipients) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenAddress | contract IERC20 | undefined |
| _allocation | uint256 | undefined |
| _milestones | InputMilestone[] | undefined |
| _recipients | address[] | undefined |

### owner

```solidity
function owner() external view returns (address)
```



*Returns the address of the current owner.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### renounceOwnership

```solidity
function renounceOwnership() external nonpayable
```



*Leaves the contract without owner. It will not be possible to call `onlyOwner` functions. Can only be called by the current owner. NOTE: Renouncing ownership will leave the contract without an owner, thereby disabling any functionality that is only available to the owner.*


### transferOwnership

```solidity
function transferOwnership(address newOwner) external nonpayable
```



*Transfers ownership of the contract to a new account (`newOwner`). Can only be called by the current owner.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| newOwner | address | undefined |



## Events

### CreateMilestoneContract

```solidity
event CreateMilestoneContract(address indexed milestoneAddress, address creator)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| milestoneAddress `indexed` | address | undefined |
| creator  | address | undefined |

### OwnershipTransferred

```solidity
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| previousOwner `indexed` | address | undefined |
| newOwner `indexed` | address | undefined |



