// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { SetUp, IDFMM2, DFMM2 } from "test/utils/SetUp.sol";
import { MockStrategy } from "test/utils/MockStrategy.sol";

contract DFMMSetUp is SetUp {
    MockStrategy strategy;

    uint256 public POOL_ID;

    function setUp() public override {
        SetUp.setUp();
        strategy = new MockStrategy(address(dfmm));
    }

    function getDefaultPoolParams(bytes memory data)
        internal
        view
        returns (IDFMM2.InitParams memory)
    {
        address[] memory tokens = new address[](2);
        tokens[0] = address(tokenX);
        tokens[1] = address(tokenY);

        return IDFMM2.InitParams({
            name: "",
            symbol: "",
            strategy: address(strategy),
            tokens: tokens,
            data: data
        });
    }

    modifier initPool() {
        uint256[] memory reserves = new uint256[](2);
        reserves[0] = 1 ether;
        reserves[1] = 1 ether;

        bytes memory params =
            abi.encode(true, int256(1 ether), reserves, uint256(1 ether));
        (POOL_ID,,) = dfmm.init(getDefaultPoolParams(params));
        _;
    }
}
