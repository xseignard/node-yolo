GPU=1
CUDNN=0
OPENCV=1
OPENMP=0
DEBUG=0

NVCC = $(shell find /usr -iname "nvcc" 2> /dev/null)
NVCC_TEST := $(notdir $(NVCC))

ifeq ($(NVCC_TEST),nvcc)
	GPU=1
	CUDNN=1
endif

ARCH= -gencode arch=compute_30,code=sm_30 \
      -gencode arch=compute_35,code=sm_35 \
      -gencode arch=compute_50,code=[sm_50,compute_50] \
      -gencode arch=compute_52,code=[sm_52,compute_52] \
      -gencode arch=compute_61,code=sm_61 \
      -gencode arch=compute_62,code=sm_62 \
      -gencode arch=compute_70,code=sm_70

# This is what I use, uncomment if you know your arch and want to specify
# ARCH= -gencode arch=compute_52,code=compute_52

SHARE_LIB_OPT=

MAC_OS_LOCAL_FOLDER=

LIB_RAW_NAME=libyolo
SLIB=
SLIB_DIR=

ALIB=libyolo.a
ALIB_DIR=$(addprefix yolo/, $(ALIB))

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
	SHARE_LIB_OPT += -shared
     SLIB=$(addprefix $(LIB_RAW_NAME),.so)
     OPENMP=$(shell ldconfig -p | grep gomp > /dev/null 2> /dev/null && echo 1 || echo 0)
endif
ifeq ($(UNAME_S),Darwin)
	SHARE_LIB_OPT += -dynamiclib
	MAC_OS_LOCAL_FOLDER=local/
     SLIB=$(addprefix $(LIB_RAW_NAME),.dylib)
endif

SLIB_DIR=$(addprefix yolo/, $(SLIB))

ROOT=
#ifeq ($(shell id -u), 0)
#     ROOT=sudo
#endif

OBJDIR=./obj/
VPATH=./darknet/src/:./yolo/src/:./stack/

CC=gcc
CPP=g++
AR=ar
ARFLAGS=rcs
OPTS=
LDFLAGS= -lm -pthread
COMMON= -I./darknet/include/ -I./darknet/src/
CFLAGS=-Wall -Wno-unused-result -Wno-unknown-pragmas -Wfatal-errors -fPIC

ifeq ($(OPENMP), 1)
CFLAGS+= -fopenmp
endif

ifeq ($(DEBUG), 1)
OPTS+=-O0 -g
else
OPTS+=-Ofast
endif

CFLAGS+=$(OPTS)

ifeq ($(OPENCV), 1)
COMMON+= -DOPENCV
CFLAGS+= -DOPENCV
LDFLAGS+= `pkg-config --libs opencv` -lstdc++
COMMON+= `pkg-config --cflags opencv`
endif

ifeq ($(GPU), 1)
COMMON+= -DGPU -I/usr/local/cuda/include/
CFLAGS+= -DGPU
LDFLAGS+= -L/usr/local/cuda/lib64 -L/usr/lib/x86_64-linux-gnu/ -lcuda -lcudart -lcublas -lcurand
endif

ifeq ($(CUDNN), 1)
COMMON+= -DCUDNN
CFLAGS+= -DCUDNN
LDFLAGS+= -lcudnn
endif

OBJ=libyolo.o yolo_error.o gemm.o utils.o cuda.o deconvolutional_layer.o convolutional_layer.o list.o image.o activations.o im2col.o col2im.o blas.o crop_layer.o dropout_layer.o maxpool_layer.o softmax_layer.o data.o matrix.o network.o connected_layer.o cost_layer.o parser.o option_list.o detection_layer.o route_layer.o upsample_layer.o box.o normalization_layer.o avgpool_layer.o layer.o local_layer.o shortcut_layer.o logistic_layer.o activation_layer.o rnn_layer.o gru_layer.o crnn_layer.o demo.o batchnorm_layer.o region_layer.o reorg_layer.o tree.o  lstm_layer.o l2norm_layer.o yolo_layer.o iseg_layer.o image_opencv.o
EXECOBJA=captcha.o lsd.o super.o art.o tag.o cifar.o go.o rnn.o segmenter.o regressor.o classifier.o coco.o yolo.o detector.o nightmare.o instance-segmenter.o darknet.o
ifeq ($(GPU), 1)
LDFLAGS+= -lstdc++
OBJ+=convolutional_kernels.o deconvolutional_kernels.o activation_kernels.o im2col_kernels.o col2im_kernels.o blas_kernels.o crop_layer_kernels.o dropout_layer_kernels.o maxpool_layer_kernels.o avgpool_layer_kernels.o
endif

EXECOBJ = $(addprefix $(OBJDIR), $(EXECOBJA))
OBJS = $(addprefix $(OBJDIR), $(OBJ))
DEPS = $(wildcard src/*.h) Makefile ./darknet/include/darknet.h

all: obj $(SLIB_DIR) $(ALIB_DIR)
#all: obj  results $(SLIB) $(ALIB) $(EXEC)

$(EXEC): $(EXECOBJ) $(ALIB)
	$(ROOT) $(CC) $(COMMON) $(CFLAGS) $^ -o $@ $(LDFLAGS) $(ALIB)

$(ALIB_DIR): $(OBJS)
	$(ROOT) $(AR) $(ARFLAGS) $@ $^

$(SLIB_DIR): $(OBJS)
	$(ROOT) $(CC) $(CFLAGS) -shared $^ -o $@ $(LDFLAGS)

$(OBJDIR)%.o: %.cpp $(DEPS)
	$(ROOT) $(CPP) $(COMMON) $(CFLAGS) -std=c++17 -c $< -o $@

$(OBJDIR)%.o: %.c $(DEPS)
	$(ROOT) $(CC) $(COMMON) $(CFLAGS) -c $< -o $@

$(OBJDIR)%.o: %.cu $(DEPS)
	$(ROOT) $(NVCC) $(ARCH) $(COMMON) --compiler-options "$(CFLAGS)" -c $< -o $@

obj:
	$(ROOT) mkdir -p obj
backup:
	mkdir -p backup
results:
	mkdir -p results

.PHONY: clean

clean_all: clean
	$(ROOT) rm -rf $(SLIB_DIR) $(ALIB_DIR)

clean:
	$(ROOT) rm -rf obj
