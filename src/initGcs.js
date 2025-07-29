import { Storage } from '@google-cloud/storage'

export default ({ bucketName }) => {
  const storage = new Storage()
  return storage.bucket(bucketName)
}