import { DeployedContracts, InstanceName, isMainnet, setDeploymentMetadata, upgradeProxy } from '../../../utils/Deploy';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { BancorArbitrage } from '../../../typechain-types';

const func: DeployFunction = async ({ getNamedAccounts }: HardhatRuntimeEnvironment) => {
    const {
        deployer,
        bnt,
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

    if (isMainnet()) {
        await upgradeProxy({
            name: InstanceName.BancorArbitrage,
            from: deployer,
            args: [bnt, protocolWallet, platforms]
        });
    } else {
        const mockExchanges = await DeployedContracts.MockExchanges.deployed();
        const mockBalancerVault = await DeployedContracts.MockBalancerVault.deployed();

        await upgradeProxy(
            {
                name: InstanceName.BancorArbitrage,
                from: deployer,
                args: [
                    bnt,
                    protocolWallet,
                    {
                        bancorNetworkV2: mockExchanges.address,
                        bancorNetworkV3,
                        uniV2Router: mockExchanges.address,
                        uniV3Router: mockExchanges.address,
                        sushiswapRouter: mockExchanges.address,
                        carbonController: mockExchanges.address,
                        balancerVault: mockBalancerVault.address
                    }
                ]
            },
            true
        );
    }

    return true;
};

export default setDeploymentMetadata(__filename, func);
