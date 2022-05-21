import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-vyper';
import 'hardhat-abi-exporter';
import type { HardhatUserConfig } from 'hardhat/config';

const config: HardhatUserConfig = {
	vyper: {
		version: '0.3.3'
	},
	abiExporter: {
		path: './abis',
		runOnCompile: true,
		clear: true,
		flat: true,
		only: ['VotingEscrow', 'SmartWalletWhitelist']
	}
};

export default config;