import { OP } from '@mimic-fi/v3-authorizer'
import {
  assertEvent,
  assertIndirectEvent,
  deploy,
  deployProxy,
  fp,
  getSigners,
  ZERO_ADDRESS,
} from '@mimic-fi/v3-helpers'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address'
import { expect } from 'chai'
import { Contract } from 'ethers'

import { buildEmptyTaskConfig, deployEnvironment } from '../../../'
import { itBehavesLikeBaseCurveTask } from './BaseCurveTask.behavior'

describe('Curve2CrvJoiner', () => {
  let task: Contract
  let smartVault: Contract, authorizer: Contract, connector: Contract, owner: SignerWithAddress

  before('setup', async () => {
    // eslint-disable-next-line prettier/prettier
    ([, owner] = await getSigners())
    ;({ authorizer, smartVault } = await deployEnvironment(owner))
  })

  before('deploy connector', async () => {
    connector = await deploy('Curve2CrvConnectorMock')
    const overrideConnectorCheckRole = smartVault.interface.getSighash('overrideConnectorCheck')
    await authorizer.connect(owner).authorize(owner.address, smartVault.address, overrideConnectorCheckRole, [])
    await smartVault.connect(owner).overrideConnectorCheck(connector.address, true)
  })

  beforeEach('deploy task', async () => {
    task = await deployProxy(
      'Curve2CrvJoiner',
      [],
      [
        {
          baseCurveConfig: {
            connector: connector.address,
            maxSlippage: 0,
            customMaxSlippages: [],
            taskConfig: buildEmptyTaskConfig(owner, smartVault),
          },
        },
      ]
    )
  })

  describe('curve', () => {
    beforeEach('set params', async function () {
      this.owner = owner
      this.task = task
      this.authorizer = authorizer
    })

    itBehavesLikeBaseCurveTask()
  })

  describe('call', () => {
    beforeEach('authorize task', async () => {
      const executeRole = smartVault.interface.getSighash('execute')
      const params = [{ op: OP.EQ, value: connector.address }]
      await authorizer.connect(owner).authorize(task.address, smartVault.address, executeRole, params)
    })

    context('when the sender is authorized', () => {
      beforeEach('set sender', async () => {
        const callRole = task.interface.getSighash('call')
        await authorizer.connect(owner).authorize(owner.address, task.address, callRole, [])
        task = task.connect(owner)
      })

      context('when the token is not zero', () => {
        let token: Contract

        beforeEach('set token threshold', async () => {
          token = await deploy('TokenMock', ['TKN'])
        })

        context('when the amount is not zero', () => {
          const amount = fp(10)

          beforeEach('fund smart vault', async () => {
            await token.mint(smartVault.address, amount)
          })

          context('when the threshold has passed', () => {
            const threshold = amount

            beforeEach('set token threshold', async () => {
              const setDefaultTokenThresholdRole = task.interface.getSighash('setDefaultTokenThreshold')
              await authorizer.connect(owner).authorize(owner.address, task.address, setDefaultTokenThresholdRole, [])
              await task.connect(owner).setDefaultTokenThreshold({ token: token.address, min: threshold, max: 0 })
            })

            context('when the slippage is below the limit', () => {
              const slippage = fp(0.01)

              beforeEach('set max slippage', async () => {
                const setDefaultMaxSlippageRole = task.interface.getSighash('setDefaultMaxSlippage')
                await authorizer.connect(owner).authorize(owner.address, task.address, setDefaultMaxSlippageRole, [])
                await task.connect(owner).setDefaultMaxSlippage(slippage)
              })

              it('executes the expected connector', async () => {
                const tx = await task.call(token.address, amount, slippage)

                const connectorData = connector.interface.encodeFunctionData('join', [token.address, amount, slippage])
                await assertIndirectEvent(tx, smartVault.interface, 'Executed', { connector, data: connectorData })

                await assertIndirectEvent(tx, connector.interface, 'LogJoin', {
                  tokenIn: token,
                  amountIn: amount,
                  slippage,
                })
              })

              it('emits an Executed event', async () => {
                const tx = await task.call(token.address, amount, slippage)
                await assertEvent(tx, 'Executed')
              })
            })

            context('when the slippage is above the limit', () => {
              const slippage = fp(0.01)

              it('reverts', async () => {
                await expect(task.call(token.address, amount, slippage)).to.be.revertedWith('TASK_SLIPPAGE_TOO_HIGH')
              })
            })
          })

          context('when the threshold has not passed', () => {
            const threshold = amount.add(1)

            beforeEach('set token threshold', async () => {
              const setDefaultTokenThresholdRole = task.interface.getSighash('setDefaultTokenThreshold')
              await authorizer.connect(owner).authorize(owner.address, task.address, setDefaultTokenThresholdRole, [])
              await task.connect(owner).setDefaultTokenThreshold({ token: token.address, min: threshold, max: 0 })
            })

            it('reverts', async () => {
              await expect(task.call(token.address, amount, 0)).to.be.revertedWith('TASK_TOKEN_THRESHOLD_NOT_MET')
            })
          })
        })

        context('when the amount is zero', () => {
          const amount = 0

          it('reverts', async () => {
            await expect(task.call(token.address, amount, 0)).to.be.revertedWith('TASK_AMOUNT_ZERO')
          })
        })
      })

      context('when the token is zero', () => {
        const token = ZERO_ADDRESS

        it('reverts', async () => {
          await expect(task.call(token, 0, 0)).to.be.revertedWith('TASK_TOKEN_ZERO')
        })
      })
    })

    context('when the sender is not authorized', () => {
      it('reverts', async () => {
        await expect(task.call(ZERO_ADDRESS, 0, 0)).to.be.revertedWith('AUTH_SENDER_NOT_ALLOWED')
      })
    })
  })
})