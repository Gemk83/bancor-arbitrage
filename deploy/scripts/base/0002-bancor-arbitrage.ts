import { deployProxy, InstanceName, setDeploymentMetadata } from '../../../utils/Deploy';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { BancorArbitrage } from '../../../typechain-types';

const func: DeployFunction = async ({ getNamedAccounts }: HardhatRuntimeEnvironment) => {
    const {
        deployer,
        bnt,
        weth,
        protocolWallet,
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

    await deployProxy({
        name: InstanceName.BancorArbitrage,
        from: deployer,
        args: [bnt, weth, protocolWallet, platforms]
    });

    return true;
};

export default setDeploymentMetadata(__filename, func);
