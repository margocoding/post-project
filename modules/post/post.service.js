import { uploadFile } from "../../config/s3.js";
import { Post } from "./post.model.js";

export class PostService {
  constructor() {
    this.postRepository = Post;
  }

  /**
   * @param {Partial<{ value: string; image?: string }>} dto
   * @param {{ buffer: any; originalname: any; }} file
   */
  async createPost(dto, file) {
    let image;

    if (file) {
      image = await uploadFile(file.buffer, file.originalname);
    }

    const post = await this.postRepository.create({ ...dto, image });

    return post;
  }

  async updatePost(id, dto, file) {
    let image;

    if (file) {
      image = await uploadFile(file.buffer, file.originalname);
    }

    const post = await this.postRepository.updateOne(
      { _id: id },
      { ...dto, image }
    );

    return post;
  }

  /**
   * @param {any} id
   */
  async deletePost(id) {
    try {
      await this.postRepository.deleteOne({ _id: id });

      return { success: true };
    } catch (e) {
      console.error(`Cannot delete post with id ${id}`, e);
      return { success: false, message: "Post not found" };
    }
  }

  async findPosts() {
    const posts = await this.postRepository.find();

    return posts;
  }

  /**
   * @param {any} id
   */
  async findPost(id) {
    const post = await this.postRepository.findById(id);
    return post;
  }
}
