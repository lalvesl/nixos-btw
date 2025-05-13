docker run -it --device nvidia.com/gpu=all \
  -v ./.tabby_data:/data \
  -e TABBY_WEBSERVER_JWT_TOKEN_SECRET=d3402622-c4b9-4ec6-818e-1e18e222eab8 \
  -p 8080:8080 \
  tabbyml/tabby \
  serve --model StarCoder-1B --chat-model Qwen2-1.5B-Instruct \
  --privileged
