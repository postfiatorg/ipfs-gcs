import 'dotenv/config'
import config from './config.js'
import Server from './server.js'

const server = Server(config)

server.start()
  .then(() => console.log(`Server started at ${Date.now()}`))
  .catch(err => {
    console.error('Failed to start server:', err.message)
    process.exit(1)
  })