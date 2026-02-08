docker run -it --device nvidia.com/gpu=all \
  -p 8080:8080 \
  -v ./.tabby_data:/data \
  -e TABBY_WEBSERVER_JWT_TOKEN_SECRET=d3402622-c4b9-4ec6-818e-1e18e222eab8 \
  registry.tabbyml.com/tabbyml/tabby \
  serve --model StarCoder-1B \
  --device cuda # --chat-model Qwen2-1.5B-Instruct \
