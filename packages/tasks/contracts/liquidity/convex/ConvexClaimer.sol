// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.0;

import '@mimic-fi/v3-connectors/contracts/liquidity/convex/ConvexConnector.sol';

import './BaseConvexTask.sol';
import '../../interfaces/liquidity/convex/IConvexClaimer.sol';

/**
 * @title Convex claimer task
 */
contract ConvexClaimer is IConvexClaimer, BaseConvexTask {
    // Execution type for relayers
    bytes32 public constant override EXECUTION_TYPE = keccak256('CONVEX_CLAIMER');

    /**
     * @dev Convex claimer task config. Only used in the initializer.
     */
    struct ConvexConfig {
        BaseConvexConfig baseConvexConfig;
    }

    /**
     * @dev Initializes a Convex claimer task
     */
    function initialize(ConvexConfig memory config) external initializer {
        _initialize(config.baseConvexConfig);
    }

    /**
     * @dev Tells the address from where the token amounts to execute this task are fetched
     */
    function getTokensSource() external view virtual override(IBaseTask, BaseTask) returns (address) {
        return address(ConvexConnector(connector).booster());
    }

    /**
     * @dev Tells the amount a task should use for a token, in this case always zero since it is not possible to
     * compute on-chain how many tokens are available to be claimed.
     */
    function getTaskAmount(address) external pure virtual override(IBaseTask, BaseTask) returns (uint256) {
        return 0;
    }

    /**
     * @dev Executes the Convex claimer task
     * @param token Address of the Convex pool token to claim rewards for
     * @param amount Must be zero, it is not possible to claim a specific number of tokens
     */
    function call(address token, uint256 amount)
        external
        override
        authP(authParams(token))
        baseTaskCall(token, amount)
    {
        bytes memory connectorData = abi.encodeWithSelector(ConvexConnector.claim.selector, token);
        bytes memory result = ISmartVault(smartVault).execute(connector, connectorData);
        (address[] memory tokens, uint256[] memory amounts) = abi.decode(result, (address[], uint256[]));

        require(tokens.length == amounts.length, 'CLAIMER_INVALID_RESULT_LEN');
        for (uint256 i = 0; i < tokens.length; i++) _increaseBalanceConnector(tokens[i], amounts[i]);
    }

    /**
     * @dev Hook to be called before the Convex task call starts. Adds a validation to make sure the amount is zero.
     */
    function _beforeTask(address token, uint256 amount) internal virtual override {
        super._beforeTask(token, amount);
        require(amount == 0, 'TASK_AMOUNT_NOT_ZERO');
    }
}
