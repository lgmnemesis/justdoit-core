const JDIToken = artifacts.require('JDIToken')
const JustDoIt = artifacts.require('JustDoIt')

module.exports = async (deployer, network, accounts) => {
  const [owner] = accounts
  await deployer.deploy(JDIToken)
  const jdiToken = await JDIToken.deployed()
  await deployer.deploy(JustDoIt, owner, jdiToken.address)
  const justDoIt = await JustDoIt.deployed()
  await jdiToken.setMiner(justDoIt.address)
}
