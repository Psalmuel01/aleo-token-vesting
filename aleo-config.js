import dotenv from 'dotenv';
dotenv.config();

export default {
  mode: 'execute',
  mainnet: {},
  networks: {
    testnet: {
      endpoint: 'http://127.0.0.1:3030',
      accounts: [
        process.env.PRIVATE_KEY,
      ],
      priorityFee: 0.01,
    },
    mainnet: {
      endpoint: 'https://api.explorer.aleo.org/v1',
      accounts: [process.env.PRIVATE_KEY],
      priorityFee: 0.001
    }
  },
  defaultNetwork: 'testnet'
};
