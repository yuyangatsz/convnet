##################################
# Set path to dependencies.
# Path to protocol buffers, hdf5.
INC=$(HOME)/local/include
LIB=$(HOME)/local/lib
LOCAL_BIN = $(HOME)/local/bin

# CUDA.
CUDA_INC=/pkgs_local/cuda-5.5/include
CUDA_LIB=/pkgs_local/cuda-5.5/lib64
#####################################

#CXX = g++ -g -rdynamic
CXX = g++
NVCC = nvcc

LIBFLAGS = -L$(LIB) -L$(CUDA_LIB)
CPPFLAGS = -I$(INC) -I$(CUDA_INC) -I$(SRC) -Ideps
LINKFLAGS = -lhdf5 -ljpeg -lX11 -lpthread -lprotobuf -lcublas -ldl -lgomp
CXXFLAGS = -O2 -std=c++0x -mtune=native -Wall -Wno-unused-result -Wno-sign-compare -fopenmp

SRC=src
OBJ=obj
BIN=bin

EDGES_SRC := $(wildcard $(SRC)/*_edge.cc)
EDGES_OBJS := $(OBJ)/edge.o $(OBJ)/edge_with_weight.o $(patsubst $(SRC)/%.cc, $(OBJ)/%.o, $(EDGES_SRC)) $(OBJ)/optimizer.o
DATAHANDLER_SRC := $(SRC)/image_iterators.cc $(SRC)/datahandler.cc $(SRC)/datawriter.cc
DATAHANDLER_OBJS := $(OBJ)/image_iterators.o $(OBJ)/datahandler.o $(OBJ)/datawriter.o
CUDA_OBJS := $(OBJ)/matrix.o $(OBJ)/cudamat.o $(OBJ)/cudamat_kernels.o $(OBJ)/cudamat_conv.o $(OBJ)/cudamat_conv_kernels.o
COMMONOBJS = $(OBJ)/convnet_config.pb.o $(DATAHANDLER_OBJS) $(OBJ)/layer.o $(OBJ)/util.o $(CUDA_OBJS) $(EDGES_OBJS)
TARGETS := $(BIN)/train_convnet $(BIN)/run_grad_check $(BIN)/extract_representation $(BIN)/jpeg2hdf5

all : $(OBJ)/convnet_config.pb.o $(TARGETS)

$(BIN)/train_convnet: $(COMMONOBJS) $(OBJ)/convnet.o  $(OBJ)/train_convnet.o $(OBJ)/multigpu_convnet.o
	$(NVCC) $(LIBFLAGS) $(CPPFLAGS) $^ -o $@ $(LINKFLAGS)

$(BIN)/extract_representation: $(COMMONOBJS) $(OBJ)/convnet.o $(OBJ)/multigpu_convnet.o $(OBJ)/extract_representation.o 
	$(NVCC) $(LIBFLAGS) $(CPPFLAGS) $^ -o $@ $(LINKFLAGS)

$(BIN)/run_grad_check: $(COMMONOBJS) $(OBJ)/convnet.o $(OBJ)/grad_check.o $(OBJ)/run_grad_check.o
	$(NVCC) $(LIBFLAGS) $(CPPFLAGS) $^ -o $@ $(LINKFLAGS)

$(BIN)/compute_mean: $(COMMONOBJS) $(OBJ)/compute_mean.o
	$(NVCC) $(LIBFLAGS) $(CPPFLAGS) $^ -o $@ $(LINKFLAGS)

$(BIN)/jpeg2hdf5: $(OBJ)/image_iterators.o $(OBJ)/jpeg2hdf5.o
	$(NVCC) $(LIBFLAGS) $(CPPFLAGS) $^ -o $@ $(LINKFLAGS)

$(OBJ)/matrix.o: $(SRC)/matrix.cc $(SRC)/matrix.h
	$(NVCC) -c $(CPPFLAGS) --compiler-options="$(CXXFLAGS)" $< -o $@

$(OBJ)/cuda%.o: $(SRC)/cuda%.cu $(SRC)/cuda%.cuh
	$(NVCC) -c -O2 --use_fast_math -gencode=arch=compute_20,code=sm_20 -gencode=arch=compute_30,code=sm_30 -gencode=arch=compute_35,code=sm_35 $< -o $@

$(OBJ)/%.o: $(SRC)/%.cc $(SRC)/%.h
	$(CXX) -c $(CPPFLAGS) $(CXXFLAGS) $< -o $@

$(OBJ)/%.o: $(SRC)/%.cc
	$(CXX) -c $(CPPFLAGS) $(CXXFLAGS) $< -o $@

$(OBJ)/convnet_config.pb.o : proto/convnet_config.proto
	$(LOCAL_BIN)/protoc -I=proto --cpp_out=$(SRC) --python_out=$(SRC) proto/convnet_config.proto
	$(CXX) -c $(CPPFLAGS) $(CXXFLAGS) $(SRC)/convnet_config.pb.cc -o $@

clean:
	rm -rf $(OBJ)/*.o $(TARGETS) $(SRC)/convnet_config.pb.*
