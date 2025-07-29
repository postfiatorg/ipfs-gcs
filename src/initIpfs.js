import { createHelia } from 'helia'
import { createLibp2p } from 'libp2p'
import { noise } from '@chainsafe/libp2p-noise'
import { yamux } from '@chainsafe/libp2p-yamux'
import { identify } from '@libp2p/identify'
import { unixfs } from '@helia/unixfs'
import { MemoryBlockstore } from 'blockstore-core'
import { CID } from 'multiformats/cid'
import { base32 } from 'multiformats/bases/base32'

// Custom GCS-backed blockstore
class GCSBlockstore extends MemoryBlockstore {
  constructor(bucket) {
    super()
    this.bucket = bucket
  }

  async put(key, val) {
    // Store in memory first
    await super.put(key, val)
    
    // Then persist to GCS
    // Convert CID to base32 for filesystem compatibility
    const cid = CID.decode(key.bytes || key)
    const keyStr = cid.toString(base32)
    const file = this.bucket.file(`blocks/${keyStr}`)
    await file.save(val)
  }

  async get(key) {
    try {
      // Try memory first
      return await super.get(key)
    } catch (err) {
      // Fall back to GCS
      const cid = CID.decode(key.bytes || key)
      const keyStr = cid.toString(base32)
      const file = this.bucket.file(`blocks/${keyStr}`)
      const [buffer] = await file.download()
      
      // Cache in memory
      await super.put(key, buffer)
      
      return buffer
    }
  }

  async has(key) {
    // Check memory first
    if (await super.has(key)) {
      return true
    }
    
    // Check GCS
    const cid = CID.decode(key.bytes || key)
    const keyStr = cid.toString(base32)
    const file = this.bucket.file(`blocks/${keyStr}`)
    const [exists] = await file.exists()
    return exists
  }
}

export default async (gcsBucket, config) => {
  console.log('Initializing IPFS with GCS blockstore...')
  
  const blockstore = new GCSBlockstore(gcsBucket)

  const libp2p = await createLibp2p({
    addresses: {
      listen: []  // Don't listen on any addresses
    },
    connectionEncrypters: [noise()],
    streamMuxers: [yamux()],
    services: {
      identify: identify()
    }
  })

  const helia = await createHelia({
    blockstore,
    libp2p
  })

  const fs = unixfs(helia)

  // Create a wrapper to match old IPFS API
  const ipfsWrapper = {
    files: {
      add: async ({ path, content }) => {
        // Handle both Buffer and Stream
        let buffer
        if (Buffer.isBuffer(content)) {
          buffer = content
        } else {
          // Read stream
          const chunks = []
          for await (const chunk of content) {
            chunks.push(chunk)
          }
          buffer = Buffer.concat(chunks)
        }
        
        const cid = await fs.addBytes(buffer)
        return {
          path: path,
          hash: cid.toString(),
          size: buffer.length
        }
      },
      catReadableStream: (ipfspath) => {
        // Remove /ipfs/ prefix if present
        const cidStr = ipfspath.replace(/^\/ipfs\//, '')
        
        // Return an async generator wrapped as a stream-like object
        const generator = fs.cat(cidStr)
        
        // Create a simple event emitter
        const stream = {
          _listeners: {},
          on(event, handler) {
            if (!this._listeners[event]) this._listeners[event] = []
            this._listeners[event].push(handler)
            return this
          },
          emit(event, ...args) {
            if (this._listeners[event]) {
              this._listeners[event].forEach(handler => handler(...args))
            }
          },
          async pipe(destination) {
            try {
              const chunks = []
              for await (const chunk of generator) {
                chunks.push(chunk)
              }
              const buffer = Buffer.concat(chunks)
              destination.write(buffer)
              destination.end()
              this.emit('end')
            } catch (error) {
              console.error('IPFS download error:', error)
              this.emit('error', error)
            }
            return destination
          }
        }
        
        // Start consuming the generator immediately to catch errors
        setImmediate(async () => {
          try {
            // Test that the CID is valid by checking if we can parse it
            const CID = await import('multiformats/cid').then(m => m.CID)
            CID.parse(cidStr)
          } catch (error) {
            stream.emit('error', new Error(`Invalid CID: ${cidStr}`))
          }
        })
        
        return stream
      }
    }
  }

  console.log('IPFS (Helia) node initialized with GCS backend')
  return ipfsWrapper
}