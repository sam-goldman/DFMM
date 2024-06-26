// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "src/DFMM.sol";
import "solmate/tokens/WETH.sol";
import "solmate/test/utils/mocks/MockERC20.sol";
import "@sphinx-labs/contracts/SphinxPlugin.sol";

contract DeploymentScript is Script, Sphinx {
    function run() public sphinx {
        WETH weth = new WETH();
        DFMM dfmm = new DFMM(address(weth));
        // GeometricMean g3m = new GeometricMean(address(dfmm));
        // LogNormal logNormal = new LogNormal(address(dfmm));

        MockERC20 usdc = new MockERC20("USD Token", "USDC", 6);
        MockERC20 usdt = new MockERC20("Tether USD", "USDT", 6);
        MockERC20 dai = new MockERC20("DAI Stablecoin", "DAI", 18);
        MockERC20 wbtc = new MockERC20("Wrapped Bitcoin", "WBTC", 18);

        console.log("DFMM:", address(dfmm));
        // console.log("GeometricMean:", address(g3m));
        // console.log("LogNormal:", address(logNormal));
        console.log("WETH:", address(weth));
        console.log("USDC:", address(usdc));
        console.log("USDT:", address(usdt));
        console.log("DAI:", address(dai));
        console.log("WBTC:", address(wbtc));
    }

    function configureSphinx() public override {
        sphinxConfig.owners = [YOUR_EOA];
        sphinxConfig.orgId = YOUR_ORG_ID;
        sphinxConfig.projectName = "DFMM";
        sphinxConfig.threshold = 1;
    }
}
