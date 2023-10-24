// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

/**
 * @notice ICurveRegistry interface
 */
interface ICurveRegistry {
    /**
     * @notice Find an available pool for exchanging two coins
     * @param _from Address of coin to be sent
     * @param _to Address of coin to be received
     * @param i Index value. When multiple pools are available
               this value is used to return the n'th address.
     * @return Pool address
     */
    function find_pool_for_coins(address _from, address _to, uint256 i) external view returns(address);

    /**
     * @notice Convert coin addresses to indices for use with pool methods
     * @param _from Coin address to be used as `i` within a pool
     * @param _to Coin address to be used as `j` within a pool
     * @return int128 `i`, int128 `j`, boolean indicating if `i` and `j` are underlying coins
     */
    function get_coin_indices(address _pool, address _from, address _to) external view returns(int128, int128, bool);
}

/**
 * @notice ICurvePool interface
 */
interface ICurvePool {
    /**
     * @notice Returns the expected trade output (tokens received) given a trade input (tokens sent)
     * @dev Index values can be found via the `coins` public getter method
     * @param i Index value for the coin to send
     * @param j Index valie of the coin to recieve
     * @param dx Amount of `i` being exchanged
     * @return Expected amount of `j` received
     */
    function get_dy(int128 i, int128 j, uint256 dx) external view returns (uint256);

    /**
     * @notice Perform an exchange between two coins
     * @dev Index values can be found via the `coins` public getter method
     * @param i Index value for the coin to send
     * @param j Index valie of the coin to recieve
     * @param dx Amount of `i` being exchanged
     * @param min_dy Minimum amount of `j` to receive
     * @return Actual amount of `j` received
     */
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external payable returns (uint256);
}
