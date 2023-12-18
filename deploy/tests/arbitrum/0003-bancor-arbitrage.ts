import { BancorArbitrage, ProxyAdmin } from '../../../components/Contracts';
import { DeployedContracts, describeDeployment } from '../../../utils/Deploy';
import { toPPM, toWei } from '../../../utils/Types';
import { expect } from 'chai';

describeDeployment(__filename, () => {
    let proxyAdmin: ProxyAdmin;
    let bancorArbitrage: BancorArbitrage;

    beforeEach(async () => {
        proxyAdmin = await DeployedContracts.ProxyAdmin.deployed();
        bancorArbitrage = await DeployedContracts.BancorArbitrage.deployed();
    });

    it('should deploy and configure the bancor arbitrage contract', async () => {
        expect(await proxyAdmin.getProxyAdmin(bancorArbitrage.address)).to.equal(proxyAdmin.address);
        expect(await bancorArbitrage.version()).to.equal(10);

        const arbRewards = await bancorArbitrage.rewards();
        expect(arbRewards.percentagePPM).to.equal(toPPM(50));
        expect(arbRewards.maxAmount).to.equal(toWei(1000));
    });
});
