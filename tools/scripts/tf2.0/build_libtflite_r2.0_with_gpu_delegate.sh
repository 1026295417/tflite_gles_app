#!/bin/sh
set -e
#set -x

export TENSORFLOW_VER=r2.0
export TENSORFLOW_DIR=`pwd`/tensorflow_${TENSORFLOW_VER}

git clone https://github.com/tensorflow/tensorflow.git ${TENSORFLOW_DIR}

cd ${TENSORFLOW_DIR}
git checkout ${TENSORFLOW_VER}


# apply patch for GPU Delegate
export SCRIPT_DIR=`dirname $0`
PATCH_FILE=${SCRIPT_DIR}/tensorflow_tf20_enable_gpu_delegate.diff
patch -p1 < ${PATCH_FILE}



echo "----------------------------------------------------"
echo " (configure) press ENTER-KEY several times.         "
echo "----------------------------------------------------"
./configure

# clean up bazel cache, just in case.
bazel clean

# download all the build dependencies.
./tensorflow/lite/tools/make/download_dependencies.sh 2>&1 | tee -a log_download_dependencies.txt


# build GPU Delegate library (libtensorflowlite_gpu_gl.so)
bazel build -s -c opt --copt="-DMESA_EGL_NO_X11_HEADERS" tensorflow/lite/delegates/gpu:libtensorflowlite_gpu_gl.so 2>&1 | tee -a log_build_delegate.txt


# reuse bazel products for make.
cd ${TENSORFLOW_DIR}
ln -s ./bazel-bin/../../../external .
cp bazel-out/k8-opt/genfiles/tensorflow/lite/delegates/gpu/gl/metadata_generated.h       ./tensorflow/lite/delegates/gpu/gl/
cp bazel-out/k8-opt/genfiles/tensorflow/lite/delegates/gpu/gl/common_generated.h         ./tensorflow/lite/delegates/gpu/gl/
cp bazel-out/k8-opt/genfiles/tensorflow/lite/delegates/gpu/gl/workgroups_generated.h     ./tensorflow/lite/delegates/gpu/gl/
cp bazel-out/k8-opt/genfiles/tensorflow/lite/delegates/gpu/gl/compiled_model_generated.h ./tensorflow/lite/delegates/gpu/gl/


# build TensorFlow Lite library (libtensorflow-lite.a)
make -j 4  -f ./tensorflow/lite/tools/make/Makefile BUILD_WITH_NNAPI=false EXTRA_CXXFLAGS="-march=native" 2>&1 | tee -a log_build_libtflite_gpu_delegate.txt


echo "----------------------------------------------------"
echo " build success."
echo "----------------------------------------------------"

cd ${TENSORFLOW_DIR}
ls -l tensorflow/lite/tools/make/gen/linux_x86_64/lib/

