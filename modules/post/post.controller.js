import { PostService } from "./post.service.js";

export class PostController {
  constructor() {
    this.postService = new PostService();
  }

  createPost = async (request, response) => {
    const post = await this.postService.createPost(request.body, request.file);

    return response.json(post);
  };

  updatePost = async (request, response) => {
    const post = await this.postService.updatePost(
      request.params.id,
      request.body,
      request.file
    );

    return response.json(post);
  };

  deletePost = async (request, response) => {
    const result = await this.postService.deletePost(request.params.id);

    return response.json(result);
  };

  findPosts = async (request, response) => {
    const result = await this.postService.findPosts();
    return response.json(result);
  };

  findPost = async (request, response) => {
    const post = await this.postService.findPost(request.params.id);
    response.json(post);
  };
}
