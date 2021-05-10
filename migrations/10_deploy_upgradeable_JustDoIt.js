// Running only this migration:
// truffle migrate --compile-all -f 10 --to 10
// OR BETER YET:
// truffle migrate --reset all -f 1 --to 10

const { deployProxy } = require('@openzeppelin/truffle-upgrades')

const JDIToken = artifacts.require('JDIToken')
const JustDoIt = artifacts.require('JustDoIt')

module.exports = async (deployer, network, accounts) => {
  const [owner] = accounts
  await deployer.deploy(JDIToken)
  const jdiToken = await JDIToken.deployed()

  const proxy = await deployProxy(JustDoIt, [owner, jdiToken.address], {
    deployer,
  })

  await jdiToken.setMiner(proxy.address)
  console.log('Deployed', proxy.address)
}
