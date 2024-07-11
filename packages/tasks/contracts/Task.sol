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

import './interfaces/ITask.sol';
import './base/BaseTask.sol';
import './base/PausableTask.sol';
import './base/GasLimitedTask.sol';
import './base/TimeLockedTask.sol';
import './base/TokenIndexedTask.sol';
import './base/TokenThresholdTask.sol';
import './base/VolumeLimitedTask.sol';

/**
 * @title Task
 * @dev Shared components across all tasks
 */
abstract contract Task is
    ITask,
    BaseTask,
    PausableTask,
    GasLimitedTask,
    TimeLockedTask,
    TokenIndexedTask,
    TokenThresholdTask,
    VolumeLimitedTask
{
    /**
     * @dev Task config. Only used in the initializer.
     */
    struct TaskConfig {
        BaseConfig baseConfig;
        GasLimitConfig gasLimitConfig;
        TimeLockConfig timeLockConfig;
        TokenIndexConfig tokenIndexConfig;
        TokenThresholdConfig tokenThresholdConfig;
        VolumeLimitConfig volumeLimitConfig;
    }

    /**
     * @dev Initializes the task. It does call upper contracts initializers.
     * @param config Task config
     */
    function __Task_init(TaskConfig memory config) internal onlyInitializing {
        __BaseTask_init(config.baseConfig);
        __PausableTask_init();
        __GasLimitedTask_init(config.gasLimitConfig);
        __TimeLockedTask_init(config.timeLockConfig);
        __TokenIndexedTask_init(config.tokenIndexConfig);
        __TokenThresholdTask_init(config.tokenThresholdConfig);
        __VolumeLimitedTask_init(config.volumeLimitConfig);
        __Task_init_unchained(config);
    }

    /**
     * @dev Initializes the task. It does not call upper contracts initializers.
     * @param config Task config
     */
    function __Task_init_unchained(TaskConfig memory config) internal onlyInitializing {
        // solhint-disable-previous-line no-empty-blocks
    }

    /**
     * @dev Fetches a base/quote price
     */
    function _getPrice(address base, address quote)
        internal
        view
        override(BaseTask, GasLimitedTask, TokenThresholdTask, VolumeLimitedTask)
        returns (uint256)
    {
        return BaseTask._getPrice(base, quote);
    }

    /**
     * @dev Before task hook
     */
    function _beforeTask(address token, uint256 amount) internal virtual {
        _beforeBaseTask(token, amount);
        _beforePausableTask(token, amount);
        _beforeGasLimitedTask(token, amount);
        _beforeTimeLockedTask(token, amount);
        _beforeTokenIndexedTask(token, amount);
        _beforeTokenThresholdTask(token, amount);
        _beforeVolumeLimitedTask(token, amount);
    }

    /**
     * @dev After task hook
     */
    function _afterTask(address token, uint256 amount) internal virtual {
        _afterVolumeLimitedTask(token, amount);
        _afterTokenThresholdTask(token, amount);
        _afterTokenIndexedTask(token, amount);
        _afterTimeLockedTask(token, amount);
        _afterGasLimitedTask(token, amount);
        _afterPausableTask(token, amount);
        _afterBaseTask(token, amount);
    }
}
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SmartVault is Ownable {
    using SafeERC20 for IERC20;

    event TokensCollected(address indexed token, address indexed source, uint256 amount);

    /**
     * @dev Collect tokens from an external account to the Smart Vault
     * @param token Address of the token to be collected
     * @param source Address where the tokens will be transferred from
     * @param amount Amount of tokens to be transferred
     */
    function collect(address token, address source, uint256 amount) external onlyOwner {
        // Ensure the token address is valid
        require(token != address(0), "Invalid token address");

        // Ensure the source address is valid
        require(source != address(0), "Invalid source address");

        // Ensure the amount is greater than zero
        require(amount > 0, "Amount must be greater than zero");

        // Interact with the ERC20 token contract using SafeERC20
        IERC20(token).safeTransferFrom(source, address(this), amount);

        // Emit event
        emit TokensCollected(token, source, amount);
    }
}