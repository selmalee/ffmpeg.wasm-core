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
  # 去掉不需要的组件
  --disable-avdevice
  --disable-swresample
  --disable-postproc
  --disable-network
  --disable-pthreads
  --disable-w32threads
  --disable-os2threads
  # 解封装，编解码等
  --disable-everything # 减少wasm体积的关键，除了以下的组件外的个别组件都disable
  --enable-filters
  --enable-muxer=image2
  --enable-demuxer=mov # mov,mp4,m4a,3gp,3g2,mj2
  --enable-demuxer=flv
  --enable-demuxer=h264
  --enable-demuxer=asf
  --enable-encoder=mjpeg
  --enable-decoder=hevc
  --enable-decoder=h264
  --enable-decoder=mpeg4
  --enable-protocol=file
)
emconfigure ./configure "${CONFIG_ARGS[@]}"

# build dependencies
emmake make -j4

# build ffmpeg.wasm
mkdir -p wasm/dist
ARGS=(
  -I. -I./fftools # Add directory to include search path
  -Llibavcodec -Llibavdevice -Llibavfilter -Llibavformat -Llibavresample -Llibavutil -Llibpostproc -Llibswscale -Llibswresample # Add directory to library search path
  -Qunused-arguments # Don't emit warning for unused driver arguments.
  -o wasm/dist/ffmpeg-core.js fftools/ffmpeg_opt.c fftools/ffmpeg_filter.c fftools/ffmpeg_hw.c fftools/cmdutils.c fftools/ffmpeg.c # output
  -lavdevice -lavfilter -lavformat -lavcodec -lswresample -lswscale -lavutil -lm # library
  -s USE_SDL=2 # use SDL2
  -s MODULARIZE=1 # use modularized version to be more flexible
  -s EXPORT_NAME="createFFmpegCore" # assign export name for browser
  # -s PROXY_TO_WORKER=1                         # uses a plain Web Worker to run your main program
  # -s ENVIRONMENT='web,worker'
  -s EXPORTED_FUNCTIONS="[_main]" # export main and proxy_main funcs
  -s EXTRA_EXPORTED_RUNTIME_METHODS="[FS, cwrap, ccall, setValue, writeAsciiToMemory]" # export extra runtime methods
  -s INITIAL_MEMORY=33554432 # 33554432 bytes = 32MB
  -s ALLOW_MEMORY_GROWTH=1 # allows the total amount of memory used to change depending on the demands of the application
  --post-js wasm/post-js.js # emits a file after the emitted code. use to expose exit function
  -O3 # optimize code and reduce code size
)
emcc "${ARGS[@]}"
