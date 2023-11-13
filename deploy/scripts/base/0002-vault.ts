import { deploy, InstanceName, setDeploymentMetadata } from '../../../utils/Deploy';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

const func: DeployFunction = async ({ getNamedAccounts }: HardhatRuntimeEnvironment) => {
    const { deployer } = await getNamedAccounts();

    // Deploy Vault contract which will serve as the protocol wallet
    await deploy({
        name: InstanceName.Vault,
        from: deployer,
        args: []
    });

    return true;
};

export default setDeploymentMetadata(__filename, func);
