import { utils } from 'ethers';

const { id } = utils;

export const Roles = {
    Upgradeable: {
        ROLE_ADMIN: id('ROLE_ADMIN')
    },

    Vault: {
        ROLE_ASSET_MANAGER: id('ROLE_ASSET_MANAGER')
    }
};

export const RoleIds = Object.values(Roles)
    .map((contractRoles) => Object.values(contractRoles))
    .flat(1);
