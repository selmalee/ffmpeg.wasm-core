# !/bin/bash -x

# verify Emscripten version
emcc -v

# configure FFMpeg with Emscripten
CFLAGS="-s USE_PTHREADS"
LDFLAGS="$CFLAGS -s INITIAL_MEMORY=33554432" # 33554432 bytes = 32 MB
CONFIG_ARGS=(
  --target-os=none        # use none to prevent any os specific configurations
  --arch=x86_32           # use x86_32 to achieve minimal architectural optimization
  --enable-cross-compile  # enable cross compile
  --disable-x86asm        # disable x86 asm
  --disable-inline-asm    # disable inline asm
  --disable-stripping     # disable stripping
  --disable-programs      # disable programs build (incl. ffplay, ffprobe & ffmpeg)
  --disable-doc           # disable doc
  # --extra-cflags="$CFLAGS"
  # --extra-cxxflags="$CFLAGS"
  # --extra-ldflags="$LDFLAGS"
  --nm="llvm-nm"
  --ar=emar
  --ranlib=emranlib
  --cc=emcc
  --cxx=em++
  --objcc=emcc
  --dep-cc=emcc
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
  -s EXIT_RUNTIME=1                             # exit runtime after execution
  -s MODULARIZE=1                               # use modularized version to be more flexible
  -s EXPORT_NAME="createFFmpegCore"             # assign export name for browser
  -s EXPORTED_FUNCTIONS="[_main]"  # export main and proxy_main funcs
  -s EXTRA_EXPORTED_RUNTIME_METHODS="[FS, cwrap, ccall, setValue, writeAsciiToMemory]"   # export preamble funcs
  -s INITIAL_MEMORY=33554432      # 33554432 bytes = 32 MB
  --post-js wasm/post-js.js
  -O3 # optimize code and reduce code size (from 30 MB to 15 MB)
)
emcc "${ARGS[@]}"


# set -e -o pipefail

# BUILD_DIR=$PWD/build

# # build_x264() {
# #   cd third_party/x264
# #   emconfigure ./configure \
# #     --prefix=$BUILD_DIR \
# #     --enable-static \
# #     --disable-cli \
# #     --disable-asm
# #   emmake make install-lib-static
# #   cd -
# # }

# FFMPEG_CONFIG_FLAGS_BASE=(
#   --arch=x86_64
#   --enable-gpl
#   --enable-cross-compile 
#   --disable-asm
#   --disable-stripping 
#   --disable-programs 
#   --disable-doc 
#   --disable-debug 
#   --disable-runtime-cpudetect 
#   --disable-autodetect
#   --extra-cflags="-I$BUILD_DIR/include"
#   --extra-cxxflags="-I$BUILD_DIR/include"
#   --extra-ldflags="-L$BUILD_DIR/lib"
#   --pkg-config-flags="--static"
#   --nm="llvm-nm"
#   --ar=emar
#   --ranlib=emranlib
#   --cc=emcc
#   --cxx=em++
#   --objcc=emcc
#   --dep-cc=emcc
#   # 解码器
#   --enable-decoder=pcm_mulaw
#   --enable-decoder=pcm_alaw
#   --enable-decoder=adpcm_ima_smjpeg
#   --enable-decoder=aac
#   --enable-decoder=hevc
#   --enable-decoder=h264
#   --enable-protocol=file
#   # 其他禁用项目
#   --disable-devices
#   --disable-indevs
#   --disable-outdevs
#   --disable-network
#   --disable-w32threads
#   --disable-pthreads
# )

# configure_ffmpeg() {
#   emconfigure ./configure "${FFMPEG_CONFIG_FLAGS_BASE[@]}"
# }

# make_ffmpeg() {
#   NPROC=$(grep -c ^processor /proc/cpuinfo)
#   emmake make -j${NPROC}
# }

# build_ffmpegjs() {
#   emcc \
#     -I. -I./fftools -I$BUILD_DIR/include \
#     -Llibavcodec -Llibavdevice -Llibavfilter -Llibavformat -Llibavresample -Llibavutil -Llibpostproc -Llibswscale -Llibswresample -Llibpostproc -L${BUILD_DIR}/lib \
#     -Qunused-arguments -Oz \
#     -o wasm/dist/ffmpeg-core.js fftools/ffmpeg_opt.c fftools/ffmpeg_filter.c fftools/ffmpeg_hw.c fftools/cmdutils.c fftools/ffmpeg.c \
#     -lavdevice -lavfilter -lavformat -lavcodec -lswresample -lswscale -lavutil -lpostproc -lm \
#     --closure 1 \
#     -s USE_SDL=2 \
#     -s MODULARIZE=1 \
#     -s SINGLE_FILE=1 \
#     -s EXTRA_EXPORTED_RUNTIME_METHODS="[cwrap, FS, getValue, setValue]" \
#     -s EXPORTED_FUNCTIONS="[_main]" \
#     -s TOTAL_MEMORY=33554432 \
#     -s ALLOW_MEMORY_GROWTH=1
# }

# main() {
#   # build_x264
#   configure_ffmpeg
#   make_ffmpeg
#   build_ffmpegjs
# }

# main "$@"