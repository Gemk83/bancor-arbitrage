import { DeployedContracts, InstanceName, setDeploymentMetadata, upgradeProxy } from '../../../utils/Deploy';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { BancorArbitrage } from '../../../typechain-types';

const func: DeployFunction = async ({ getNamedAccounts }: HardhatRuntimeEnvironment) => {
    const {
        deployer,
        bnt,
        weth,
        bancorNetworkV2,
        bancorNetworkV3,
        uniswapV2Router02,
        sushiSwapRouter,
        uniswapV3Router,
        carbonController,
        balancerVault,
        carbonPOL
    } = await getNamedAccounts();

    const platforms: BancorArbitrage.PlatformsStruct = {
        bancorNetworkV2,
        bancorNetworkV3,
        uniV2Router: uniswapV2Router02,
        uniV3Router: uniswapV3Router,
        sushiswapRouter: sushiSwapRouter,
        carbonController,
        balancerVault,
        carbonPOL
    };

    const vault = await DeployedContracts.Vault.deployed();

    // Deploy BancorArbitrage contract
    await upgradeProxy({
        name: InstanceName.BancorArbitrage,
        from: deployer,
        args: [bnt, weth, vault.address, platforms]
    });

    return true;
};

export default setDeploymentMetadata(__filename, func);
