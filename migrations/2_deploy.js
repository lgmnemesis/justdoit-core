const JustDoIt = artifacts.require('JustDoIt')

module.exports = function (deployer, network, accounts) {
  const [owner] = accounts
  deployer.deploy(JustDoIt, owner)
}
