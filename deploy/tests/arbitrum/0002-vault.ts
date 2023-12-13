import { getNamedAccounts } from 'hardhat';
import { keccak256, toUtf8Bytes } from 'ethers/lib/utils';
import { Vault } from '../../../components/Contracts';
import { DeployedContracts, describeDeployment } from '../../../utils/Deploy';
import { expect } from 'chai';

describeDeployment(__filename, () => {
    let vault: Vault;

    beforeEach(async () => {
        vault = await DeployedContracts.Vault.deployed();
    });

    it('should deploy and configure the vault contract', async () => {
        const adminRole = keccak256(toUtf8Bytes('ROLE_ADMIN'));
        const { deployer } = await getNamedAccounts();
        expect(await vault.getRoleMember(adminRole, 0)).to.equal(deployer);
    });
});
