// SPDX-License-Identifier: MIT
pragma solidity =0.8.18;

/// @title TronMulticall - Aggregate results from multiple function calls
/// @author Michael Elliot <mike@makerdao.com>
/// @author Joshua Levine <joshua@makerdao.com>
/// @author Nick Johnson <arachnid@notdot.net>
/// @author Pavlo Bolhar <contact@pironmind.com>
/// @author Andreas Bigger <andreas@nascent.xyz>
/// @author Matt Solomon <matt@mattsolomon.dev>

contract TronMulticall {
    struct Call {
        address target;
        bytes callData;
    }

    struct CallFailure {
        address target;
        bool allowFailure;
        bytes callData;
    }

    struct Call3Value {
        address target;
        bool allowFailure;
        uint256 value;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    // @notice Error thrown when a call reverts
    error MulticallError(string message);
    // @notice Error thrown when a call is made to a non-contract address
    error MulticallNonContractCall(address target);
    // @notice Error thrown when the value passed to aggregateWithValue
    // 		   does not match the sum of the values in the calls
    error MulticallValueMismatch();

    function aggregate(
        Call[] calldata calls
    )
        public
        payable
        returns (uint256 blockNumber, Result[] memory returnData)
    {
        blockNumber = block.number;
        uint256 length = calls.length;
        returnData = new Result[](length);
        Call calldata call;
        for (uint256 i; i < length; ) {
            Result memory result = returnData[i];
            call = calls[i];
            if (!isContract(call.target)) {
                revert MulticallNonContractCall(call.target);
            }
            (result.success, result.returnData) = call.target.call(
                call.callData
            );
            if (!result.success) {
                revert MulticallError(
                    string(abi.encodePacked(result.returnData))
                );
            }
            unchecked {
                ++i;
            }
        }
    }

    function aggregateWithFailure(
        CallFailure[] calldata calls
    )
        public
        payable
        returns (uint256 blockNumber, Result[] memory returnData)
    {
        blockNumber = block.number;
        uint256 length = calls.length;
        returnData = new Result[](length);
        CallFailure calldata calli;
        for (uint256 i; i < length; ) {
            Result memory result = returnData[i];
            calli = calls[i];
            (result.success, result.returnData) = calli.target.call(
                calli.callData
            );
            if (!result.success && !calli.allowFailure) {
                revert MulticallError(
                    string(abi.encodePacked(result.returnData))
                );
            }
            unchecked {
                ++i;
            }
        }
    }

    function aggregateWithValue(
        Call3Value[] calldata calls
    )
        public
        payable
        returns (uint256 blockNumber, Result[] memory returnData)
    {
        blockNumber = block.number;
        uint256 valAccumulator;
        uint256 length = calls.length;
        returnData = new Result[](length);
        Call3Value calldata calli;
        uint256 value;
        for (uint256 i; i < length; ) {
            Result memory result = returnData[i];
            calli = calls[i];
            uint256 val = calli.value;
            // Humanity will be a Type V Kardashev Civilization before this overflows - andreas
            // ~ 10^25 Wei in existence << ~ 10^76 size uint fits in a uint256
            unchecked {
                valAccumulator += val;
            }
            (result.success, result.returnData) = calli.target.call{
                value: value
            }(calli.callData);
            if (!result.success && !calli.allowFailure) {
                revert MulticallError(
                    string(abi.encodePacked(result.returnData))
                );
            }
            unchecked {
                ++i;
            }
        }
        if (value != msg.value) {
            revert MulticallValueMismatch();
        }
    }

    function aggregateStatic(
        Call[] calldata calls
    ) public view returns (uint256 blockNumber, Result[] memory returnData) {
        blockNumber = block.number;
        uint256 length = calls.length;
        returnData = new Result[](length);
        Call calldata call;
        for (uint256 i; i < length; ) {
            Result memory result = returnData[i];
            call = calls[i];
            if (!isContract(call.target)) {
                revert MulticallNonContractCall(call.target);
            }
            (result.success, result.returnData) = call.target.staticcall(
                call.callData
            );
            if (!result.success) {
                revert MulticallError(
                    string(abi.encodePacked(result.returnData))
                );
            }
            unchecked {
                ++i;
            }
        }
    }

    function aggregateStaticWithFailure(
        CallFailure[] calldata calls
    ) public view returns (uint256 blockNumber, Result[] memory returnData) {
        blockNumber = block.number;
        uint256 length = calls.length;
        returnData = new Result[](length);
        CallFailure calldata calli;
        for (uint256 i; i < length; ) {
            Result memory result = returnData[i];
            calli = calls[i];
            (result.success, result.returnData) = calli.target.staticcall(
                calli.callData
            );
            if (!result.success && !calli.allowFailure) {
                revert MulticallError(
                    string(abi.encodePacked(result.returnData))
                );
            }
            unchecked {
                ++i;
            }
        }
    }

    function multicall(bytes[] calldata data) public returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).call(data[i]);

            if (!success) {
                // Next 5 lines from https://ethereum.stackexchange.com/a/83577
                if (result.length < 68) revert();
                assembly {
                    result := add(result, 0x04)
                }
                revert(abi.decode(result, (string)));
            }

            results[i] = result;
        }
    }

    function multicallStatic(bytes[] calldata data) public view returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).staticcall(data[i]);

            if (!success) {
                // Next 5 lines from https://ethereum.stackexchange.com/a/83577
                if (result.length < 68) revert();
                assembly {
                    result := add(result, 0x04)
                }
                revert(abi.decode(result, (string)));
            }

            results[i] = result;
        }
    }

    // Helper functions
    /// @notice Returns the block hash for the given block number
    /// @param blockNumber The block number
    function getBlockHash(
        uint256 blockNumber
    ) public view returns (bytes32 blockHash) {
        blockHash = blockhash(blockNumber);
    }

    /// @notice Returns the block number
    function getBlockNumber() public view returns (uint256 blockNumber) {
        blockNumber = block.number;
    }

    /// @notice Returns the block coinbase
    function getCurrentBlockCoinbase() public view returns (address coinbase) {
        coinbase = block.coinbase;
    }

    /// @notice Returns the block difficulty
    function getCurrentBlockDifficulty()
        public
        view
        returns (uint256 difficulty)
    {
        difficulty = block.prevrandao;
    }

    /// @notice Returns the block timestamp
    function getCurrentBlockTimestamp()
        public
        view
        returns (uint256 timestamp)
    {
        timestamp = block.timestamp;
    }

    /// @notice Returns the (ETH) balance of a given address
    function getEthBalance(address addr) public view returns (uint256 balance) {
        balance = addr.balance;
    }

    /// @notice Returns the block hash of the last block
    function getLastBlockHash() public view returns (bytes32 blockHash) {
        unchecked {
            blockHash = blockhash(block.number - 1);
        }
    }

    /// @notice Gets the base fee of the given block
    /// @notice Can revert if the BASEFEE opcode is not implemented by the given chain
    function getBasefee() public view returns (uint256 basefee) {
        basefee = block.basefee;
    }

    /// @notice Returns tron account check for is contract TRC-44
    function isContract(address addr) public view returns (bool result) {
        result = addr.isContract;
    }

    /// @notice Returns tron TRC10 token account balance
    function getTokenBalance(
        address accountAddress,
        trcToken id
    ) public view returns (uint256 balance) {
        balance = accountAddress.tokenBalance(id);
    }
}
