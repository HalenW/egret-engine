#!/bin/sh

# MacOS编译
# 脚本所在地址
PakagePath=`pwd`
echo "脚本所在地址-----:$PakagePath"

cd ..

# 包所在地址
BasePath=`pwd`
echo "包所在地址-----:$BasePath"

#回到脚本所在地址
cd "$PakagePath"
echo "回到脚本所在地址pwd-----:`pwd` "

CONFIGURE_FLAGS="--disable-shared --disable-frontend"
ARCHS="arm64 armv7s x86_64 i386 armv7"

# 目录准备等价于 --prefix
# 存放最终的合成的真机、模拟器通用的 .a 的文件夹
FAT=$BasePath/fat-lame
echo "FAT地址-----:$FAT "

# 存放脚本执行过程产生的对应不同架构的库文件夹
SCRATCH=$BasePath/scratch-lame

# 存放各个架构.a 和 include w
THIN=$BasePath/"thin-lame"

COMPILE="y"
LIPO="y"

if [ "$*" ]
then
	if [ "$*" = "lipo" ]
	then
		# skip compile
		COMPILE=
	else
		ARCHS="$*"
		if [ $# -eq 1 ]
		then
			# skip lipo
			LIPO=
		fi
	fi
fi

if [ "$COMPILE" ]
then
	#根据Platform修改CC，CFLAGS
	CWD=`pwd`
	for ARCH in $ARCHS
	do
		echo "building $ARCH..."
		mkdir -p "$SCRATCH/$ARCH"
		cd "$SCRATCH/$ARCH"

		if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
		then
		    PLATFORM="iPhoneSimulator"
		    if [ "$ARCH" = "x86_64" ]
		    then
		    	SIMULATOR="-mios-simulator-version-min=7.0"
                        HOST=x86_64-apple-darwin
		    else
		    	SIMULATOR="-mios-simulator-version-min=5.0"
                        HOST=i386-apple-darwin
		    fi
		else
		    PLATFORM="iPhoneOS"
		    SIMULATOR=
                    HOST=arm-apple-darwin
		fi
		#配置编译环境
		#xcrun --sdk iphoneos --show-sdk-path
		#xcrun -sdk iphonesimulator -show-sdk-path
		XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		CC="xcrun -sdk $XCRUN_SDK clang -arch $ARCH"
		#AS="$CWD/$SOURCE/extras/gas-preprocessor.pl $CC"
		CFLAGS="-arch $ARCH $SIMULATOR"
		#xcode 版本验证
		if ! xcodebuild -version | grep "Xcode [1-6]\."
		then
			CFLAGS="$CFLAGS -fembed-bitcode"
		fi
		CXXFLAGS="$CFLAGS"
		LDFLAGS="$CFLAGS"

		CC=$CC $CWD/$SOURCE/configure \
		    $CONFIGURE_FLAGS \
                    --host=$HOST \
		    --prefix="$THIN/$ARCH" \
                    CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS"

		make -j3 install
		cd $CWD
	done
fi

if [ "$LIPO" ]
then
	#上述架构库合并
	echo "building fat binaries..."
	mkdir -p $FAT/lib
	set - $ARCHS
	CWD=`pwd`
	cd $THIN/$1/lib
	for LIB in *.a
	do
		cd $CWD
		lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB
	done

	cd $CWD
	cp -rf $THIN/$1/include $FAT

    #验证合并的.a 架构
    cd $FAT/lib
    for LIB in *.a
    do
    lipo -info $LIB
    done

    #打开合并的.a 所在位置
    open $FAT/lib

fi
