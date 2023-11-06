import { HardhatUserConfig } from 'hardhat/types';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import '@tenderly/hardhat-tenderly';
import '@typechain/hardhat';
import 'hardhat-deploy';
import 'hardhat-dependency-compiler';
import 'dotenv/config';
import 'solidity-coverage';
import 'hardhat-storage-layout';
import '@nomicfoundation/hardhat-chai-matchers';
import { DeploymentNetwork } from './utils/Constants';
import { NamedAccounts } from './data/named-accounts';

interface EnvOptions {
    ETHEREUM_PROVIDER_URL?: string;
    BASE_PROVIDER_URL?: string;
    ARBITRUM_PROVIDER_URL?: string;
    ETHEREUM_SEPOLIA_PROVIDER_URL?: string;
    ETHERSCAN_API_KEY?: string;
    GAS_PRICE?: number | 'auto';
    TENDERLY_FORK_ID?: string;
    TENDERLY_PROJECT?: string;
    TENDERLY_TEST_PROJECT?: string;
    TENDERLY_USERNAME?: string;
    TENDERLY_NETWORK_ID?: string;
    TENDERLY_FORK_NETWORK_NAME?: string;
}

const {
    ETHEREUM_PROVIDER_URL = '',
    BASE_PROVIDER_URL = '',
    ARBITRUM_PROVIDER_URL = '',
    ETHEREUM_SEPOLIA_PROVIDER_URL = '',
    ETHERSCAN_API_KEY,
    GAS_PRICE: gasPrice = 'auto',
    TENDERLY_FORK_ID = '',
    TENDERLY_PROJECT = '',
    TENDERLY_TEST_PROJECT = '',
    TENDERLY_USERNAME = '',
    TENDERLY_NETWORK_ID = '1',
    TENDERLY_FORK_NETWORK_NAME = DeploymentNetwork.Mainnet
}: EnvOptions = process.env as any as EnvOptions;

const config: HardhatUserConfig = {
    networks: {
        [DeploymentNetwork.Hardhat]: {
            accounts: {
                count: 20,
                accountsBalance: '10000000000000000000000000000000000000000000000'
            },
            allowUnlimitedContractSize: true,
            saveDeployments: false,
            live: false
        },
        [DeploymentNetwork.Mainnet]: {
            chainId: 1,
            url: ETHEREUM_PROVIDER_URL,
            gasPrice,
            saveDeployments: true,
            live: true,
            deploy: [`deploy/scripts/${DeploymentNetwork.Mainnet}`]
        },
        [DeploymentNetwork.Base]: {
            chainId: 8453,
            url: BASE_PROVIDER_URL,
            gasPrice,
            saveDeployments: true,
            live: true,
            deploy: [`deploy/scripts/${DeploymentNetwork.Base}`]
        },
        [DeploymentNetwork.Arbitrum]: {
            chainId: 42161,
            url: ARBITRUM_PROVIDER_URL,
            gasPrice,
            saveDeployments: true,
            live: true,
            deploy: [`deploy/scripts/${DeploymentNetwork.Arbitrum}`]
        },
        [DeploymentNetwork.Sepolia]: {
            chainId: 11155111,
            url: ETHEREUM_SEPOLIA_PROVIDER_URL,
            saveDeployments: true,
            live: true,
            deploy: [`deploy/scripts/${DeploymentNetwork.Sepolia}`]
        },
        [DeploymentNetwork.Tenderly]: {
            chainId: parseInt(TENDERLY_NETWORK_ID),
            url: `https://rpc.tenderly.co/fork/${TENDERLY_FORK_ID}`,
            autoImpersonate: true,
            saveDeployments: true,
            live: true,
            deploy: [`deploy/scripts/${TENDERLY_FORK_NETWORK_NAME}`]
        }
    },
    solidity: {
        compilers: [
            {
                version: '0.8.19',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 20000
                    },
                    metadata: {
                        bytecodeHash: 'none'
                    }
                }
            }
        ]
    },
    paths: {
        deploy: ['deploy/scripts']
    },
    tenderly: {
        forkNetwork: TENDERLY_NETWORK_ID,
        project: TENDERLY_PROJECT || TENDERLY_TEST_PROJECT,
        username: TENDERLY_USERNAME
    },
    dependencyCompiler: {
        paths: ['@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol']
    },
    namedAccounts: NamedAccounts,
    external: {
        contracts: [
            {
                artifacts: 'node_modules/@bancor/contracts-solidity/artifacts'
            },
            {
                artifacts: 'node_modules/@bancor/token-governance/artifacts'
            }
        ],
        deployments: {
            [DeploymentNetwork.Mainnet]: [`deployments/${DeploymentNetwork.Mainnet}`],
            [DeploymentNetwork.Base]: [`deployments/${DeploymentNetwork.Base}`],
            [DeploymentNetwork.Arbitrum]: [`deployments/${DeploymentNetwork.Arbitrum}`],
            [DeploymentNetwork.Sepolia]: [`deployments/${DeploymentNetwork.Sepolia}`],
            [DeploymentNetwork.Tenderly]: [`deployments/${DeploymentNetwork.Tenderly}`]
        }
    },
    verify: {
        etherscan: {
            apiKey: ETHERSCAN_API_KEY
        }
    },
    etherscan: {
        apiKey: ETHERSCAN_API_KEY
    }
};

export default config;
