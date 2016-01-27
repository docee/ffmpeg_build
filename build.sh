#!/bin/bash

: << '#__REM__'

Build for iOS and ffmpeg. Build a full auto of architecture and multiple creation of toolchains and downloads Create the following architecture, version 2.8.5 by default
i386 x86_64 armv7 armv7s

#__REM__

TARGET_VERSION="2.8.5"
ARCHIVE_BASENAME="ffmpeg"
ARCHIVE_FILE="${ARCHIVE_BASENAME}-${TARGET_VERSION}.tar.bz2"
ARCHIVE_TYPE="tar.bz2"
DOWNLOAD_URL="http://www.ffmpeg.org/releases/${ARCHIVE_FILE}"
OUTPUT_LIBS="libavcodec.a libavdevice.a libavfilter.a libavformat.a libavutil.a libswresample.a libswscale.a"

#livavもarm64はビルドできなかった
#TARGET_VERSION="head"
#ARCHIVE_BASENAME="libav"
#ARCHIVE_FILE="${ARCHIVE_BASENAME}-${TARGET_VERSION}.tar.gz"
#ARCHIVE_TYPE="tar.gz"
#DOWNLOAD_URL="http://git.libav.org/?p=libav.git;a=snapshot;h=HEAD;sf=tgz"
#OUTPUT_LIBS="libavcodec.a libavfilter.a libavformat.a libavutil.a libswresample.a libswscale.a"

#ios
DEPLOYMENT_TARGET="ios"
SDK_VERSION="9.2"
MIN_OS_VERSION="7.0"
ARCHS="i386 x86_64 armv7 armv7s"

#osx
DEPLOYMENT_TARGET="osx"
SDK_VERSION="10.11"
MIN_OS_VERSION="10.8"
ARCHS="i386 x86_64"

MAC_CPU=corei7
#MAC_CPU=core2
FILE_API_32=0
COCOS2DX=1

DEBUG=0
VERBOSE=1

########################################

DEVELOPER=`xcode-select -print-path`
#DEVELOPER="/Applications/Xcode.app/Contents/Developer"

cd "`dirname \"$0\"`"
REPOROOT=$(pwd)

OUTPUT_DIR="${REPOROOT}/dependencies-lib"
mkdir -p "${OUTPUT_DIR}/include"
mkdir -p "${OUTPUT_DIR}/lib"

BUILD_DIR="${REPOROOT}/build"

SRC_DIR="${BUILD_DIR}/src"
mkdir -p "${SRC_DIR}"
WORK_DIR="${BUILD_DIR}/work"
mkdir -p "${WORK_DIR}"
INTER_DIR="${BUILD_DIR}/built"
mkdir -p "$INTER_DIR"

########################################

cd $SRC_DIR

set -e

if [ "${ARCHIVE_FILE}" == "" ]; then
		ARCHIVE_FILE="src_archive.${ARCHIVE_TYPE}"
fi

if [ "`ls -F | grep /`" == "" ]; then
	cat <<_EOT_
##############################################################################
####
####  Downloading ${ARCHIVE_BASENAME}-${TARGET_VERSION}.tar.gz
####
##############################################################################
_EOT_
	#curl -O ${DOWNLOAD_URL}
	wget "${DOWNLOAD_URL}" -O "${ARCHIVE_FILE}"
	echo "Done." ; echo ""

cat <<_EOT_
##############################################################################
####
####  Using ${ARCHIVE_FILE}
####
##############################################################################
_EOT_
	#tar jxf ${ARCHIVE_FILE} -C ${SRC_DIR}
	#tar zxf ${ARCHIVE_FILE} -C ${SRC_DIR}

	case "${ARCHIVE_TYPE}" in
		"tar.gz" )
			tar zxf ${ARCHIVE_FILE} -C ${SRC_DIR}
		;;

		"tar.bz2" )
			tar jxf ${ARCHIVE_FILE} -C ${SRC_DIR}
		;;

		"tar.xz" )
			tar Jxf ${ARCHIVE_FILE} -C ${SRC_DIR}
		;;

		".tar.lzma" )
			tar xf --lzma ${ARCHIVE_FILE} -C ${SRC_DIR}
		;;
	esac
fi

cd $WORK_DIR

GAS_PREPROCESSOR_DIR="${WORK_DIR}/gas-preprocessor-master"
if [ ! -e "${GAS_PREPROCESSOR_DIR}/gas-preprocessor.pl" ]; then
	cat <<_EOT_
##############################################################################
####
####   Downloading gas-preprocessor.pl (libav gas-preprocessor)
####
##############################################################################
_EOT_
	wget --no-check-certificate "https://github.com/libav/gas-preprocessor/archive/master.zip"
	unzip "master.zip"
	chmod 755 ${GAS_PREPROCESSOR_DIR}/gas-preprocessor.pl
	echo "Done." ; echo ""
fi

ARCHIVE_OUT="`ls -F ${SRC_DIR} | grep /`"
cd "${SRC_DIR}/${ARCHIVE_OUT}"

export ORIGINALPATH=$PATH

if [ "${DEPLOYMENT_TARGET}" == "ios" ]; then
	X86PLATFORM="iPhoneSimulator"
	PLATFORM_DEPLOYMENT_TARGET="IPHONEOS_DEPLOYMENT_TARGET"
else
	X86PLATFORM="MacOSX"
	PLATFORM_DEPLOYMENT_TARGET="OSX_DEPLOYMENT_TARGET"
fi

for ARCH in ${ARCHS}
do
	if [ "${ARCH}" == "i386" ] || [ "${ARCH}" == "x86_64" ]; then
		PLATFORM=${X86PLATFORM}
	else
		PLATFORM="iPhoneOS"
	fi

	if [ "${DEPLOYMENT_TARGET}" == "ios" ]; then
		if [ "${ARCH}" == "i386" ] || [ "${ARCH}" == "x86_64" ]; then
			CFLAG_VERSION_MIN="-mios-simulator-version-min"
		else
			CFLAG_VERSION_MIN="-miphoneos-version-min"
		fi
	else
		CFLAG_VERSION_MIN="-mmacosx-version-min"
	fi

	PREFIX="${INTER_DIR}/${PLATFORM}${SDK_VERSION}-${ARCH}.sdk"
	mkdir -p "${PREFIX}"

  export PATH=$ORIGINALPATH

  export PATH="${GAS_PREPROCESSOR_DIR}:${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer/usr/bin:${DEVELOPER}/usr/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

	cat <<_EOT_
##############################################################################
####
####   Configure ${ARCH}
####
##############################################################################
_EOT_

	case "${ARCH}" in
		"i386" | "x86" )
			TOOLCHAIN="${DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr"
			HOST_PLATFORM=${DEVELOPER}/Platforms/${PLATFORM}.platform
			HOST_SYSROOT=$HOST_PLATFORM/Developer/SDKs/${PLATFORM}${SDK_VERSION}.sdk
			HOST_CFLAGS="-isysroot $HOST_SYSROOT -arch ${ARCH} -I${TOOLCHAIN}/include ${CFLAG_VERSION_MIN}=${MIN_OS_VERSION} -mtune=${MAC_CPU}"
			HOST_LDFLAGS="-isysroot $HOST_SYSROOT -arch ${ARCH} -I${TOOLCHAIN}/include ${CFLAG_VERSION_MIN}=${MIN_OS_VERSION} -mtune=${MAC_CPU}"

			export ${PLATFORM_DEPLOYMENT_TARGET}=$SDK_VERSION
			if [ "${DEBUG}" == 0 ]; then
				HOST_CFLAGS="${HOST_CFLAGS} -O3 -DNDEBUG"
			else
				HOST_CFLAGS="${HOST_CFLAGS} -O0 -g -DDEBUG"
			fi

			if [ ${COCOS2DX} -ne 0 ]; then
				FILE_API_32=1
				if [ ${DEBUG} -ne 0 ]; then
					HOST_CFLAGS="${HOST_CFLAGS} -DCOCOS2D_DEBUG=2"
				fi
			fi

			if [ ${FILE_API_32} -ne 0 ]; then
				HOST_CFLAGS="${HOST_CFLAGS} -U_LARGEFILE_SOURCE -U_FILE_OFFSET_BITS -D_FILE_OFFSET_BITS=32 -DUSE_FILE32API"
			fi

			./configure \
			    --prefix=$PREFIX \
			    --enable-static \
			    --disable-shared \
			    --disable-doc \
			    --disable-ffmpeg \
			    --disable-ffplay \
			    --disable-ffprobe \
			    --disable-ffserver \
			    --disable-avdevice \
			    --disable-symver \
			    --target-os=darwin \
			    --arch=i386 \
			    --cpu=${MAC_CPU} \
			    --enable-cross-compile \
			    --sysroot=${HOST_SYSROOT} \
					--disable-yasm \
			    --extra-cflags="${HOST_CFLAGS}" \
			    --extra-ldflags="${HOST_LDFLAGS}" \
			    ${CONFIGURE_EXTEA}
		;;



		"i686" | "x86_64" )
			TOOLCHAIN="${DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr"
			HOST_PLATFORM=${DEVELOPER}/Platforms/${PLATFORM}.platform
			HOST_SYSROOT=$HOST_PLATFORM/Developer/SDKs/${PLATFORM}${SDK_VERSION}.sdk
			HOST_CFLAGS="-isysroot $HOST_SYSROOT -arch ${ARCH} -I${TOOLCHAIN}/include ${CFLAG_VERSION_MIN}=${MIN_OS_VERSION} -mtune=${MAC_CPU}"
			HOST_LDFLAGS="-isysroot $HOST_SYSROOT -arch ${ARCH} -I${TOOLCHAIN}/include ${CFLAG_VERSION_MIN}=${MIN_OS_VERSION} -mtune=${MAC_CPU}"

			export ${PLATFORM_DEPLOYMENT_TARGET}=$SDK_VERSION
			if [ "${DEBUG}" == 0 ]; then
				HOST_CFLAGS="${HOST_CFLAGS} -O3 -DNDEBUG"
			else
				HOST_CFLAGS="${HOST_CFLAGS} -O0 -g -DDEBUG"
			fi

			if [ ${COCOS2DX} -ne 0 ]; then
				FILE_API_32=1
				if [ ${DEBUG} -ne 0 ]; then
					HOST_CFLAGS="${HOST_CFLAGS} -DCOCOS2D_DEBUG=2"
				fi
			fi

			if [ ${FILE_API_32} -ne 0 ]; then
				HOST_CFLAGS="${HOST_CFLAGS} -U_LARGEFILE_SOURCE -U_FILE_OFFSET_BITS -D_FILE_OFFSET_BITS=32 -DUSE_FILE32API"
			fi

			./configure \
			    --prefix=$PREFIX \
			    --enable-static \
			    --disable-shared \
			    --disable-doc \
			    --disable-ffmpeg \
			    --disable-ffplay \
			    --disable-ffprobe \
			    --disable-ffserver \
			    --disable-avdevice \
			    --disable-symver \
			    --target-os=darwin \
			    --arch=i686 \
			    --cpu=${MAC_CPU} \
			    --enable-cross-compile \
			    --sysroot=${HOST_SYSROOT} \
					--disable-yasm \
			    --extra-cflags="${HOST_CFLAGS}" \
			    --extra-ldflags="${HOST_LDFLAGS}" \
			    ${CONFIGURE_EXTEA}
		;;



		"armv7" | "armv7s" | "arm64" )
			TOOLCHAIN="${DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr"
			HOST_PLATFORM=${DEVELOPER}/Platforms/${PLATFORM}.platform
			HOST_SYSROOT=$HOST_PLATFORM/Developer/SDKs/${PLATFORM}${SDK_VERSION}.sdk
			HOST_CFLAGS="-isysroot $HOST_SYSROOT -arch ${ARCH} -I${TOOLCHAIN}/include ${CFLAG_VERSION_MIN}=${MIN_OS_VERSION}"
			HOST_LDFLAGS="-isysroot $HOST_SYSROOT -arch ${ARCH} -I${TOOLCHAIN}/include ${CFLAG_VERSION_MIN}=${MIN_OS_VERSION}"

			export ${PLATFORM_DEPLOYMENT_TARGET}=$SDK_VERSION

			if [ "${DEBUG}" == 0 ]; then
				HOST_CFLAGS="${HOST_CFLAGS} -O3 -DNDEBUG"
			else
				HOST_CFLAGS="${HOST_CFLAGS} -O0 -g -DDEBUG"
			fi

			if [ ${COCOS2DX} -ne 0 ]; then
				FILE_API_32=1
				if [ ${DEBUG} -ne 0 ]; then
					HOST_CFLAGS="${HOST_CFLAGS} -DCOCOS2D_DEBUG=2"
				fi
			fi

			if [ ${FILE_API_32} -ne 0 ]; then
				HOST_CFLAGS="${HOST_CFLAGS} -U_LARGEFILE_SOURCE -U_FILE_OFFSET_BITS -D_FILE_OFFSET_BITS=32 -DUSE_FILE32API"
			fi

			./configure \
			    --prefix=$PREFIX \
			    --enable-static \
			    --disable-shared \
			    --disable-doc \
			    --disable-ffmpeg \
			    --disable-ffplay \
			    --disable-ffprobe \
			    --disable-ffserver \
			    --disable-avdevice \
			    --disable-symver \
			    --target-os=darwin \
			    --arch=${ARCH} \
			    --enable-cross-compile \
			    --sysroot=${HOST_SYSROOT} \
			    --extra-cflags="${HOST_CFLAGS}" \
			    --extra-ldflags="${HOST_LDFLAGS}" \
			    ${CONFIGURE_EXTEA}
		;;

	esac
	echo "Done." ; echo ""

		cat <<_EOT_
##############################################################################
####
####   Make ${ARCH}
####
##############################################################################
_EOT_
	make V=${VERBOSE} clean
	make -j4 V=${VERBOSE}
	make -j4 V=${VERBOSE} install
	echo "Done." ; echo ""
done

########################################

	cat <<_EOT_
##############################################################################
####
####   Build library ...
####
##############################################################################
_EOT_
for OUTPUT_LIB in ${OUTPUT_LIBS}; do
	INPUT_LIBS=""
	for ARCH in ${ARCHS}; do
		if [ "${ARCH}" == "i386" ] || [ "${ARCH}" == "x86_64" ]; then
			PLATFORM=${X86PLATFORM}
		else
			PLATFORM="iPhoneOS"
		fi
		INPUT_ARCH_LIB="${INTER_DIR}/${PLATFORM}${SDK_VERSION}-${ARCH}.sdk/lib/${OUTPUT_LIB}"
		if [ -e $INPUT_ARCH_LIB ]; then
			INPUT_LIBS="${INPUT_LIBS} ${INPUT_ARCH_LIB}"
		fi
	done
	# Combine the three architectures into a universal library.
	if [ -n "$INPUT_LIBS"  ]; then
		lipo -create $INPUT_LIBS \
		-output "${OUTPUT_DIR}/lib/${OUTPUT_LIB}"
	else
		echo "$OUTPUT_LIB does not exist, skipping (are the dependencies installed?)"
	fi
done

for ARCH in ${ARCHS}; do
	if [ "${ARCH}" == "i386" ] || [ "${ARCH}" == "x86_64" ]; then
		PLATFORM=${X86PLATFORM}
	else
		PLATFORM="iPhoneOS"
	fi
	cp -R ${INTER_DIR}/${PLATFORM}${SDK_VERSION}-${ARCH}.sdk/include/* ${OUTPUT_DIR}/include/
	if [ $? == "0" ]; then
		# We only need to copy the headers over once. (So break out of forloop
		# once we get first success.)
		break
	fi
	echo "Done." ; echo ""
done
echo "Done all." ; echo ""
