import { Router } from "express";
import { PostController } from "./post.controller.js";
import multer from "multer";

const upload = multer({ storage: multer.memoryStorage() });

export const postRouter = Router();

const postController = new PostController();

postRouter.get("/:id", postController.findPost);
postRouter.get("/", postController.findPosts);
postRouter.post("/", upload.single("file"), postController.createPost);
postRouter.put("/:id", upload.single("file"), postController.updatePost);
postRouter.delete("/:id", postController.deletePost);
