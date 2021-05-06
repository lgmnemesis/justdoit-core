const { time } = require('@openzeppelin/test-helpers')
const JustDoIt = artifacts.require('JustDoIt')
const JDIToken = artifacts.require('JDIToken')

const Result = {
  success: 1,
  failure: 2,
}

contract('JustDoIt', (accounts) => {
  ;[admin, owner, supporter1, supporter2] = accounts

  describe('', () => {
    let instance
    const challengeID = web3.utils.asciiToHex(
      'utajiot9ouyfqpxr3x77ylybvqzimbde',
    ) // bytes32
    const challengeName = 'challenge1'
    const challenge2ID = web3.utils.asciiToHex(
      'zr15p0jbi0o4esc663h7zb4yb1ekuids',
    ) // bytes32
    const challenge2Name = 'challenge2'
    const ChallengeAddedEvent = 'ChallengeAdded'
    const SupportChallengeEvent = 'SupportChallenge'
    const amountToSpend = '1'
    const amountToSupport = '0.2'
    const reportPath = 'this_is_an_ipfs_path_hash'
    let date, correctDeadLine, passedDeadLine
    const onlyTime = false

    before('', async () => {
      date = (await time.latest()).toNumber()
      correctDeadLine = date + 60 * 60 * 25
      passedDeadLine = date + 60 * 60 * 23
      instance = await JustDoIt.deployed()
      jdiToken = await JDIToken.deployed()

      if (onlyTime) {
        console.log('Only increasing blockchain timestamp')
        // const duration = 172800 // 2 days
        const duration = 34 * 60 * 60 // 34 hours
        await time.increase(duration)
      }
    })

    describe('', () => {
      it('', () => {
        if (onlyTime) {
          console.log('Exiting')
          process.exit(0)
        }
      })
    })

    describe('New Challenge Tests', () => {
      it('Adding new challenge', async () => {
        const initialChallenges = await instance.challenges(challengeID, {
          from: owner,
        })
        assert(
          initialChallenges.id ==
            '0x0000000000000000000000000000000000000000000000000000000000000000',
          `Initialy, challenge  ${challengeID} should Not exists`,
        )
        const tx = await instance.addChallengeETH(
          challengeID,
          challengeName,
          correctDeadLine,
          {
            from: owner,
            value: web3.utils.toWei(amountToSpend, 'ether'),
          },
        )

        const log = tx.logs[0]
        assert(
          log.event == ChallengeAddedEvent,
          `Event ${ChallengeAddedEvent} was not emitet`,
        )

        const currentChallenges = await instance.challenges(challengeID, {
          from: owner,
        })

        assert(
          currentChallenges.id == challengeID,
          `After adding a new challenge, ${challengeID} should exists`,
        )
      })

      it('Not allowing adding the same challenge again', async () => {
        try {
          await instance.addChallengeETH(
            challengeID,
            challengeName,
            correctDeadLine,
            {
              from: owner,
              value: web3.utils.toWei(amountToSpend, 'ether'),
            },
          )
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
          await instance.addChallengeETH(
            challenge2ID,
            challenge2Name,
            correctDeadLine,
            {
              from: owner,
            },
          )
          asset(false, 'This should NOT ended successfully')
        } catch (error) {
          const reason = error.reason
          assert(reason == 'No funds supplied', `Error:${reason}`)
        }
      })

      it('Can not add new challenge with a deadline shorter then 24 hours', async () => {
        try {
          await instance.addChallengeETH(
            challenge2ID,
            challenge2Name,
            passedDeadLine,
            {
              from: owner,
              value: web3.utils.toWei(amountToSpend, 'ether'),
            },
          )
          asset(false, 'This should NOT ended successfully')
        } catch (error) {
          const reason = error.reason
          assert(reason == 'Deadline too short', `Error:${reason}`)
        }
      })
    })

    describe('Supporting Challenge Tests', () => {
      it('Support a challenge', async () => {
        const tx = await instance.supportChallenge(challengeID, {
          from: supporter1,
          value: web3.utils.toWei(amountToSupport, 'ether'),
        })
        const challenge = await instance.challenges(challengeID, {
          from: supporter1,
        })

        const log = tx.logs[0]
        assert(
          log.event == SupportChallengeEvent,
          `Event ${SupportChallengeEvent} was not emitet`,
        )

        assert(
          challenge.supporters == 1,
          'Supporter1 was not added to challenge',
        )
      })

      it('Add another supporter to the challenge', async () => {
        await instance.supportChallenge(challengeID, {
          from: supporter2,
          value: web3.utils.toWei(amountToSupport, 'ether'),
        })
        const challenge = await instance.challenges(challengeID, {
          from: supporter2,
        })
        assert(
          challenge.supporters == 2,
          'Supporter2 was not added to challenge',
        )
      })
    })

    describe('Reporting While Challenge In Progress Tests', () => {
      it('Can not report if challenge not over (as a supporter)', async () => {
        try {
          await instance.supporterReportResult(challengeID, Result.success, {
            from: supporter1,
          })
          assert(false, 'Was able to report still')
        } catch (error) {
          assert(error.reason == 'Not in a report time window', error.reason)
        }
      })

      it('Can not report if challenge not over (as a owner)', async () => {
        try {
          await instance.ownerReportResult(
            challengeID,
            Result.success,
            reportPath,
            {
              from: owner,
            },
          )
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

      it('Reporting on Success (as a owner)', async () => {
        await instance.ownerReportResult(
          challengeID,
          Result.success,
          reportPath,
          {
            from: owner,
          },
        )
        const challenge = await instance.challenges(challengeID, {
          from: owner,
        })
        assert(
          challenge.resultFromOwner == 1,
          'Reporting on success.... failed',
        )
      })

      it('Reporting on Failure (as a supporter1)', async () => {
        await instance.supporterReportResult(challengeID, Result.failure, {
          from: supporter1,
        })
        const challenge = await instance.challenges(challengeID, {
          from: supporter1,
        })
        assert(challenge.failures == 1, 'Reporting on failure.... failed')
      })

      it('Reporting on Failure (as a supporter2)', async () => {
        await instance.supporterReportResult(challengeID, Result.failure, {
          from: supporter2,
        })
        const challenge = await instance.challenges(challengeID, {
          from: supporter2,
        })
        assert(challenge.failures == 2, 'Reporting on failure.... failed')
      })
    })

    describe('Challenge Is Over Tests', () => {
      before('', async () => {
        const duration = 604800 // 7 days
        await time.increase(duration)
      })

      it('Can not report if challenge is over (as a supporter)', async () => {
        try {
          await instance.supporterReportResult(challengeID, Result.success, {
            from: supporter1,
          })
          assert(false, 'Was able to report still')
        } catch (error) {
          assert(error.reason == 'Not in a report time window', error.reason)
        }
      })

      it('Can not report if challenge is over (as a owner)', async () => {
        try {
          await instance.ownerReportResult(
            challengeID,
            Result.success,
            reportPath,
            {
              from: owner,
            },
          )
          assert(false, 'Was able to report still')
        } catch (error) {
          assert(error.reason == 'Not in a report time window', error.reason)
        }
      })

      it('Collecting supporter rewards', async () => {
        const ethBalanceBefore = web3.utils.toBN(
          await web3.eth.getBalance(supporter1),
        )
        const jdiBalanceBefore = web3.utils.toBN(
          await jdiToken.balanceOf(supporter1),
        )

        await instance.collectSupporterRewards(challengeID, {
          from: supporter1,
        })

        const ethBalanceAfter = web3.utils.toBN(
          await web3.eth.getBalance(supporter1),
        )
        const jdiBalanceAfter = web3.utils.toBN(
          await jdiToken.balanceOf(supporter1),
        )

        assert(ethBalanceAfter.gt(ethBalanceBefore), 'ETH rewards are missing')
        assert(jdiBalanceAfter.gt(jdiBalanceBefore), 'JDI rewards are missing')
      })

      it('Can not collect supporter rewards again', async () => {
        try {
          await instance.collectSupporterRewards(challengeID, {
            from: supporter1,
          })
          assert(false, 'Was able to collect rewards more then once.')
        } catch (error) {
          assert(error.reason == 'No more rewards', `ERROR:${error.reason}`)
        }
      })

      it('Collecting owner rewards (No rewards in this schenario)', async () => {
        const ethBalanceBefore = web3.utils.toBN(
          await web3.eth.getBalance(owner),
        )
        const jdiBalanceBefore = web3.utils.toBN(
          await jdiToken.balanceOf(owner),
        )

        await instance.collectOwnerRewards(challengeID, {
          from: owner,
        })

        const ethBalanceAfter = web3.utils.toBN(
          await web3.eth.getBalance(owner),
        )
        const jdiBalanceAfter = web3.utils.toBN(await jdiToken.balanceOf(owner))

        assert(
          ethBalanceAfter.lte(ethBalanceBefore),
          'should not get ETH rewards',
        )
        assert(
          jdiBalanceAfter.eq(jdiBalanceBefore),
          'Should not get JDI rewards',
        )
      })

      it('Can not collect owner rewards again', async () => {
        try {
          await instance.collectOwnerRewards(challengeID, {
            from: owner,
          })
          assert(false, 'Was able to collect rewards more then once.')
        } catch (error) {
          assert(error.reason == 'No more rewards', `ERROR:${error.reason}`)
        }
      })

      it('Collecting challenge fees', async () => {
        const ethBalanceBefore = web3.utils.toBN(
          await instance.totalFeesAmount(),
        )
        const jdiBalanceBefore = web3.utils.toBN(
          await jdiToken.balanceOf(instance.address),
        )

        await instance.collectChallengeFees(challengeID, {
          from: admin,
        })

        const ethBalanceAfter = web3.utils.toBN(
          await instance.totalFeesAmount(),
        )
        const jdiBalanceAfter = web3.utils.toBN(
          await jdiToken.balanceOf(instance.address),
        )

        assert(ethBalanceAfter.gt(ethBalanceBefore), 'should get ETH fees')
        assert(jdiBalanceAfter.gt(jdiBalanceBefore), 'Should get JDI fees')
      })

      it('Collecting all fees', async () => {
        const ethDeployerBalanceBefore = web3.utils.toBN(
          await web3.eth.getBalance(admin),
        )
        const jdiDeployerBalanceBefore = web3.utils.toBN(
          await jdiToken.balanceOf(admin),
        )
        const jdiBalanceBefore = web3.utils.toBN(
          await jdiToken.balanceOf(instance.address),
        )

        await instance.collectFees({
          from: admin,
        })

        const ethBalanceAfter = web3.utils.toBN(
          await instance.totalFeesAmount(),
        )
        const ethDeployerBalanceAfter = web3.utils.toBN(
          await web3.eth.getBalance(admin),
        )
        const jdiDeployerBalanceAfter = web3.utils.toBN(
          await jdiToken.balanceOf(admin),
        )
        const jdiBalanceAfter = web3.utils.toBN(
          await jdiToken.balanceOf(instance.address),
        )

        assert(ethBalanceAfter.isZero(), 'should send all ETH as fees')
        assert(
          ethDeployerBalanceAfter.gt(ethDeployerBalanceBefore),
          'Should get more ETH as fees',
        )
        assert(
          jdiDeployerBalanceAfter.gt(jdiDeployerBalanceBefore),
          'Should get JDI as fees',
        )
        assert(
          jdiBalanceBefore.gt(jdiBalanceAfter),
          'Should burn 10% of collected JustDoit JDI',
        )
      })
    })
  })
})
