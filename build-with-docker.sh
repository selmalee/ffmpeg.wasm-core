#!/bin/bash

set -euo pipefail

EM_VERSION=2.0.8

docker pull emscripten/emsdk:$EM_VERSION
docker run \
  --rm \
  -v $PWD:/src \
  -v $PWD/wasm/cache:/emsdk_portable/.data/cache/wasm \
  emscripten/emsdk:$EM_VERSION \
  sh -c 'bash ./build1.sh'
