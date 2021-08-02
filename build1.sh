# !/bin/bash -x

set -e -o pipefail

# verify Emscripten version
emcc -v

# configure FFMpeg with Emscripten
CONFIG_ARGS=(
  --target-os=none        # use none to prevent any os specific configurations
  --arch=x86_32           # use x86_32 to achieve minimal architectural optimization
  --enable-cross-compile  # enable cross compile
  --disable-x86asm        # disable x86 asm
  --disable-inline-asm    # disable inline asm
  --disable-stripping     # disable stripping
  --disable-programs      # disable programs build (incl. ffplay, ffprobe & ffmpeg)
  --disable-doc           # disable doc
  --nm="llvm-nm"
  --ar=emar
  --ranlib=emranlib
  --cc=emcc
  --cxx=em++
  --objcc=emcc
  --dep-cc=emcc
  # 解码器
  --enable-decoder=pcm_mulaw
  --enable-decoder=pcm_alaw
  --enable-decoder=adpcm_ima_smjpeg
  --enable-decoder=aac
  --enable-decoder=hevc
  --enable-decoder=h264
  --enable-protocol=file
  # 其他禁用项目
  --disable-devices
  --disable-indevs
  --disable-outdevs
  --disable-network
  --disable-w32threads
  --disable-pthreads
)
emconfigure ./configure "${CONFIG_ARGS[@]}"

# build dependencies
emmake make -j4

# build ffmpeg.wasm
mkdir -p wasm/dist
ARGS=(
  -I. -I./fftools
  -Llibavcodec -Llibavdevice -Llibavfilter -Llibavformat -Llibavresample -Llibavutil -Llibpostproc -Llibswscale -Llibswresample
  -Qunused-arguments
  -o wasm/dist/ffmpeg-core.js fftools/ffmpeg_opt.c fftools/ffmpeg_filter.c fftools/ffmpeg_hw.c fftools/cmdutils.c fftools/ffmpeg.c
  -lavdevice -lavfilter -lavformat -lavcodec -lswresample -lswscale -lavutil -lm
  -s USE_SDL=2                    # use SDL2
  -s MODULARIZE=1                 # use modularized version to be more flexible
  -s EXPORT_NAME="createFFmpegCore"             # assign export name for browser
  -s EXPORTED_FUNCTIONS="[_main]"  # export main and proxy_main funcs
  -s EXTRA_EXPORTED_RUNTIME_METHODS="[FS, cwrap, ccall, setValue, writeAsciiToMemory]"   # export preamble funcs
  -s INITIAL_MEMORY=2146435072      # 2146435072 bytes = 2GB
  -s ALLOW_MEMORY_GROWTH=1
  --post-js wasm/post-js.js
  -O3 # optimize code and reduce code size (from 30 MB to 15 MB)
)
emcc "${ARGS[@]}"
