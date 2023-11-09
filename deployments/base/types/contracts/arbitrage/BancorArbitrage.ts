/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
  BigNumber,
  BigNumberish,
  BytesLike,
  CallOverrides,
  ContractTransaction,
  Overrides,
  PayableOverrides,
  PopulatedTransaction,
  Signer,
  utils,
} from "ethers";
import type {
  FunctionFragment,
  Result,
  EventFragment,
} from "@ethersproject/abi";
import type { Listener, Provider } from "@ethersproject/providers";
import type {
  TypedEventFilter,
  TypedEvent,
  TypedListener,
  OnEvent,
} from "../../common";

export declare namespace BancorArbitrage {
  export type PlatformsStruct = {
    bancorNetworkV2: string;
    bancorNetworkV3: string;
    uniV2Router: string;
    uniV3Router: string;
    sushiswapRouter: string;
    carbonController: string;
    balancerVault: string;
    carbonPOL: string;
  };

  export type PlatformsStructOutput = [
    string,
    string,
    string,
    string,
    string,
    string,
    string,
    string
  ] & {
    bancorNetworkV2: string;
    bancorNetworkV3: string;
    uniV2Router: string;
    uniV3Router: string;
    sushiswapRouter: string;
    carbonController: string;
    balancerVault: string;
    carbonPOL: string;
  };

  export type FlashloanStruct = {
    platformId: BigNumberish;
    sourceTokens: string[];
    sourceAmounts: BigNumberish[];
  };

  export type FlashloanStructOutput = [number, string[], BigNumber[]] & {
    platformId: number;
    sourceTokens: string[];
    sourceAmounts: BigNumber[];
  };

  export type TradeRouteStruct = {
    platformId: BigNumberish;
    sourceToken: string;
    targetToken: string;
    sourceAmount: BigNumberish;
    minTargetAmount: BigNumberish;
    deadline: BigNumberish;
    customAddress: string;
    customInt: BigNumberish;
    customData: BytesLike;
  };

  export type TradeRouteStructOutput = [
    number,
    string,
    string,
    BigNumber,
    BigNumber,
    BigNumber,
    string,
    BigNumber,
    string
  ] & {
    platformId: number;
    sourceToken: string;
    targetToken: string;
    sourceAmount: BigNumber;
    minTargetAmount: BigNumber;
    deadline: BigNumber;
    customAddress: string;
    customInt: BigNumber;
    customData: string;
  };

  export type RewardsStruct = {
    percentagePPM: BigNumberish;
    maxAmount: BigNumberish;
  };

  export type RewardsStructOutput = [number, BigNumber] & {
    percentagePPM: number;
    maxAmount: BigNumber;
  };
}

export interface BancorArbitrageInterface extends utils.Interface {
  functions: {
    "DEFAULT_ADMIN_ROLE()": FunctionFragment;
    "PLATFORM_ID_BALANCER()": FunctionFragment;
    "PLATFORM_ID_BANCOR_V2()": FunctionFragment;
    "PLATFORM_ID_BANCOR_V3()": FunctionFragment;
    "PLATFORM_ID_CARBON()": FunctionFragment;
    "PLATFORM_ID_CARBON_POL()": FunctionFragment;
    "PLATFORM_ID_CURVE()": FunctionFragment;
    "PLATFORM_ID_SUSHISWAP()": FunctionFragment;
    "PLATFORM_ID_UNISWAP_V2_FORK()": FunctionFragment;
    "PLATFORM_ID_UNISWAP_V3_FORK()": FunctionFragment;
    "flashloanAndArbV2((uint16,address[],uint256[])[],(uint16,address,address,uint256,uint256,uint256,address,uint256,bytes)[])": FunctionFragment;
    "fundAndArb((uint16,address,address,uint256,uint256,uint256,address,uint256,bytes)[],address,uint256)": FunctionFragment;
    "getRoleAdmin(bytes32)": FunctionFragment;
    "getRoleMember(bytes32,uint256)": FunctionFragment;
    "getRoleMemberCount(bytes32)": FunctionFragment;
    "grantRole(bytes32,address)": FunctionFragment;
    "hasRole(bytes32,address)": FunctionFragment;
    "initialize()": FunctionFragment;
    "onFlashLoan(address,address,uint256,uint256,bytes)": FunctionFragment;
    "postUpgrade(bytes)": FunctionFragment;
    "receiveFlashLoan(address[],uint256[],uint256[],bytes)": FunctionFragment;
    "renounceRole(bytes32,address)": FunctionFragment;
    "revokeRole(bytes32,address)": FunctionFragment;
    "rewards()": FunctionFragment;
    "roleAdmin()": FunctionFragment;
    "setRewards((uint32,uint256))": FunctionFragment;
    "supportsInterface(bytes4)": FunctionFragment;
    "version()": FunctionFragment;
  };

  getFunction(
    nameOrSignatureOrTopic:
      | "DEFAULT_ADMIN_ROLE"
      | "PLATFORM_ID_BALANCER"
      | "PLATFORM_ID_BANCOR_V2"
      | "PLATFORM_ID_BANCOR_V3"
      | "PLATFORM_ID_CARBON"
      | "PLATFORM_ID_CARBON_POL"
      | "PLATFORM_ID_CURVE"
      | "PLATFORM_ID_SUSHISWAP"
      | "PLATFORM_ID_UNISWAP_V2_FORK"
      | "PLATFORM_ID_UNISWAP_V3_FORK"
      | "flashloanAndArbV2"
      | "fundAndArb"
      | "getRoleAdmin"
      | "getRoleMember"
      | "getRoleMemberCount"
      | "grantRole"
      | "hasRole"
      | "initialize"
      | "onFlashLoan"
      | "postUpgrade"
      | "receiveFlashLoan"
      | "renounceRole"
      | "revokeRole"
      | "rewards"
      | "roleAdmin"
      | "setRewards"
      | "supportsInterface"
      | "version"
  ): FunctionFragment;

  encodeFunctionData(
    functionFragment: "DEFAULT_ADMIN_ROLE",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "PLATFORM_ID_BALANCER",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "PLATFORM_ID_BANCOR_V2",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "PLATFORM_ID_BANCOR_V3",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "PLATFORM_ID_CARBON",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "PLATFORM_ID_CARBON_POL",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "PLATFORM_ID_CURVE",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "PLATFORM_ID_SUSHISWAP",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "PLATFORM_ID_UNISWAP_V2_FORK",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "PLATFORM_ID_UNISWAP_V3_FORK",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "flashloanAndArbV2",
    values: [
      BancorArbitrage.FlashloanStruct[],
      BancorArbitrage.TradeRouteStruct[]
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "fundAndArb",
    values: [BancorArbitrage.TradeRouteStruct[], string, BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "getRoleAdmin",
    values: [BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "getRoleMember",
    values: [BytesLike, BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "getRoleMemberCount",
    values: [BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "grantRole",
    values: [BytesLike, string]
  ): string;
  encodeFunctionData(
    functionFragment: "hasRole",
    values: [BytesLike, string]
  ): string;
  encodeFunctionData(
    functionFragment: "initialize",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "onFlashLoan",
    values: [string, string, BigNumberish, BigNumberish, BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "postUpgrade",
    values: [BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "receiveFlashLoan",
    values: [string[], BigNumberish[], BigNumberish[], BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "renounceRole",
    values: [BytesLike, string]
  ): string;
  encodeFunctionData(
    functionFragment: "revokeRole",
    values: [BytesLike, string]
  ): string;
  encodeFunctionData(functionFragment: "rewards", values?: undefined): string;
  encodeFunctionData(functionFragment: "roleAdmin", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "setRewards",
    values: [BancorArbitrage.RewardsStruct]
  ): string;
  encodeFunctionData(
    functionFragment: "supportsInterface",
    values: [BytesLike]
  ): string;
  encodeFunctionData(functionFragment: "version", values?: undefined): string;

  decodeFunctionResult(
    functionFragment: "DEFAULT_ADMIN_ROLE",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "PLATFORM_ID_BALANCER",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "PLATFORM_ID_BANCOR_V2",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "PLATFORM_ID_BANCOR_V3",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "PLATFORM_ID_CARBON",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "PLATFORM_ID_CARBON_POL",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "PLATFORM_ID_CURVE",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "PLATFORM_ID_SUSHISWAP",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "PLATFORM_ID_UNISWAP_V2_FORK",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "PLATFORM_ID_UNISWAP_V3_FORK",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "flashloanAndArbV2",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "fundAndArb", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "getRoleAdmin",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "getRoleMember",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "getRoleMemberCount",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "grantRole", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "hasRole", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "initialize", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "onFlashLoan",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "postUpgrade",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "receiveFlashLoan",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "renounceRole",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "revokeRole", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "rewards", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "roleAdmin", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "setRewards", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "supportsInterface",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "version", data: BytesLike): Result;

  events: {
    "ArbitrageExecuted(address,uint16[],address[],address[],uint256[],uint256[],uint256[])": EventFragment;
    "Initialized(uint8)": EventFragment;
    "RewardsUpdated(uint32,uint32,uint256,uint256)": EventFragment;
    "RoleAdminChanged(bytes32,bytes32,bytes32)": EventFragment;
    "RoleGranted(bytes32,address,address)": EventFragment;
    "RoleRevoked(bytes32,address,address)": EventFragment;
  };

  getEvent(nameOrSignatureOrTopic: "ArbitrageExecuted"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "Initialized"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "RewardsUpdated"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "RoleAdminChanged"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "RoleGranted"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "RoleRevoked"): EventFragment;
}

export interface ArbitrageExecutedEventObject {
  caller: string;
  platformIds: number[];
  tokenPath: string[];
  sourceTokens: string[];
  sourceAmounts: BigNumber[];
  protocolAmounts: BigNumber[];
  rewardAmounts: BigNumber[];
}
export type ArbitrageExecutedEvent = TypedEvent<
  [string, number[], string[], string[], BigNumber[], BigNumber[], BigNumber[]],
  ArbitrageExecutedEventObject
>;

export type ArbitrageExecutedEventFilter =
  TypedEventFilter<ArbitrageExecutedEvent>;

export interface InitializedEventObject {
  version: number;
}
export type InitializedEvent = TypedEvent<[number], InitializedEventObject>;

export type InitializedEventFilter = TypedEventFilter<InitializedEvent>;

export interface RewardsUpdatedEventObject {
  prevPercentagePPM: number;
  newPercentagePPM: number;
  prevMaxAmount: BigNumber;
  newMaxAmount: BigNumber;
}
export type RewardsUpdatedEvent = TypedEvent<
  [number, number, BigNumber, BigNumber],
  RewardsUpdatedEventObject
>;

export type RewardsUpdatedEventFilter = TypedEventFilter<RewardsUpdatedEvent>;

export interface RoleAdminChangedEventObject {
  role: string;
  previousAdminRole: string;
  newAdminRole: string;
}
export type RoleAdminChangedEvent = TypedEvent<
  [string, string, string],
  RoleAdminChangedEventObject
>;

export type RoleAdminChangedEventFilter =
  TypedEventFilter<RoleAdminChangedEvent>;

export interface RoleGrantedEventObject {
  role: string;
  account: string;
  sender: string;
}
export type RoleGrantedEvent = TypedEvent<
  [string, string, string],
  RoleGrantedEventObject
>;

export type RoleGrantedEventFilter = TypedEventFilter<RoleGrantedEvent>;

export interface RoleRevokedEventObject {
  role: string;
  account: string;
  sender: string;
}
export type RoleRevokedEvent = TypedEvent<
  [string, string, string],
  RoleRevokedEventObject
>;

export type RoleRevokedEventFilter = TypedEventFilter<RoleRevokedEvent>;

export interface BancorArbitrage extends BaseContract {
  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: BancorArbitrageInterface;

  queryFilter<TEvent extends TypedEvent>(
    event: TypedEventFilter<TEvent>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TEvent>>;

  listeners<TEvent extends TypedEvent>(
    eventFilter?: TypedEventFilter<TEvent>
  ): Array<TypedListener<TEvent>>;
  listeners(eventName?: string): Array<Listener>;
  removeAllListeners<TEvent extends TypedEvent>(
    eventFilter: TypedEventFilter<TEvent>
  ): this;
  removeAllListeners(eventName?: string): this;
  off: OnEvent<this>;
  on: OnEvent<this>;
  once: OnEvent<this>;
  removeListener: OnEvent<this>;

  functions: {
    DEFAULT_ADMIN_ROLE(overrides?: CallOverrides): Promise<[string]>;

    PLATFORM_ID_BALANCER(overrides?: CallOverrides): Promise<[number]>;

    PLATFORM_ID_BANCOR_V2(overrides?: CallOverrides): Promise<[number]>;

    PLATFORM_ID_BANCOR_V3(overrides?: CallOverrides): Promise<[number]>;

    PLATFORM_ID_CARBON(overrides?: CallOverrides): Promise<[number]>;

    PLATFORM_ID_CARBON_POL(overrides?: CallOverrides): Promise<[number]>;

    PLATFORM_ID_CURVE(overrides?: CallOverrides): Promise<[number]>;

    PLATFORM_ID_SUSHISWAP(overrides?: CallOverrides): Promise<[number]>;

    PLATFORM_ID_UNISWAP_V2_FORK(overrides?: CallOverrides): Promise<[number]>;

    PLATFORM_ID_UNISWAP_V3_FORK(overrides?: CallOverrides): Promise<[number]>;

    flashloanAndArbV2(
      flashloans: BancorArbitrage.FlashloanStruct[],
      routes: BancorArbitrage.TradeRouteStruct[],
      overrides?: Overrides & { from?: string }
    ): Promise<ContractTransaction>;

    fundAndArb(
      routes: BancorArbitrage.TradeRouteStruct[],
      token: string,
      sourceAmount: BigNumberish,
      overrides?: PayableOverrides & { from?: string }
    ): Promise<ContractTransaction>;

    getRoleAdmin(role: BytesLike, overrides?: CallOverrides): Promise<[string]>;

    getRoleMember(
      role: BytesLike,
      index: BigNumberish,
      overrides?: CallOverrides
    ): Promise<[string]>;

    getRoleMemberCount(
      role: BytesLike,
      overrides?: CallOverrides
    ): Promise<[BigNumber]>;

    grantRole(
      role: BytesLike,
      account: string,
      overrides?: Overrides & { from?: string }
    ): Promise<ContractTransaction>;

    hasRole(
      role: BytesLike,
      account: string,
      overrides?: CallOverrides
    ): Promise<[boolean]>;

    initialize(
      overrides?: Overrides & { from?: string }
    ): Promise<ContractTransaction>;

    onFlashLoan(
      caller: string,
      erc20Token: string,
      amount: BigNumberish,
      feeAmount: BigNumberish,
      data: BytesLike,
      overrides?: Overrides & { from?: string }
    ): Promise<ContractTransaction>;

    postUpgrade(
      data: BytesLike,
      overrides?: Overrides & { from?: string }
    ): Promise<ContractTransaction>;

    receiveFlashLoan(
      tokens: string[],
      amounts: BigNumberish[],
      feeAmounts: BigNumberish[],
      userData: BytesLike,
      overrides?: Overrides & { from?: string }
    ): Promise<ContractTransaction>;

    renounceRole(
      role: BytesLike,
      account: string,
      overrides?: Overrides & { from?: string }
    ): Promise<ContractTransaction>;

    revokeRole(
      role: BytesLike,
      account: string,
      overrides?: Overrides & { from?: string }
    ): Promise<ContractTransaction>;

    rewards(
      overrides?: CallOverrides
    ): Promise<[BancorArbitrage.RewardsStructOutput]>;

    roleAdmin(overrides?: CallOverrides): Promise<[string]>;

    setRewards(
      newRewards: BancorArbitrage.RewardsStruct,
      overrides?: Overrides & { from?: string }
    ): Promise<ContractTransaction>;

    supportsInterface(
      interfaceId: BytesLike,
      overrides?: CallOverrides
    ): Promise<[boolean]>;

    version(overrides?: CallOverrides): Promise<[number]>;
  };

  DEFAULT_ADMIN_ROLE(overrides?: CallOverrides): Promise<string>;

  PLATFORM_ID_BALANCER(overrides?: CallOverrides): Promise<number>;

  PLATFORM_ID_BANCOR_V2(overrides?: CallOverrides): Promise<number>;

  PLATFORM_ID_BANCOR_V3(overrides?: CallOverrides): Promise<number>;

  PLATFORM_ID_CARBON(overrides?: CallOverrides): Promise<number>;

  PLATFORM_ID_CARBON_POL(overrides?: CallOverrides): Promise<number>;

  PLATFORM_ID_CURVE(overrides?: CallOverrides): Promise<number>;

  PLATFORM_ID_SUSHISWAP(overrides?: CallOverrides): Promise<number>;

  PLATFORM_ID_UNISWAP_V2_FORK(overrides?: CallOverrides): Promise<number>;

  PLATFORM_ID_UNISWAP_V3_FORK(overrides?: CallOverrides): Promise<number>;

  flashloanAndArbV2(
    flashloans: BancorArbitrage.FlashloanStruct[],
    routes: BancorArbitrage.TradeRouteStruct[],
    overrides?: Overrides & { from?: string }
  ): Promise<ContractTransaction>;

  fundAndArb(
    routes: BancorArbitrage.TradeRouteStruct[],
    token: string,
    sourceAmount: BigNumberish,
    overrides?: PayableOverrides & { from?: string }
  ): Promise<ContractTransaction>;

  getRoleAdmin(role: BytesLike, overrides?: CallOverrides): Promise<string>;

  getRoleMember(
    role: BytesLike,
    index: BigNumberish,
    overrides?: CallOverrides
  ): Promise<string>;

  getRoleMemberCount(
    role: BytesLike,
    overrides?: CallOverrides
  ): Promise<BigNumber>;

  grantRole(
    role: BytesLike,
    account: string,
    overrides?: Overrides & { from?: string }
  ): Promise<ContractTransaction>;

  hasRole(
    role: BytesLike,
    account: string,
    overrides?: CallOverrides
  ): Promise<boolean>;

  initialize(
    overrides?: Overrides & { from?: string }
  ): Promise<ContractTransaction>;

  onFlashLoan(
    caller: string,
    erc20Token: string,
    amount: BigNumberish,
    feeAmount: BigNumberish,
    data: BytesLike,
    overrides?: Overrides & { from?: string }
  ): Promise<ContractTransaction>;

  postUpgrade(
    data: BytesLike,
    overrides?: Overrides & { from?: string }
  ): Promise<ContractTransaction>;

  receiveFlashLoan(
    tokens: string[],
    amounts: BigNumberish[],
    feeAmounts: BigNumberish[],
    userData: BytesLike,
    overrides?: Overrides & { from?: string }
  ): Promise<ContractTransaction>;

  renounceRole(
    role: BytesLike,
    account: string,
    overrides?: Overrides & { from?: string }
  ): Promise<ContractTransaction>;

  revokeRole(
    role: BytesLike,
    account: string,
    overrides?: Overrides & { from?: string }
  ): Promise<ContractTransaction>;

  rewards(
    overrides?: CallOverrides
  ): Promise<BancorArbitrage.RewardsStructOutput>;

  roleAdmin(overrides?: CallOverrides): Promise<string>;

  setRewards(
    newRewards: BancorArbitrage.RewardsStruct,
    overrides?: Overrides & { from?: string }
  ): Promise<ContractTransaction>;

  supportsInterface(
    interfaceId: BytesLike,
    overrides?: CallOverrides
  ): Promise<boolean>;

  version(overrides?: CallOverrides): Promise<number>;

  callStatic: {
    DEFAULT_ADMIN_ROLE(overrides?: CallOverrides): Promise<string>;

    PLATFORM_ID_BALANCER(overrides?: CallOverrides): Promise<number>;

    PLATFORM_ID_BANCOR_V2(overrides?: CallOverrides): Promise<number>;

    PLATFORM_ID_BANCOR_V3(overrides?: CallOverrides): Promise<number>;

    PLATFORM_ID_CARBON(overrides?: CallOverrides): Promise<number>;

    PLATFORM_ID_CARBON_POL(overrides?: CallOverrides): Promise<number>;

    PLATFORM_ID_CURVE(overrides?: CallOverrides): Promise<number>;

    PLATFORM_ID_SUSHISWAP(overrides?: CallOverrides): Promise<number>;

    PLATFORM_ID_UNISWAP_V2_FORK(overrides?: CallOverrides): Promise<number>;

    PLATFORM_ID_UNISWAP_V3_FORK(overrides?: CallOverrides): Promise<number>;

    flashloanAndArbV2(
      flashloans: BancorArbitrage.FlashloanStruct[],
      routes: BancorArbitrage.TradeRouteStruct[],
      overrides?: CallOverrides
    ): Promise<void>;

    fundAndArb(
      routes: BancorArbitrage.TradeRouteStruct[],
      token: string,
      sourceAmount: BigNumberish,
      overrides?: CallOverrides
    ): Promise<void>;

    getRoleAdmin(role: BytesLike, overrides?: CallOverrides): Promise<string>;

    getRoleMember(
      role: BytesLike,
      index: BigNumberish,
      overrides?: CallOverrides
    ): Promise<string>;

    getRoleMemberCount(
      role: BytesLike,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    grantRole(
      role: BytesLike,
      account: string,
      overrides?: CallOverrides
    ): Promise<void>;

    hasRole(
      role: BytesLike,
      account: string,
      overrides?: CallOverrides
    ): Promise<boolean>;

    initialize(overrides?: CallOverrides): Promise<void>;

    onFlashLoan(
      caller: string,
      erc20Token: string,
      amount: BigNumberish,
      feeAmount: BigNumberish,
      data: BytesLike,
      overrides?: CallOverrides
    ): Promise<void>;

    postUpgrade(data: BytesLike, overrides?: CallOverrides): Promise<void>;

    receiveFlashLoan(
      tokens: string[],
      amounts: BigNumberish[],
      feeAmounts: BigNumberish[],
      userData: BytesLike,
      overrides?: CallOverrides
    ): Promise<void>;

    renounceRole(
      role: BytesLike,
      account: string,
      overrides?: CallOverrides
    ): Promise<void>;

    revokeRole(
      role: BytesLike,
      account: string,
      overrides?: CallOverrides
    ): Promise<void>;

    rewards(
      overrides?: CallOverrides
    ): Promise<BancorArbitrage.RewardsStructOutput>;

    roleAdmin(overrides?: CallOverrides): Promise<string>;

    setRewards(
      newRewards: BancorArbitrage.RewardsStruct,
      overrides?: CallOverrides
    ): Promise<void>;

    supportsInterface(
      interfaceId: BytesLike,
      overrides?: CallOverrides
    ): Promise<boolean>;

    version(overrides?: CallOverrides): Promise<number>;
  };

  filters: {
    "ArbitrageExecuted(address,uint16[],address[],address[],uint256[],uint256[],uint256[])"(
      caller?: string | null,
      platformIds?: null,
      tokenPath?: null,
      sourceTokens?: null,
      sourceAmounts?: null,
      protocolAmounts?: null,
      rewardAmounts?: null
    ): ArbitrageExecutedEventFilter;
    ArbitrageExecuted(
      caller?: string | null,
      platformIds?: null,
      tokenPath?: null,
      sourceTokens?: null,
      sourceAmounts?: null,
      protocolAmounts?: null,
      rewardAmounts?: null
    ): ArbitrageExecutedEventFilter;

    "Initialized(uint8)"(version?: null): InitializedEventFilter;
    Initialized(version?: null): InitializedEventFilter;

    "RewardsUpdated(uint32,uint32,uint256,uint256)"(
      prevPercentagePPM?: null,
      newPercentagePPM?: null,
      prevMaxAmount?: null,
      newMaxAmount?: null
    ): RewardsUpdatedEventFilter;
    RewardsUpdated(
      prevPercentagePPM?: null,
      newPercentagePPM?: null,
      prevMaxAmount?: null,
      newMaxAmount?: null
    ): RewardsUpdatedEventFilter;

    "RoleAdminChanged(bytes32,bytes32,bytes32)"(
      role?: BytesLike | null,
      previousAdminRole?: BytesLike | null,
      newAdminRole?: BytesLike | null
    ): RoleAdminChangedEventFilter;
    RoleAdminChanged(
      role?: BytesLike | null,
      previousAdminRole?: BytesLike | null,
      newAdminRole?: BytesLike | null
    ): RoleAdminChangedEventFilter;

    "RoleGranted(bytes32,address,address)"(
      role?: BytesLike | null,
      account?: string | null,
      sender?: string | null
    ): RoleGrantedEventFilter;
    RoleGranted(
      role?: BytesLike | null,
      account?: string | null,
      sender?: string | null
    ): RoleGrantedEventFilter;

    "RoleRevoked(bytes32,address,address)"(
      role?: BytesLike | null,
      account?: string | null,
      sender?: string | null
    ): RoleRevokedEventFilter;
    RoleRevoked(
      role?: BytesLike | null,
      account?: string | null,
      sender?: string | null
    ): RoleRevokedEventFilter;
  };

  estimateGas: {
    DEFAULT_ADMIN_ROLE(overrides?: CallOverrides): Promise<BigNumber>;

    PLATFORM_ID_BALANCER(overrides?: CallOverrides): Promise<BigNumber>;

    PLATFORM_ID_BANCOR_V2(overrides?: CallOverrides): Promise<BigNumber>;

    PLATFORM_ID_BANCOR_V3(overrides?: CallOverrides): Promise<BigNumber>;

    PLATFORM_ID_CARBON(overrides?: CallOverrides): Promise<BigNumber>;

    PLATFORM_ID_CARBON_POL(overrides?: CallOverrides): Promise<BigNumber>;

    PLATFORM_ID_CURVE(overrides?: CallOverrides): Promise<BigNumber>;

    PLATFORM_ID_SUSHISWAP(overrides?: CallOverrides): Promise<BigNumber>;

    PLATFORM_ID_UNISWAP_V2_FORK(overrides?: CallOverrides): Promise<BigNumber>;

    PLATFORM_ID_UNISWAP_V3_FORK(overrides?: CallOverrides): Promise<BigNumber>;

    flashloanAndArbV2(
      flashloans: BancorArbitrage.FlashloanStruct[],
      routes: BancorArbitrage.TradeRouteStruct[],
      overrides?: Overrides & { from?: string }
    ): Promise<BigNumber>;

    fundAndArb(
      routes: BancorArbitrage.TradeRouteStruct[],
      token: string,
      sourceAmount: BigNumberish,
      overrides?: PayableOverrides & { from?: string }
    ): Promise<BigNumber>;

    getRoleAdmin(
      role: BytesLike,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    getRoleMember(
      role: BytesLike,
      index: BigNumberish,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    getRoleMemberCount(
      role: BytesLike,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    grantRole(
      role: BytesLike,
      account: string,
      overrides?: Overrides & { from?: string }
    ): Promise<BigNumber>;

    hasRole(
      role: BytesLike,
      account: string,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    initialize(overrides?: Overrides & { from?: string }): Promise<BigNumber>;

    onFlashLoan(
      caller: string,
      erc20Token: string,
      amount: BigNumberish,
      feeAmount: BigNumberish,
      data: BytesLike,
      overrides?: Overrides & { from?: string }
    ): Promise<BigNumber>;

    postUpgrade(
      data: BytesLike,
      overrides?: Overrides & { from?: string }
    ): Promise<BigNumber>;

    receiveFlashLoan(
      tokens: string[],
      amounts: BigNumberish[],
      feeAmounts: BigNumberish[],
      userData: BytesLike,
      overrides?: Overrides & { from?: string }
    ): Promise<BigNumber>;

    renounceRole(
      role: BytesLike,
      account: string,
      overrides?: Overrides & { from?: string }
    ): Promise<BigNumber>;

    revokeRole(
      role: BytesLike,
      account: string,
      overrides?: Overrides & { from?: string }
    ): Promise<BigNumber>;

    rewards(overrides?: CallOverrides): Promise<BigNumber>;

    roleAdmin(overrides?: CallOverrides): Promise<BigNumber>;

    setRewards(
      newRewards: BancorArbitrage.RewardsStruct,
      overrides?: Overrides & { from?: string }
    ): Promise<BigNumber>;

    supportsInterface(
      interfaceId: BytesLike,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    version(overrides?: CallOverrides): Promise<BigNumber>;
  };

  populateTransaction: {
    DEFAULT_ADMIN_ROLE(
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    PLATFORM_ID_BALANCER(
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    PLATFORM_ID_BANCOR_V2(
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    PLATFORM_ID_BANCOR_V3(
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    PLATFORM_ID_CARBON(
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    PLATFORM_ID_CARBON_POL(
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    PLATFORM_ID_CURVE(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    PLATFORM_ID_SUSHISWAP(
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    PLATFORM_ID_UNISWAP_V2_FORK(
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    PLATFORM_ID_UNISWAP_V3_FORK(
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    flashloanAndArbV2(
      flashloans: BancorArbitrage.FlashloanStruct[],
      routes: BancorArbitrage.TradeRouteStruct[],
      overrides?: Overrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    fundAndArb(
      routes: BancorArbitrage.TradeRouteStruct[],
      token: string,
      sourceAmount: BigNumberish,
      overrides?: PayableOverrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    getRoleAdmin(
      role: BytesLike,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    getRoleMember(
      role: BytesLike,
      index: BigNumberish,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    getRoleMemberCount(
      role: BytesLike,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    grantRole(
      role: BytesLike,
      account: string,
      overrides?: Overrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    hasRole(
      role: BytesLike,
      account: string,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    initialize(
      overrides?: Overrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    onFlashLoan(
      caller: string,
      erc20Token: string,
      amount: BigNumberish,
      feeAmount: BigNumberish,
      data: BytesLike,
      overrides?: Overrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    postUpgrade(
      data: BytesLike,
      overrides?: Overrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    receiveFlashLoan(
      tokens: string[],
      amounts: BigNumberish[],
      feeAmounts: BigNumberish[],
      userData: BytesLike,
      overrides?: Overrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    renounceRole(
      role: BytesLike,
      account: string,
      overrides?: Overrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    revokeRole(
      role: BytesLike,
      account: string,
      overrides?: Overrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    rewards(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    roleAdmin(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    setRewards(
      newRewards: BancorArbitrage.RewardsStruct,
      overrides?: Overrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    supportsInterface(
      interfaceId: BytesLike,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    version(overrides?: CallOverrides): Promise<PopulatedTransaction>;
  };
}