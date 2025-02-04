#------------------------------------------------------
# tensorflow-lite
#
# This mk file defines tensorflow-lite module with prebuilt static library.
# To build and run the example with gstreamer binaries, we built a static library (e.g., libtensorflow-lite.a)
# for Android/Tensorflow-lite from the Tensorflow repository of the Tizen software platform.
# - [Tizen] Tensorflow git repository:
#    * Repository: https://review.tizen.org/gerrit/p/platform/upstream/tensorflow
#------------------------------------------------------
LOCAL_PATH := $(call my-dir)

ifndef NNSTREAMER_ROOT
$(error NNSTREAMER_ROOT is not defined!)
endif

include $(NNSTREAMER_ROOT)/jni/nnstreamer.mk

TFLITE_VERSION := 1.13.1

_TFLITE_VERSIONS = $(subst ., , $(TFLITE_VERSION))
TFLITE_VERSION_MAJOR := $(word 1, $(_TFLITE_VERSIONS))
TFLITE_VERSION_MINOR := $(word 2, $(_TFLITE_VERSIONS))
TFLITE_VERSION_MICRO := $(word 3, $(_TFLITE_VERSIONS))

TFLITE_FLAGS := \
    -DTFLITE_SUBPLUGIN_NAME=\"tensorflow-lite\" \
    -DTFLITE_VERSION=$(TFLITE_VERSION) \
    -DTFLITE_VERSION_MAJOR=$(TFLITE_VERSION_MAJOR) \
    -DTFLITE_VERSION_MINOR=$(TFLITE_VERSION_MINOR) \
    -DTFLITE_VERSION_MICRO=$(TFLITE_VERSION_MICRO)

# Define types and features in tensorflow-lite sub-plugin.
# FLOAT16/COMPLEX64 for tensorflow-lite >= 2, and INT8/INT16 for tensorflow-lite >=1.13
# GPU-delegate supported on tensorflow-lite >= 2
# NNAPI-delegate supported on tensorflow-lite >= 1.14
TFLITE_ENABLE_GPU_DELEGATE := false
TFLITE_ENABLE_NNAPI_DELEGATE := false
TFLITE_EXPORT_LDLIBS :=

ifeq ($(shell test $(TFLITE_VERSION_MAJOR) -ge 2; echo $$?),0)
TFLITE_ENABLE_GPU_DELEGATE := true
TFLITE_ENABLE_NNAPI_DELEGATE := true

TFLITE_FLAGS += -DTFLITE_INT8=1 -DTFLITE_INT16=1 -DTFLITE_FLOAT16=1 -DTFLITE_COMPLEX64=1
else
ifeq ($(shell test $(TFLITE_VERSION_MINOR) -ge 14; echo $$?),0)
TFLITE_ENABLE_NNAPI_DELEGATE := true
endif

ifeq ($(shell test $(TFLITE_VERSION_MINOR) -ge 13; echo $$?),0)
TFLITE_FLAGS += -DTFLITE_INT8=1 -DTFLITE_INT16=1
endif
endif

ifeq ($(TFLITE_ENABLE_NNAPI_DELEGATE),true)
TFLITE_FLAGS += -DTFLITE_NNAPI_DELEGATE_SUPPORTED=1
endif

ifeq ($(TFLITE_ENABLE_GPU_DELEGATE),true)
TFLITE_FLAGS += -DTFLITE_GPU_DELEGATE_SUPPORTED=1
TFLITE_EXPORT_LDLIBS += -lEGL -lGLESv2
endif

TF_LITE_DIR := $(LOCAL_PATH)/tensorflow-lite
TF_LITE_INCLUDES := $(TF_LITE_DIR)/include

ifeq ($(TARGET_ARCH_ABI),armeabi-v7a)
TF_LITE_LIB_PATH := $(TF_LITE_DIR)/lib/armv7
else ifeq ($(TARGET_ARCH_ABI),arm64-v8a)
TF_LITE_LIB_PATH := $(TF_LITE_DIR)/lib/arm64
else
$(error Target arch ABI not supported: $(TARGET_ARCH_ABI))
endif

#------------------------------------------------------
# tensorflow-lite (prebuilt static library)
#------------------------------------------------------
include $(CLEAR_VARS)

LOCAL_MODULE := tensorflow-lite-lib
LOCAL_SRC_FILES := $(TF_LITE_LIB_PATH)/libtensorflow-lite.a
LOCAL_EXPORT_LDFLAGS := -Wl,--exclude-libs,libtensorflow-lite.a

include $(PREBUILT_STATIC_LIBRARY)

#------------------------------------------------------
# tensor-filter sub-plugin for tensorflow-lite
#------------------------------------------------------
include $(CLEAR_VARS)

LOCAL_MODULE := tensorflow-lite-subplugin
LOCAL_SRC_FILES := $(NNSTREAMER_FILTER_TFLITE_SRCS)
LOCAL_CXXFLAGS := -std=c++11 -O3 -fPIC -frtti -fexceptions $(NNS_API_FLAGS) $(TFLITE_FLAGS)
LOCAL_C_INCLUDES := $(TF_LITE_INCLUDES) $(NNSTREAMER_INCLUDES) $(GST_HEADERS_COMMON)
LOCAL_EXPORT_LDLIBS := $(TFLITE_EXPORT_LDLIBS)
LOCAL_STATIC_LIBRARIES := tensorflow-lite-lib cpufeatures

include $(BUILD_STATIC_LIBRARY)
