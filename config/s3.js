import { PutObjectCommand, S3Client } from "@aws-sdk/client-s3";

const s3 = new S3Client({
  region: process.env.S3_REGION,
  endpoint: process.env.S3_ENDPOINT,
  credentials: {
    accessKeyId: process.env.S3_ACCESS_KEY_ID,
    secretAccessKey: process.env.S3_ACCESS_KEY,
  },
});

export const uploadFile = async (fileBuffer, key) => {
  await s3.send(
    new PutObjectCommand({
      Body: fileBuffer,
      Bucket: process.env.S3_BUCKET,
      Key: key,
      ACL: "public-read",
    })
  );

  return `https://${process.env.S3_BUCKET}.storage.yandexcloud.net/${key}`;
};
