import { BancorArbitrage, ProxyAdmin, Vault } from '../../../components/Contracts';
import { DeployedContracts, describeDeployment } from '../../../utils/Deploy';
import { toPPM, toWei } from '../../../utils/Types';
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
        expect(await proxyAdmin.getProxyAdmin(vault.address)).to.equal(proxyAdmin.address);
        expect(await vault.version()).to.equal(1);
    });

    it('should deploy and configure the bancor arbitrage contract', async () => {
        expect(await proxyAdmin.getProxyAdmin(bancorArbitrage.address)).to.equal(proxyAdmin.address);
        expect(await bancorArbitrage.version()).to.equal(8);

        const arbRewards = await bancorArbitrage.rewards();
        expect(arbRewards.percentagePPM).to.equal(toPPM(10));
        expect(arbRewards.maxAmount).to.equal(toWei(100));
    });
});
