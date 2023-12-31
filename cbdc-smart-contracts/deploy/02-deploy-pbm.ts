import { DeployFunction } from 'hardhat-deploy/dist/types'
import { deploymentConfig } from '../helper-hardhat-config'
import { network } from 'hardhat'
import { getDeployedUnderlyingToken } from '../helpers/network'
import { verifyContract } from '../helpers/verify'

const deployFunction: DeployFunction = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments

  const { PBMDeployer } = await getNamedAccounts()

  const chainId = network.config.chainId

  if (!chainId) {
    throw new Error('Chain ID cannot be retrieved')
  }

  const dsgdContractAddress =
    (await deployments.get('DSGDToken')).address || getDeployedUnderlyingToken(chainId)
  console.log(`DSGD Contract Address: ${dsgdContractAddress}`)
  console.log(`PBM Deployer: ${PBMDeployer}`)

  const pbmContract = await deploy('PBMToken', {
    from: PBMDeployer,
    args: [
      dsgdContractAddress,
      'PBM Sample Token (Non Upgradeable)',
      'XPBM',
      deploymentConfig[chainId].expiryDate,
    ],
    // Defaults to 1 confirmation, assuming that network deployed to is local testnet
    waitConfirmations: deploymentConfig[chainId].waitForConfirmations || 1,
    log: true,
  })

  console.log(pbmContract.address)

  // Verification not needed for chains without access to etherscan (eg; local-nets)
  if (deploymentConfig[chainId].type !== 'local-net') {
    await verifyContract({
      address: pbmContract.address,
      args: [
        dsgdContractAddress,
        'PBM Sample Token (Non Upgradeable)',
        'XPBM',
        deploymentConfig[chainId].expiryDate,
      ],
    })
  }
}

export default deployFunction
deployFunction.tags = ['pbm-standard']
deployFunction.dependencies = ['dsgd']
