import { DeployedContracts, InstanceName, isMainnet, setDeploymentMetadata, upgradeProxy } from '../../utils/Deploy';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { BancorArbitrage } from '../../typechain-types';

const func: DeployFunction = async ({ getNamedAccounts }: HardhatRuntimeEnvironment) => {
    const {
        deployer,
        bnt,
        weth,
        protocolWallet,
        bancorNetworkV2,
        bancorNetworkV3,
        carbonController,
        balancerVault,
        carbonPOL
    } = await getNamedAccounts();

    const platforms: BancorArbitrage.PlatformsStruct = {
        bancorNetworkV2,
        bancorNetworkV3,
        carbonController,
        balancerVault,
        carbonPOL
    };

    if (isMainnet()) {
        await upgradeProxy(
            {
                name: InstanceName.BancorArbitrage,
                from: deployer,
                args: [bnt, weth, protocolWallet, platforms]
            },
            true
        );
    } else {
        const mockExchanges = await DeployedContracts.MockExchanges.deployed();
        const mockBalancerVault = await DeployedContracts.MockBalancerVault.deployed();

        await upgradeProxy(
            {
                name: InstanceName.BancorArbitrage,
                from: deployer,
                args: [
                    bnt,
                    weth,
                    protocolWallet,
                    {
                        bancorNetworkV2: mockExchanges.address,
                        bancorNetworkV3,
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
