FROM golang:1.15-buster

WORKDIR /go/src/v2ray.com/core

# base packages
RUN apt update && apt install -y --no-install-recommends g++ unzip zip jq git

# clone code
RUN git clone https://github.com/v2fly/v2ray-core.git . \
    && git checkout $(git describe --abbrev=0 --tags) \
    && go get -v -t -d ./...

# install bazel
RUN curl -L -o bazel-installer.sh https://github.com/bazelbuild/bazel/releases/download/3.5.1/bazel-3.5.1-installer-linux-x86_64.sh \
    && chmod +x bazel-installer.sh \
    && ./bazel-installer.sh \
    && rm bazel-installer.sh

# build release
RUN bazel build --action_env=GOPATH=$GOPATH \
    --action_env=PATH=$PATH \
    --action_env=SPWD=$PWD \
    --action_env=GOCACHE=$(go env GOCACHE) \
    --spawn_strategy \
    local //release:all

# fetch origin latest files
RUN mkdir -p origin-releases \
    && cd origin-releases \
    && curl -s https://api.github.com/repos/v2fly/v2ray-core/releases/latest \
    | jq ".assets[] | {browser_download_url, name}" -c \
    | jq ".browser_download_url" -r \
    | wget -i - \
    && rm *.dgst

# ready diff
ENTRYPOINT [ "diff", "./bazel-bin/release/", "./origin-releases"]