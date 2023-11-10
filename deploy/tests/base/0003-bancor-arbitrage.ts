import { getNamedAccounts } from 'hardhat';
import { BancorArbitrage, ProxyAdmin, Vault } from '../../../components/Contracts';
import { DeployedContracts, describeDeployment } from '../../../utils/Deploy';
import { toPPM, toWei } from '../../../utils/Types';
import { Roles } from '../../../utils/Roles';
import { expect } from 'chai';

describeDeployment(__filename, () => {
    let proxyAdmin: ProxyAdmin;
    let bancorArbitrage: BancorArbitrage;
    let vault: Vault;

    beforeEach(async () => {
        proxyAdmin = await DeployedContracts.ProxyAdmin.deployed();
        bancorArbitrage = await DeployedContracts.BancorArbitrage.deployed();
        vault = await DeployedContracts.Vault.deployed();
    });

    it('should deploy and configure the vault contract', async () => {
        const { deployer } = await getNamedAccounts();
        expect(await vault.hasRole(Roles.Upgradeable.ROLE_ADMIN, deployer)).to.be.true;
    });

    it('should deploy and configure the bancor arbitrage contract', async () => {
        expect(await proxyAdmin.getProxyAdmin(bancorArbitrage.address)).to.equal(proxyAdmin.address);
        expect(await bancorArbitrage.version()).to.equal(9);

        const arbRewards = await bancorArbitrage.rewards();
        expect(arbRewards.percentagePPM).to.equal(toPPM(10));
        expect(arbRewards.maxAmount).to.equal(toWei(100));
    });
});
