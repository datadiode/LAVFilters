#!/bin/sh

arch=x86
archdir=Win32
clean_build=true
cross_prefix=

CV2PDB=../thirdparty/contrib/cv2pdb.exe

for opt in "$@"
do
    case "$opt" in
    x86)
            ;;
    x64 | amd64)
            arch=x86_64
            archdir=x64
            cross_prefix=x86_64-w64-mingw32-
            ;;
    quick)
            clean_build=false
            ;;
    *)
            echo "Unknown Option $opt"
            exit 1
    esac
done

make_dirs() (
  mkdir -p bin_${archdir}/lib
  mkdir -p bin_${archdir}d/lib
)

copy_libs() (
  # copy and process .dll/.pdb
  for file in lib*/*-lav-*.dll; do
    file_basename=$(basename $file)
    file_pdb=$(basename $file .dll).pdb
    ${CV2PDB} -p${file_pdb} ${file} ../bin_${archdir}d/${file_basename}
    cp ../bin_${archdir}d/${file_basename} ../bin_${archdir}/
    cp ../bin_${archdir}d/${file_pdb} ../bin_${archdir}/
  done

  # copy lib files
  cp -u lib*/*.lib ../bin_${archdir}/lib
  cp -u lib*/*.lib ../bin_${archdir}d/lib
)

clean() (
  make distclean > /dev/null 2>&1
)

configure() (
  OPTIONS="
    --disable-x86asm                \
	--x86asmexe=yasm.exe            \
    --enable-shared                 \
    --disable-static                \
    --enable-gpl                    \
    --enable-version3               \
    --disable-autodetect            \
    --enable-w32threads             \
    --disable-demuxer=matroska      \
    --disable-filters               \
    --enable-filter=scale,yadif,w3fdif,bwdif \
    --disable-protocol=async,cache,concat,httpproxy,icecast,md5,subfile \
    --disable-muxers                \
    --enable-muxer=spdif            \
    --disable-bsfs                  \
    --enable-bsf=extract_extradata  \
    --disable-avdevice              \
    --disable-encoders              \
    --disable-devices               \
    --disable-programs              \
    --disable-debug                 \
    --disable-doc                   \
    --enable-avisynth               \
    --enable-bzlib                  \
    --enable-d3d11va                \
    --enable-dxva2                  \
    --enable-schannel               \
    --enable-gmp                    \
    --enable-libdav1d               \
    --enable-libspeex               \
    --enable-libopencore-amrnb      \
    --enable-libopencore-amrwb      \
    --enable-libxml2                \
    --enable-zlib                   \
    --build-suffix=-lav             \
    --disable-stripping             \
    --arch=${arch}"

  EXTRA_CFLAGS="-fno-tree-vectorize -D_WIN32_WINNT=0x0600 -DWINVER=0x0600 -gdwarf-5"
  EXTRA_LDFLAGS=""
  PKG_CONFIG_PREFIX_DIR=""
  if [ "${arch}" == "x86_64" ]; then
    export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:../thirdparty/64/lib/pkgconfig/"
    OPTIONS="${OPTIONS} --enable-cross-compile --cross-prefix=${cross_prefix} --target-os=mingw32 --pkg-config=pkg-config"
    EXTRA_CFLAGS="${EXTRA_CFLAGS} -I../thirdparty/64/include -fno-omit-frame-pointer"
    EXTRA_LDFLAGS="${EXTRA_LDFLAGS} -L../thirdparty/64/lib"
    PKG_CONFIG_PREFIX_DIR="--define-variable=prefix=../thirdparty/64"
  else
    export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:../thirdparty/32/lib/pkgconfig/"
    OPTIONS="${OPTIONS} --cpu=i686"
    EXTRA_CFLAGS="${EXTRA_CFLAGS} -I../thirdparty/32/include -mmmx -msse -msse2 -mfpmath=sse -mstackrealign"
    EXTRA_LDFLAGS="${EXTRA_LDFLAGS} -L../thirdparty/32/lib"
    PKG_CONFIG_PREFIX_DIR="--define-variable=prefix=../thirdparty/32"
  fi

  sh configure --extra-ldflags="${EXTRA_LDFLAGS}" --extra-cflags="${EXTRA_CFLAGS}" --pkg-config-flags="--static ${PKG_CONFIG_PREFIX_DIR}" ${OPTIONS}
)

build() (
  make -j$NUMBER_OF_PROCESSORS
)

make_dirs

echo
echo Building ffmpeg in GCC ${arch} Release config...
echo

cd ffmpeg

if $clean_build ; then
    clean

    ## run configure, redirect to file because of a msys bug
    configure > ffbuild/config.out 2>&1
    CONFIGRETVAL=$?

    ## show configure output
    cat ffbuild/config.out
fi

## Only if configure succeeded, actually build
if ! $clean_build || [ ${CONFIGRETVAL} -eq 0 ]; then
  build &&
  copy_libs
fi

cd ..
