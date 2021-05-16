// Running only this migration:
// truffle migrate --compile-all -f 11 --to 11 --skip-dry-run

require('dotenv').config({ path: '.env.public' })
const CURRENT_CONTRACT_NAME = process.env['CURRENT_CONTRACT_NAME']
const UPDATED_CONTRACT_NAME = process.env['UPDATED_CONTRACT_NAME']

const { upgradeProxy } = require('@openzeppelin/truffle-upgrades')

const JustDoIt = artifacts.require(CURRENT_CONTRACT_NAME)
const upgradeTo = artifacts.require(UPDATED_CONTRACT_NAME)

module.exports = async function (deployer) {
  const proxyAddress = (await JustDoIt.deployed()).address
  // proxyAddress = '0xC0A3804BBd9F3658B3088C9A188ED854833Ba6bd' // on kovan
  const proxy = await upgradeProxy(proxyAddress, upgradeTo, {
    deployer,
  })
  console.log('Upgraded', proxy.address)
}
