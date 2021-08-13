# !/bin/bash -x

set -e -o pipefail

# verify Emscripten version
emcc -v

# configure FFMpeg with Emscripten
# Flags for code optimization, focus on speed instead
# of size
OPTIM_FLAGS=(
  -O3
)
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  # Use closure complier only in linux environment
  OPTIM_FLAGS=(
    "${OPTIM_FLAGS[@]}"
    --closure 1
  )
fi
# Convert array to string
OPTIM_FLAGS="${OPTIM_FLAGS[@]}"
# Root directory
ROOT_DIR=$PWD
# Directory to install headers and libraries
BUILD_DIR=$ROOT_DIR/build
CFLAGS="-I$BUILD_DIR/include $OPTIM_FLAGS"
LDFLAGS="$CFLAGS -L$BUILD_DIR/lib"
CONFIG_ARGS=(
  --target-os=none        # use none to prevent any os specific configurations
  --arch=x86_32           # use x86_32 to achieve minimal architectural optimization
  --enable-cross-compile  # enable cross compile
  --extra-cflags="$CFLAGS"
  --extra-cxxflags="$CFLAGS"
  --extra-ldflags="$LDFLAGS"
  --pkg-config-flags="--static"
  --nm="llvm-nm"
  --ar=emar
  --ranlib=emranlib
  --cc=emcc
  --cxx=em++
  --objcc=emcc
  --dep-cc=emcc
  # 其他禁用项目
  --disable-x86asm        # disable x86 asm
  --disable-inline-asm    # disable inline asm
  --disable-stripping     # disable stripping
  --disable-programs      # disable programs build (incl. ffplay, ffprobe & ffmpeg)
  --disable-ffmpeg
  --disable-ffplay
  --disable-ffprobe
  --disable-doc           # disable doc
  --disable-debug         # disable debug info, required by closure
  --disable-runtime-cpudetect   # disable runtime cpu detect
  --disable-autodetect    # disable external libraries auto detect
  # 组件选项
  # --disable-swresample
  # --disable-postproc
  # --disable-avfilter
  --disable-network
  --disable-w32threads
  --disable-pthreads
  # 个别组件选项
  --disable-devices
  --disable-indevs
  --disable-outdevs
  --disable-everything
  # 解码器
  --enable-decoder=pcm_mulaw
  --enable-decoder=pcm_alaw
  --enable-decoder=adpcm_ima_smjpeg
  --enable-decoder=aac
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
  -I. -I./fftools # Add the specified directory to the search path for include files.
  -Llibavcodec -Llibavdevice -Llibavfilter -Llibavformat -Llibavresample -Llibavutil -Llibpostproc -Llibswscale -Llibswresample  # Add directory to library search path
  -Qunused-arguments # Don't emit warning for unused driver arguments.
  -o wasm/dist/ffmpeg-core.js # Write output to file.
  fftools/ffmpeg_opt.c fftools/ffmpeg_filter.c fftools/ffmpeg_hw.c fftools/cmdutils.c fftools/ffmpeg.c
  -lavdevice -lavfilter -lavformat -lavcodec -lswresample -lswscale -lavutil -lm
  -s USE_SDL=2                    # Specify the SDL version that is being linked against. 2 is a port of the SDL C code on emscripten-ports
  -s MODULARIZE=1                 # use modularized version to be more flexible
  -s EXPORT_NAME="createFFmpegCore"             # assign export name for browser
  # -s PROXY_TO_WORKER=1                         # uses a plain Web Worker to run your main program
  # -s ENVIRONMENT='web,worker'
  -s EXPORTED_FUNCTIONS="[_main]"  # export main and proxy_main funcs,  the main function from fftools/ffmpeg.c
  -s EXTRA_EXPORTED_RUNTIME_METHODS="[FS, cwrap, ccall, setValue, writeAsciiToMemory]"   # export preamble funcs
  -s INITIAL_MEMORY=2146435072      # 2146435072 bytes = 2GB
  -s ALLOW_MEMORY_GROWTH=1
  -s ASSERTIONS=1
  --post-js wasm/post-js.js
  -O3 # optimize code and reduce code size (from 30 MB to 15 MB)
)
emcc "${ARGS[@]}"
