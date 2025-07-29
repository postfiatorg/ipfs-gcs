import initExpress from './initExpress.js'
import initIpfs from './initIpfs.js'
import initGcs from './initGcs.js'
import routers from './routers/index.js'

const Server = (config) => {
  const start = async () => {
    const gcs = await initGcs(config)
    const ipfs = await initIpfs(gcs, config)
    
    const app = initExpress(config)
    const router = routers(ipfs, config)
    
    app.use(router)
    
    return app
  }

  const stop = async () => {
    // Cleanup if needed
  }

  return {
    start,
    stop
  }
}

export default Server