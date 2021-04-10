const JustDoIt = artifacts.require('JustDoIt')

contract('JustDoIt', (accounts) => {
  ;[owner, account1, account2] = accounts

  describe('', () => {
    let instance
    const challengeName = 'challengeName1'
    const amountToSpend = '1'
    const challenge2Name = 'challengeName2'
    const date = Math.floor(new Date().getTime() / 1000)
    const correctDeadLine = date + 60 * 60 * 25
    const passedDeadLine = date + 60 * 60 * 23

    before('', async () => {
      instance = await JustDoIt.deployed()
    })

    it('Adding new challenge', async () => {
      const initialChallenges = await instance.getChallenges({ from: owner })
      assert(
        initialChallenges.length == 0,
        'Initialy, challenges array length should be Zero',
      )

      await instance.addChallengeETH(challengeName, correctDeadLine, {
        from: account1,
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
          from: account1,
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
          from: account1,
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
          from: account1,
          value: web3.utils.toWei(amountToSpend, 'ether'),
        })
        asset(false, 'This should NOT ended successfully')
      } catch (error) {
        const reason = error.reason
        assert(reason == 'Deadline too short', `Error:${reason}`)
      }
    })
  })
})
