import { deploy, DeployedContracts, deployProxy, InstanceName, setDeploymentMetadata } from '../../../utils/Deploy';
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

    // Deploy Vault contract which will serve as the protocol wallet
    await deploy({
        name: InstanceName.Vault,
        from: deployer,
        args: []
    });

    const vault = await DeployedContracts.Vault.deployed();

    // Deploy BancorArbitrage contract
    await deployProxy({
        name: InstanceName.BancorArbitrage,
        from: deployer,
        args: [bnt, weth, vault.address, platforms]
    });

    return true;
};

export default setDeploymentMetadata(__filename, func);
