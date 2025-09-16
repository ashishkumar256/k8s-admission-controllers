DOCKER_DEFAULT_PLATFORM=linux/$(arch) docker build -t <image:tag> --no-cache --build-arg ARCH=$(arch) .


