import { DeploymentNetwork, NetworkId } from '../utils/Constants';

interface EnvOptions {
    TENDERLY_NETWORK_ID?: string;
}

const { 
    TENDERLY_NETWORK_ID = '1',
}: EnvOptions = process.env as any as EnvOptions;

const mainnet = (address: string) => {
    if (TENDERLY_NETWORK_ID === NetworkId.Mainnet) {
        return {
            [DeploymentNetwork.Mainnet]: address,
            [DeploymentNetwork.Tenderly]: address
        }
    } else {
        return {
            [DeploymentNetwork.Mainnet]: address
        }
    }
}

const base = (address: string) => {
    if (TENDERLY_NETWORK_ID === NetworkId.Base) {
        return {
            [DeploymentNetwork.Base]: address,
            [DeploymentNetwork.Tenderly]: address
        }
    }
}

const arbitrum = (address: string) => {
    if (TENDERLY_NETWORK_ID === NetworkId.Arbitrum) {
        return {
            [DeploymentNetwork.Arbitrum]: address,
            [DeploymentNetwork.Tenderly]: address
        }
    } else {
        return {
            [DeploymentNetwork.Arbitrum]: address
        }
    }
}

const sepolia = (address: string) => {
    if (TENDERLY_NETWORK_ID === NetworkId.Sepolia) {
        return {
            [DeploymentNetwork.Sepolia]: address,
            [DeploymentNetwork.Tenderly]: address
        }
    } else {
        return {
            [DeploymentNetwork.Sepolia]: address
        }
    }
}

const TestNamedAccounts = {
    ethWhale: {
        ...mainnet('0xDA9dfA130Df4dE4673b89022EE50ff26f6EA73Cf'),
        ...base('0x4200000000000000000000000000000000000006'),
        ...arbitrum('0xF977814e90dA44bFA03b6295A0616a897441aceC')
    },
    daiWhale: {
        ...mainnet('0xb527a981e1d415AF696936B3174f2d7aC8D11369'),
        ...base('0x73b06D8d18De422E269645eaCe15400DE7462417'),
        ...arbitrum('0xd85E038593d7A098614721EaE955EC2022B9B91B')
    },
    usdcWhale: {
        ...mainnet('0x55FE002aefF02F77364de339a1292923A15844B8'),
        ...base('0x20FE51A9229EEf2cF8Ad9E89d91CAb9312cF3b7A'),
        ...arbitrum('0x489ee077994B6658eAfA855C308275EAd8097C4A')
    },
    wbtcWhale: {
        ...mainnet('0x6daB3bCbFb336b29d06B9C793AEF7eaA57888922'),
        ...arbitrum('0x489ee077994B6658eAfA855C308275EAd8097C4A'),
    },
    linkWhale: {
        ...mainnet('0xc6bed363b30DF7F35b601a5547fE56cd31Ec63DA'),
        ...arbitrum('0x191c10Aa4AF7C30e871E70C95dB0E4eb77237530')
    },
    bntWhale: {
        ...mainnet('0x221A0e3C9AcEa6B3f1CC9DfC7063509c89bE7BC3')
    }
};

const TokenNamedAccounts = {
    dai: {
        ...mainnet('0x6B175474E89094C44Da98b954EedeAC495271d0F'),
        ...base('0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb'),
        ...arbitrum('0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1')
    },
    link: {
        ...mainnet('0x514910771AF9Ca656af840dff83E8264EcF986CA'),
        ...base('0x0000000000000000000000000000000000000000'),
        ...arbitrum('0xf97f4df75117a78c1A5a0DBb814Af92458539FB4')
    },
    weth: {
        ...mainnet('0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'),
        ...base('0x4200000000000000000000000000000000000006'),
        ...arbitrum('0x82aF49447D8a07e3bd95BD0d56f35241523fBab1'),
    },
    usdc: {
        ...mainnet('0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'),
        ...base('0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913'),
        ...arbitrum('0xaf88d065e77c8cC2239327C5EDb3A432268e5831')
    },
    wbtc: {
        ...mainnet('0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599'),
        ...base('0x0000000000000000000000000000000000000000'),
        ...arbitrum('0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f')
    },
    bnt: {
        ...mainnet('0x1F573D6Fb3F13d689FF844B4cE37794d79a7FF1C'),
        ...base('0x0000000000000000000000000000000000000000'),
        ...arbitrum('0x0000000000000000000000000000000000000000')
    }
};

const UniswapNamedAccounts = {
    uniswapV3Router: { 
        ...mainnet('0xE592427A0AEce92De3Edee1F18E0157C05861564'),
        ...base('0x2626664c2603336E57B271c5C0b26F421741e481'),
        ...arbitrum('0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45')
    },
    uniswapV2Router02: { 
        ...mainnet('0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D'),
        ...base('0x0000000000000000000000000000000000000000'),
        ...arbitrum('0x0000000000000000000000000000000000000000')
    }
};

const SushiSwapNamedAccounts = {
    sushiSwapRouter: { 
        ...mainnet('0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F'),
        ...base('0x6BDED42c6DA8FBf0d2bA55B2fa120C5e0c8D7891'),
        ...arbitrum('0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506')
    }
};

const BalancerNamedAccounts = {
    balancerVault: { 
        ...mainnet('0xBA12222222228d8Ba445958a75a0704d566BF2C8'),
        ...base('0xBA12222222228d8Ba445958a75a0704d566BF2C8'),
        ...arbitrum('0xBA12222222228d8Ba445958a75a0704d566BF2C8')
    }
};

const BancorNamedAccounts = {
    bancorNetworkV2: { 
        ...mainnet('0x2F9EC37d6CcFFf1caB21733BdaDEdE11c823cCB0'),
        ...base('0x0000000000000000000000000000000000000000'),
        ...arbitrum('0x0000000000000000000000000000000000000000')
     },
    bancorNetworkV3: { 
        ...mainnet('0xeEF417e1D5CC832e619ae18D2F140De2999dD4fB'),
        ...base('0x0000000000000000000000000000000000000000'),
        ...arbitrum('0x0000000000000000000000000000000000000000')
    },
    carbonController: { 
        ...mainnet('0xC537e898CD774e2dCBa3B14Ea6f34C93d5eA45e1'),
        ...base('0x0000000000000000000000000000000000000000'),
        ...arbitrum('0x0000000000000000000000000000000000000000')
    },
    carbonPOL: { 
        ...mainnet('0xD06146D292F9651C1D7cf54A3162791DFc2bEf46'),
        ...base('0x0000000000000000000000000000000000000000'),
        ...arbitrum('0x0000000000000000000000000000000000000000')
    }
};

export const NamedAccounts = {
    deployer: {
        ...mainnet('ledger://0x5bEBA4D3533a963Dedb270a95ae5f7752fA0Fe22'),
        ...base('ledger://0x5bEBA4D3533a963Dedb270a95ae5f7752fA0Fe22'),
        ...arbitrum('ledger://0x5bEBA4D3533a963Dedb270a95ae5f7752fA0Fe22'),
        ...sepolia('ledger://0x0f28D58c00F9373C00811E9576eE803B4eF98abe')
    },
    protocolWallet: { 
        ...mainnet('0xba7d1581Db6248DC9177466a328BF457703c8f84'),
        ...base('0xba7d1581Db6248DC9177466a328BF457703c8f84'),
        ...arbitrum('0xba7d1581Db6248DC9177466a328BF457703c8f84')
     },

    ...TokenNamedAccounts,
    ...TestNamedAccounts,
    ...UniswapNamedAccounts,
    ...SushiSwapNamedAccounts,
    ...BalancerNamedAccounts,
    ...BancorNamedAccounts
};
