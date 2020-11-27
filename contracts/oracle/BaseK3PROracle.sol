pragma solidity 0.6.12;

import '../../interfaces/IKeep3rV1Oracle.sol';
import '../../interfaces/IUniswapV2Pair.sol';

contract BaseK3PROracle {
  uint public constant MIN_TWAP_TIME = 15 minutes;
  uint public constant MAX_TWAP_TIME = 60 minutes;

  IKeep3rV1Oracle public k3pr;
  address public factory;
  address public weth;

  constructor(IKeep3rV1Oracle _k3pr) public {
    k3pr = _k3pr;
    factory = _k3pr.factory();
    weth = _k3pr.WETH();
  }

  /// @dev Return the TWAP value price0. Revert if TWAP time range is not within the threshold.
  /// @param pair The pair to query for price0.
  function price0TWAP(address pair) public view returns (uint) {
    uint length = k3pr.observationLength(pair);
    require(length > 0, 'no length-1 observation');
    (uint lastTime, uint lastPx0Cumu, ) = k3pr.observations(pair, length - 1);
    if (lastTime > now - MIN_TWAP_TIME) {
      require(length > 1, 'no length-2 observation');
      (lastTime, lastPx0Cumu, ) = k3pr.observations(pair, length - 2);
    }
    uint elapsedTime = now - lastTime;
    require(elapsedTime >= MIN_TWAP_TIME && elapsedTime <= MAX_TWAP_TIME, 'bad TWAP time');
    uint currPx0Cumu = currentPx0Cumu(pair);
    return (currPx0Cumu - lastPx0Cumu) / (now - lastTime); // overflow is desired
  }

  /// @dev Return the TWAP value price1. Revert if TWAP time range is not within the threshold.
  /// @param pair The pair to query for price1.
  function price1TWAP(address pair) public view returns (uint) {
    uint length = k3pr.observationLength(pair);
    require(length > 0, 'no length-1 observation');
    (uint lastTime, , uint lastPx1Cumu) = k3pr.observations(pair, length - 1);
    if (lastTime > now - MIN_TWAP_TIME) {
      require(length > 1, 'no length-2 observation');
      (lastTime, , lastPx1Cumu) = k3pr.observations(pair, length - 2);
    }
    uint elapsedTime = now - lastTime;
    require(elapsedTime >= MIN_TWAP_TIME && elapsedTime <= MAX_TWAP_TIME, 'bad TWAP time');
    uint currPx1Cumu = currentPx1Cumu(pair);
    return (currPx1Cumu - lastPx1Cumu) / (now - lastTime); // overflow is desired
  }

  /// @dev Return the current price0 cumulative value on uniswap.
  /// @param pair The uniswap pair to query for price0 cumulative value.
  function currentPx0Cumu(address pair) public view returns (uint px0Cumu) {
    uint32 currTime = uint32(now);
    px0Cumu = IUniswapV2Pair(pair).price0CumulativeLast();
    (uint reserve0, uint reserve1, uint32 lastTime) = IUniswapV2Pair(pair).getReserves();
    if (lastTime != now) {
      uint32 timeElapsed = currTime - lastTime; // overflow is desired
      px0Cumu += uint((reserve1 << 112) / reserve0) * timeElapsed; // overflow is desired
    }
  }

  /// @dev Return the current price1 cumulative value on uniswap.
  /// @param pair The uniswap pair to query for price1 cumulative value.
  function currentPx1Cumu(address pair) public view returns (uint px1Cumu) {
    uint32 currTime = uint32(now);
    px1Cumu = IUniswapV2Pair(pair).price1CumulativeLast();
    (uint reserve0, uint reserve1, uint32 lastTime) = IUniswapV2Pair(pair).getReserves();
    if (lastTime != currTime) {
      uint32 timeElapsed = currTime - lastTime; // overflow is desired
      px1Cumu += uint((reserve0 << 112) / reserve1) * timeElapsed; // overflow is desired
    }
  }
}