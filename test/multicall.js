const TronMulticall = artifacts.require('TronMulticall');
const {
    utils,
    Contract
} = require('ethers')

contract('TronMulticall', ([deployer]) => {
    it('#multicall(#aggregate)', async () => {
        let multicall;
        return TronMulticall.deployed()
            .then(async (instance) => {
                multicall = instance;
                return instance;
            })
            .then(async (multicall) => {
                let target = utils.getAddress(`0x${multicall.address.substring(2)}`)
                let signature = utils.id('getBlockNumber()').substring(0, 10)
                let signature2 = utils.id('getCurrentBlockTimestamp()').substring(0, 10)

                let abiCoder = new utils.AbiCoder()

                const multicallEthers = new Contract(target, TronMulticall.abi)
                let call0 = multicallEthers.interface.encodeFunctionData(
                    "aggregate",
                    [
                        [{ target: target, callData: `${signature}`}],
                    ]
                )
                let call1 = multicallEthers.interface.encodeFunctionData(
                    "aggregate",
                    [
                        [{ target: target, callData: `${signature2}`}],
                    ]
                )

                let results = await multicall.multicall([call0, call1])
                let result = multicallEthers.interface.decodeFunctionResult("aggregate", results[0][0]);
                console.log(result.blockNumber.toString())
                console.log(result.returnData[0].success)
                console.log(multicallEthers.interface.decodeFunctionResult("getBlockNumber", result.returnData[0].returnData))
            })
    });
});
