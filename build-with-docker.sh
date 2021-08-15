#!/bin/bash
set -euo pipefail

EM_VERSION=2.0.8

docker pull emscripten/emsdk:$EM_VERSION
# -v $PWD/wasm/cache:/emsdk_portable/.data/cache/wasm \
docker run \
  --rm \
  -v $PWD:/src \
  emscripten/emsdk:$EM_VERSION \
  sh -c 'bash ./build1.sh'
