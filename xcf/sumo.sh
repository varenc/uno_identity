#!/bin/sh
set -ex

: "${LIBNAME:=libunoxcf}"
: "${OUTNAME:=UnoRust}"
: "${TOOLCHAIN:=nightly}"
: "${PROFILE:=release}"
: "${PROFDIR:=$PROFILE}"
: "${OUTDIR:=../target/$PROFDIR}"

#
# Build an archs table because the triple arch is not the same as lipo arch.
#
ARCHS="
aarch64
x86_64
"
subarchs=$(mktemp -d)
echo "arm64v8" > $subarchs/aarch64
echo "x86_64" > $subarchs/x86_64

mkdir -p $OUTDIR/a

#
# Build macOS.
#
lipo_args=""

for ARCH in $ARCHS
do
  TRIPLE="$ARCH-apple-darwin"
  cargo +$TOOLCHAIN build \
      -Z unstable-options --profile $PROFILE \
      --target $TRIPLE

  larch=$(< $subarchs/$ARCH)
  lipo_args="$lipo_args
    -arch $larch ../target/$TRIPLE/$PROFDIR/$LIBNAME.a"
done

lipo -create $lipo_args -output $OUTDIR/a/$LIBNAME-macos.a

xc_args="$xc_args
    -library $OUTDIR/a/$LIBNAME-macos.a"
xc_args="$xc_args
    -headers include"


#
# Build iOS.
#
cargo +$TOOLCHAIN build \
    -Z unstable-options --profile $PROFILE \
    --target aarch64-apple-ios

cp ../target/aarch64-apple-ios/$PROFDIR/$LIBNAME.a $OUTDIR/a/$LIBNAME-ios.a

xc_args="$xc_args
    -library $OUTDIR/a/$LIBNAME-ios.a"
xc_args="$xc_args
    -headers include"


#
# Build ios simulator.
#
cargo +$TOOLCHAIN build \
    -Z unstable-options --profile $PROFILE \
    --target aarch64-apple-ios-sim

lipo_args="
    -arch arm64v8 ../target/aarch64-apple-ios-sim/$PROFDIR/$LIBNAME.a"

# The simulator target doesn't end in `-sim` on x86_64
cargo +$TOOLCHAIN build \
    -Z unstable-options --profile $PROFILE \
    --target x86_64-apple-ios

lipo_args="$lipo_args
    -arch x86_64 ../target/x86_64-apple-ios/$PROFDIR/$LIBNAME.a"

lipo -create $lipo_args -output $OUTDIR/a/$LIBNAME-ios-sim.a

xc_args="$xc_args
    -library $OUTDIR/a/$LIBNAME-ios-sim.a"
xc_args="$xc_args
    -headers include"


#
# Build mac catalyst.
#
lipo_args=""
for ARCH in $ARCHS
do
  TRIPLE="$ARCH-apple-ios-macabi"
  cargo +$TOOLCHAIN build \
      -Z unstable-options --profile $PROFILE \
      -Z build-std \
      --target $TRIPLE

  larch=$(< $subarchs/$ARCH)
  lipo_args="$lipo_args
    -arch $larch ../target/$TRIPLE/$PROFDIR/$LIBNAME.a"
done

lipo -create $lipo_args -output $OUTDIR/a/$LIBNAME-ios-macabi.a

xc_args="$xc_args
    -library $OUTDIR/a/$LIBNAME-ios-macabi.a"
xc_args="$xc_args
    -headers include"


#
# Build the sumo xcframework.
#
rm -rf $OUTDIR/$OUTNAME.xcframework
xcodebuild -create-xcframework $xc_args -output $OUTDIR/$OUTNAME.xcframework

