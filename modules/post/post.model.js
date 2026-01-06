import { model, Schema } from "mongoose";

const PostSchema = new Schema({
  value: String,
  image: String,
});

export const Post = model("Post", PostSchema);
