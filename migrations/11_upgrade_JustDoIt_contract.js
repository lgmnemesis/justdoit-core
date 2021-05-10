// Running only this migration:
// truffle migrate --compile-all -f 11 --to 11 --skip-dry-run

const { upgradeProxy } = require('@openzeppelin/truffle-upgrades')

const JustDoIt = artifacts.require('JustDoIt')
const upgradeTo = artifacts.require('JustDoIt_V3')

module.exports = async function (deployer) {
  const proxyAddress = (await JustDoIt.deployed()).address
  // proxyAddress = '0xC0A3804BBd9F3658B3088C9A188ED854833Ba6bd' // on kovan

  const proxy = await upgradeProxy(proxyAddress, upgradeTo, {
    deployer,
  })
  console.log('Upgraded', proxy.address)
}
