const TronMulticall = artifacts.require('TronMulticall');
const {
    utils,
    Contract
} = require('ethers');
const TronWeb = require('tronweb');
const {defaultAbiCoder} = require("ethers/lib/utils");
require('dotenv').config();

// Initialize TronWeb with your chosen node and private key
const tronWeb = new TronWeb({
    fullHost: `http://127.0.0.1:${process.env.HOST_PORT}`, // Or your preferred node
    privateKey: process.env.DEFAULT_DOCKER_KEY // Use a private key with necessary permissions
});

contract('TronMulticall', ([deployer]) => {
    let multicall;

    let target;
    let signature;
    let signature2;
    let multicallEthers;
    let call0;
    let call1;

    before('', async () => {
        multicall = await TronMulticall.deployed();

        target = utils.getAddress(`0x${multicall.address.substring(2)}`)
        signature = utils.id('getBlockNumber()').substring(0, 10)
        signature2 = utils.id('getCurrentBlockTimestamp()').substring(0, 10)

        multicallEthers = new Contract(target, TronMulticall.abi)
        call0 = multicallEthers.interface.encodeFunctionData(
            "aggregate",
            [
                [{ target: target, callData: `${signature}`}],
            ]
        )
        call1 = multicallEthers.interface.encodeFunctionData(
            "aggregate",
            [
                [{ target: target, callData: `${signature2}`}],
            ]
        )
    });

    it('#multicall(#aggregate)', async () => {
        const results = await multicall.multicallStatic([call0, call1])
        const result = multicallEthers.interface.decodeFunctionResult("aggregate", results[0][0]);
        console.log(result.blockNumber.toString())
        console.log(result.returnData[0].success)
        console.log(multicallEthers.interface.decodeFunctionResult("getBlockNumber", result.returnData[0].returnData))
    });

    it('should estimate energy', async () => {
        const target = utils.getAddress(`0x${multicall.address.substring(2)}`)
        console.log(target)
        console.log(tronWeb.address.toHex(multicall.address))
        const functionSelector = utils.id('multicall(bytes[])').substring(0, 10);
        console.log(functionSelector)
        const parameter = defaultAbiCoder.encode(["bytes[]"], [[call0, call1]]);
        console.log(parameter)

        console.log('Params:')
        const options = [
            target.trim(),
            functionSelector.trim(),
            {
                feeLimit: 1e9,
                callValue: 0,
                shouldPollResponse: false,
            },
            [call0, call1],
            utils.getAddress(`0x${tronWeb.defaultAddress.hex.substring(2)}`).trim()
        ]
        console.log(
            ...options
        )
        console.log('-------------------')

        const energy = await tronWeb.transactionBuilder.estimateEnergy(...options);
        console.log(`Estimated Energy: ${energy}`);
    });
});
