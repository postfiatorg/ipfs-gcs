import { Router } from 'express'
import { Duplex } from 'stream'

const bufferToStream = (buffer) => {
  const stream = new Duplex()
  stream.push(buffer)
  stream.push(null)
  return stream
}

const upload = (ipfs) => async (req, res) => {
  try {
    const files = req.files
    if (!files || !files.upload) {
      return res.status(400).json({ error: 'No file uploaded' })
    }
    
    const result = await ipfs.files.add({
      path: files.upload.name,
      content: bufferToStream(files.upload.data)
    })
    
    console.log('Upload result:', result)
    res.json(result)
  } catch (error) {
    console.error('Upload error:', error)
    res.status(500).json({ error: error.message })
  }
}

const download = (ipfs) => async (req, res) => {
  try {
    const ipfspath = req.path
    console.log('Downloading:', ipfspath)
    
    ipfs.files.catReadableStream(ipfspath)
      .on('error', (err) => {
        console.error('Download error:', err)
        res.status(404).send(err.message)
      })
      .pipe(res)
  } catch (error) {
    console.error('Download error:', error)
    res.status(500).send(error.message)
  }
}

export default (ipfs, config) => {
  const router = Router()
  
  router.post('/upload', upload(ipfs))
  router.use('/download', download(ipfs))
  router.get('/health', (req, res) => res.json({ status: 'ok' }))
  router.use('/', (req, res) => res.send('IPFS-GCS API'))
  
  return router
}