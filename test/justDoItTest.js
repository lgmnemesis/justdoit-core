const { time } = require('@openzeppelin/test-helpers')
const JustDoIt = artifacts.require('JustDoIt')
const JDIToken = artifacts.require('JDIToken')

contract('JustDoIt', (accounts) => {
  ;[admin, owner, supporter1, supporter2] = accounts

  describe('', () => {
    let instance
    const challengeName = 'challengeName1'
    const challenge2Name = 'challengeName2'
    const amountToSpend = '1'
    const amountToSupport = '0.2'
    let date, correctDeadLine, passedDeadLine

    before('', async () => {
      date = (await time.latest()).toNumber()
      correctDeadLine = date + 60 * 60 * 25
      passedDeadLine = date + 60 * 60 * 23
      instance = await JustDoIt.deployed()
      jdiToken = await JDIToken.deployed()
    })

    describe('New Challenge Tests', () => {
      it('Adding new challenge', async () => {
        const initialChallenges = await instance.getChallenges({ from: owner })
        assert(
          initialChallenges.length == 0,
          'Initialy, challenges array length should be Zero',
        )
        await instance.addChallengeETH(challengeName, correctDeadLine, {
          from: owner,
          value: web3.utils.toWei(amountToSpend, 'ether'),
        })
        const currentChallenges = await instance.getChallenges({ from: owner })
        assert(
          currentChallenges.length == 1,
          'After adding a new challenge, challenges array length should be One',
        )
      })

      it('Not allowing adding the same challenge again', async () => {
        try {
          await instance.addChallengeETH(challengeName, correctDeadLine, {
            from: owner,
            value: web3.utils.toWei(amountToSpend, 'ether'),
          })
          asset(false, 'This should NOT ended successfully')
        } catch (error) {
          const reason = error.reason
          assert(reason == 'Challenge already exists', `Error:${reason}`)
        }
      })

      it('Contract got the amountToSpend', async () => {
        const balance = await web3.eth.getBalance(instance.address)
        const amountSent = web3.utils.toWei(amountToSpend, 'ether')
        assert(balance.toString() == amountSent.toString())
      })

      it('Can not add new challenge without funding', async () => {
        try {
          await instance.addChallengeETH(challenge2Name, correctDeadLine, {
            from: owner,
          })
          asset(false, 'This should NOT ended successfully')
        } catch (error) {
          const reason = error.reason
          assert(reason == 'No funds supplied', `Error:${reason}`)
        }
      })

      it('Can not add new challenge with a deadline shorter then 24 hours', async () => {
        try {
          await instance.addChallengeETH(challenge2Name, passedDeadLine, {
            from: owner,
            value: web3.utils.toWei(amountToSpend, 'ether'),
          })
          asset(false, 'This should NOT ended successfully')
        } catch (error) {
          const reason = error.reason
          assert(reason == 'Deadline too short', `Error:${reason}`)
        }
      })
    })

    describe('Supporting Challenge Tests', () => {
      it('Support a challenge', async () => {
        await instance.supportChallenge(challengeName, {
          from: supporter1,
          value: web3.utils.toWei(amountToSupport, 'ether'),
        })
        const challenge = await instance.getChallenge(challengeName, {
          from: supporter1,
        })
        assert(
          challenge.supporters[0] == supporter1,
          'Supporter address was not added to challenge',
        )
      })

      it('Add another supporter to the challenge', async () => {
        await instance.supportChallenge(challengeName, {
          from: supporter2,
          value: web3.utils.toWei(amountToSupport, 'ether'),
        })
        const challenge = await instance.getChallenge(challengeName, {
          from: supporter2,
        })
        assert(
          challenge.supporters[1] == supporter2,
          'Supporter address was not added to challenge',
        )
      })
    })

    describe('Reporting While Challenge In Progress Tests', () => {
      it('Can not report if challenge not over (as a supporter)', async () => {
        try {
          await instance.supporterReportResult(challengeName, 1, {
            from: supporter1,
          })
          assert(false, 'Was able to report still')
        } catch (error) {
          assert(error.reason == 'Not in a report time window', error.reason)
        }
      })

      it('Can not report if challenge not over (as a owner)', async () => {
        try {
          await instance.ownerReportResult(challengeName, 1, {
            from: owner,
          })
          assert(false, 'Was able to report still')
        } catch (error) {
          assert(error.reason == 'Not in a report time window', error.reason)
        }
      })
    })

    describe('Reporting In Correct Time Window Tests', () => {
      before('', async () => {
        const duration = 172800 // 2 days
        await time.increase(duration)
      })

      it('Reporting on Failure (as a supporter1)', async () => {
        await instance.supporterReportResult(challengeName, 2, {
          from: supporter1,
        })
        const challenge = await instance.getChallenge(challengeName, {
          from: supporter1,
        })
        assert(challenge.failures == 1, 'Reporting on failure.... failed')
      })

      it('Reporting on Failure (as a supporter2)', async () => {
        await instance.supporterReportResult(challengeName, 2, {
          from: supporter2,
        })
        const challenge = await instance.getChallenge(challengeName, {
          from: supporter2,
        })
        assert(challenge.failures == 2, 'Reporting on failure.... failed')
      })

      it('Reporting on Success (as a owner)', async () => {
        await instance.ownerReportResult(challengeName, 1, {
          from: owner,
        })
        const challenge = await instance.getChallenge(challengeName, {
          from: owner,
        })
        assert(
          challenge.resultFromOwner == 1,
          'Reporting on success.... failed',
        )
      })
    })

    describe('Challenge Is Over Tests', () => {
      before('', async () => {
        const duration = 604800 // 7 days
        await time.increase(duration)
      })

      it('Can not report if challenge is over (as a supporter)', async () => {
        try {
          await instance.supporterReportResult(challengeName, 1, {
            from: supporter1,
          })
          assert(false, 'Was able to report still')
        } catch (error) {
          assert(error.reason == 'Not in a report time window', error.reason)
        }
      })

      it('Can not report if challenge is over (as a owner)', async () => {
        try {
          await instance.ownerReportResult(challengeName, 1, {
            from: owner,
          })
          assert(false, 'Was able to report still')
        } catch (error) {
          assert(error.reason == 'Not in a report time window', error.reason)
        }
      })

      it('Collecting supporter rewards', async () => {
        const ethBalanceBefore = web3.utils.fromWei(
          await web3.eth.getBalance(supporter1),
        )
        const jdiBalanceBefore = web3.utils.fromWei(
          await jdiToken.balanceOf(supporter1),
        )
        await instance.collectSupporterRewards(challengeName, {
          from: supporter1,
        })
        const ethBalanceAfter = web3.utils.fromWei(
          await web3.eth.getBalance(supporter1),
        )
        const jdiBalanceAfter = web3.utils.fromWei(
          await jdiToken.balanceOf(supporter1),
        )
        const totalWei = ethBalanceAfter - ethBalanceBefore
        const totalJdi = jdiBalanceAfter - jdiBalanceBefore
        assert(totalWei > 0, 'ETH rewards are missing')
        assert(totalJdi > 0, 'JDI rewards are missing')
      })

      it('Can not collect supporter rewards again', async () => {
        try {
          await instance.collectSupporterRewards(challengeName, {
            from: supporter1,
          })
          assert(false, 'Was able to collect rewards more then once.')
        } catch (error) {
          assert(error.reason == 'No more rewards', `ERROR:${error.reason}`)
        }
      })

      it('Collecting owner rewards (No rewards in this schenario)', async () => {
        const ethBalanceBefore = web3.utils.fromWei(
          await web3.eth.getBalance(owner),
        )
        const jdiBalanceBefore = web3.utils.fromWei(
          await jdiToken.balanceOf(owner),
        )
        await instance.collectOwnerRewards(challengeName, {
          from: owner,
        })
        const ethBalanceAfter = web3.utils.fromWei(
          await web3.eth.getBalance(owner),
        )
        const jdiBalanceAfter = web3.utils.fromWei(
          await jdiToken.balanceOf(owner),
        )
        const totalWei = ethBalanceAfter - ethBalanceBefore
        const totalJdi = jdiBalanceAfter - jdiBalanceBefore
        assert(totalWei <= 0, 'should not get ETH rewards')
        assert(totalJdi == 0, 'Should not get JDI rewards')
      })

      it('Can not collect owner rewards again', async () => {
        try {
          await instance.collectOwnerRewards(challengeName, {
            from: owner,
          })
          assert(false, 'Was able to collect rewards more then once.')
        } catch (error) {
          assert(error.reason == 'No more rewards', `ERROR:${error.reason}`)
        }
      })

      it('Collecting challenge fees', async () => {
        const ethBalanceBefore = web3.utils.fromWei(
          await instance.totalFeesAmount(),
        )
        const jdiBalanceBefore = web3.utils.fromWei(
          await jdiToken.balanceOf(instance.address),
        )
        await instance.collectChallengeFees(challengeName, {
          from: admin,
        })
        const ethBalanceAfter = web3.utils.fromWei(
          await instance.totalFeesAmount(),
        )
        const jdiBalanceAfter = web3.utils.fromWei(
          await jdiToken.balanceOf(instance.address),
        )
        const totalWei = ethBalanceAfter - ethBalanceBefore
        const totalJdi = jdiBalanceAfter - jdiBalanceBefore
        assert(totalWei > 0, 'should get ETH fees')
        assert(totalJdi > 0, 'Should get JDI fees')
      })

      it('Collecting all fees', async () => {
        const ethDeployerBalanceBefore = web3.utils.fromWei(
          await web3.eth.getBalance(admin),
        )
        const jdiDeployerBalanceBefore = web3.utils.fromWei(
          await jdiToken.balanceOf(admin),
        )
        const jdiBalanceBefore = web3.utils.fromWei(
          await jdiToken.balanceOf(instance.address),
        )
        await instance.collectFees({
          from: admin,
        })
        const ethBalanceAfter = web3.utils.fromWei(
          await instance.totalFeesAmount(),
        )
        const ethDeployerBalanceAfter = web3.utils.fromWei(
          await web3.eth.getBalance(admin),
        )
        const jdiDeployerBalanceAfter = web3.utils.fromWei(
          await jdiToken.balanceOf(admin),
        )
        const jdiBalanceAfter = web3.utils.fromWei(
          await jdiToken.balanceOf(instance.address),
        )
        const totalEthDeployer =
          ethDeployerBalanceAfter - ethDeployerBalanceBefore
        const totalJdiDeployer =
          jdiDeployerBalanceAfter - jdiDeployerBalanceBefore
        const totalJdi = jdiBalanceAfter - jdiBalanceBefore

        assert(ethBalanceAfter == 0, 'should send all ETH as fees')
        assert(totalEthDeployer > 0, 'Should get more ETH as fees')
        assert(totalJdiDeployer > 0, 'Should get JDI as fees')
        assert(totalJdi < 0, 'Should burn 10% of collected JustDoit JDI')
      })
    })
  })
})
