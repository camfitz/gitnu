#!/bin/bash

set -e

echo 'Building Gitnu for distribution.'
echo 'Please ensure you have unpdated manifest.json with the latest version number or Chrome Webstore upload will fail.'
echo 'Run pub get prior to this build tool.'
echo "Building into build/gitnu.zip"

BUILD_DIR=build
UNPACKED_DIR=$BUILD_DIR/gitnu

mkdir -p $UNPACKED_DIR/lib

dart2js app/gitnu.dart -o $UNPACKED_DIR/gitnu.dart.js

echo "Finished dart2js."

APP_JS_TOOLS="app/dart.js"
APP_SUPPORT_FILES="app/styles.css app/README.md app/manifest.json app/gitnu.html app/background.js app/bootstrap.js app/packages"
APP_STATIC_RESOURCES="app/dart_icon.png app/assets"
ZLIB_IN_SPARK="lib/spark/spark/ide/app/git/third_party"
ZLIB_FILES="app/$ZLIB_IN_SPARK/zlib_deflate.js app/$ZLIB_IN_SPARK/zlib_inflate.js"

COPY="cp -R -f -t"

## Copy some files that we need.
$COPY $UNPACKED_DIR/ $APP_JS_TOOLS $APP_SUPPORT_FILES $APP_STATIC_RESOURCES
## Bootstrap CSS
$COPY $UNPACKED_DIR/lib app/lib/bootstrap
## Spark ZLib
mkdir -p $UNPACKED_DIR/$ZLIB_IN_SPARK
$COPY $UNPACKED_DIR/$ZLIB_IN_SPARK $ZLIB_FILES

## Zip the files into the build zip folder with name specified earlier. Replaces files if the zip folder exists.
(
cd $UNPACKED_DIR
zip -r -q ../gitnu *
)

echo "Built build/gitnu.zip."