import { getNamedAccounts } from 'hardhat';
import { Vault } from '../../../components/Contracts';
import { DeployedContracts, describeDeployment } from '../../../utils/Deploy';
import { Roles } from '../../../utils/Roles';
import { expect } from 'chai';

describeDeployment(__filename, () => {
    let vault: Vault;

    beforeEach(async () => {
        vault = await DeployedContracts.Vault.deployed();
    });

    it('should deploy and configure the vault contract', async () => {
        const { deployer } = await getNamedAccounts();
        expect(await vault.hasRole(Roles.Upgradeable.ROLE_ADMIN, deployer)).to.be.true;
    });
});
