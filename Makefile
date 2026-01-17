PROTO      = inference.proto
PROTO_DIR  = .
GEN_DIR    = ./protos

PROTOC     = protoc
GRPC_CPP   = grpc_cpp_plugin

PB_SRC     = $(GEN_DIR)/inference.pb.cc
PB_HDR     = $(GEN_DIR)/inference.pb.h
GRPC_SRC   = $(GEN_DIR)/inference.grpc.pb.cc
GRPC_HDR   = $(GEN_DIR)/inference.grpc.pb.h

all: proto

proto: $(PB_SRC) $(GRPC_SRC)

$(PB_SRC) $(PB_HDR): $(PROTO)
	$(PROTOC) -I $(PROTO_DIR) --cpp_out=$(GEN_DIR) $<

$(GRPC_SRC) $(GRPC_HDR): $(PROTO)
	$(PROTOC) -I $(PROTO_DIR) \
	  --grpc_out=$(GEN_DIR) \
	  --plugin=protoc-gen-grpc=`which $(GRPC_CPP)` \
	  $<

clean:
	rm -f $(PB_SRC) $(PB_HDR) $(GRPC_SRC) $(GRPC_HDR)

.PHONY: all proto clean

