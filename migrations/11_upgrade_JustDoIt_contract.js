// Running only this migration:
// truffle migrate --compile-all -f 11 --to 11

const { upgradeProxy } = require('@openzeppelin/truffle-upgrades')

const JustDoIt = artifacts.require('JustDoIt')
const JustDoItV2 = artifacts.require('JustDoIt_V2')

module.exports = async function (deployer) {
  const existing = await JustDoIt.deployed()
  const proxy = await upgradeProxy(existing.address, JustDoItV2, {
    deployer,
  })

  console.log('Upgraded', proxy.address)
}
