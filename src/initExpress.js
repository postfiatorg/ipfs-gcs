import cors from 'cors'
import express from 'express'
import fileUpload from 'express-fileupload'

export default ({ port }) => {
  const app = express()

  app.use(express.urlencoded({ extended: false }))
  app.use(express.json())
  app.use(cors())
  app.use(fileUpload())

  app.listen(port, (err) => {
    if (err) {
      throw err
    }
    console.log(`Express listening on port ${port}`)
  })

  return app
}