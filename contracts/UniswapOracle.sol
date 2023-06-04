//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.14;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";

contract UniswapOracle {
    /**
    @notice Address of the token that we're vesting
     */
    IERC20 public immutable tokenAddress;

    // USDC contract address
    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // UniswapV3 Factory address
    address public constant UNISWAP_V3_FACTORY_ADDRESS =
        0x1F98431c8aD98523631AE4a59f267346ea31F984;

    // pool address for USDC vs Token using Uniswap factory contract
    address public immutable pool;
    bytes4 private constant FUNC_SELECTOR =
        bytes4(keccak256("getPool(address,address,uint256)"));

    constructor(IERC20 _tokenAddress) {
        require(address(_tokenAddress) != address(0), "INVALID_ADDRESS");
        tokenAddress = _tokenAddress;
        pool = IUniswapV3Factory(UNISWAP_V3_FACTORY_ADDRESS).getPool(
            address(tokenAddress),
            USDC_ADDRESS,
            500
        );
    }

    // get the price of the token that will be calculated by 100 times.
    function getPrice(
        uint128 amount,
        uint32 secondsAgo
    ) public view returns (uint amountOut) {
        (int24 tick, ) = consult(secondsAgo);
        amountOut = OracleLibrary.getQuoteAtTick(
            tick,
            amount,
            address(tokenAddress),
            USDC_ADDRESS
        );
        // uint256 amountOut = getQuoteAtTick(
        //     tick,
        //     amount,
        //     tokenAddress,
        //     USDC_ADDRESS
        // );

        // calculate the price with 100 times
        return (amountOut * 100) / amount;
    }

    /// @notice Calculates time-weighted means of tick and liquidity for a given Uniswap V3 pool
    /// @param secondsAgo Number of seconds in the past from which to calculate the time-weighted means
    /// @return arithmeticMeanTick The arithmetic mean tick from (block.timestamp - secondsAgo) to block.timestamp
    /// @return harmonicMeanLiquidity The harmonic mean liquidity from (block.timestamp - secondsAgo) to block.timestamp
    function consult(
        uint32 secondsAgo
    )
        private
        view
        returns (int24 arithmeticMeanTick, uint128 harmonicMeanLiquidity)
    {
        require(secondsAgo != 0, "BP");

        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = secondsAgo;
        secondsAgos[1] = 0;

        (
            int56[] memory tickCumulatives,
            uint160[] memory secondsPerLiquidityCumulativeX128s
        ) = IUniswapV3Pool(pool).observe(secondsAgos);

        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
        uint160 secondsPerLiquidityCumulativesDelta = secondsPerLiquidityCumulativeX128s[
                1
            ] - secondsPerLiquidityCumulativeX128s[0];

        arithmeticMeanTick = int24(
            tickCumulativesDelta / int56(uint56(secondsAgo))
        );
        // Always round to negative infinity
        if (
            tickCumulativesDelta < 0 &&
            (tickCumulativesDelta % int56(uint56(secondsAgo)) != 0)
        ) arithmeticMeanTick--;

        // We are multiplying here instead of shifting to ensure that harmonicMeanLiquidity doesn't overflow uint128
        uint192 secondsAgoX160 = uint192(secondsAgo) * type(uint160).max;
        harmonicMeanLiquidity = uint128(
            secondsAgoX160 /
                (uint192(secondsPerLiquidityCumulativesDelta) << 32)
        );
    }
}
