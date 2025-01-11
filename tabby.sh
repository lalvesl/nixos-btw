docker run -it --device nvidia.com/gpu=all \
  -p 8080:8080 -v $HOME/.tabby:/data \
  registry.tabbyml.com/tabbyml/tabby \
  serve --model StarCoder-1B --chat-model Qwen2-1.5B-Instruct --device cuda
