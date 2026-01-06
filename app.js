import "dotenv/config";
import express from "express";
import { postRouter } from "./modules/post/post.route.js";
import mongoose from "mongoose";

const app = express();
const port = +(process.env.PORT || 3000);

app.set("trust proxy", 1);
app.use((req, res, next) => {
  if (req.headers["x-forwarded-proto"] === "https") {
    // @ts-ignore
    req.protocol = "https";
  }
  next();
});

app.use(express.json());
app.use("/post", postRouter);

app.get("/health", (request, response) => {
  response.send("OK");
});

app.listen(port, async () => {
  await mongoose
    .connect(
      process.env.MONGO_URI || "mongodb://localhost:27017/posts-project",
      {
        maxConnecting: 3,
        serverSelectionTimeoutMS: 3000,
      }
    )
    .catch((e) => {
      console.error(e);
      throw new Error(`Cannot connect to mongodb server`);
    });
  console.log(`App is listening on ${port} port`);
});
