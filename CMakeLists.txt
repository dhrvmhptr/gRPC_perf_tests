cmake_minimum_required(VERSION 3.16)
project(GrpcInference)

include(cmake/common.cmake)
find_package(absl REQUIRED)

include_directories(${CMAKE_CURRENT_SOURCE_DIR})

add_executable(server async_server.cc protos/inference.pb.cc protos/inference.grpc.pb.cc)
target_link_libraries(server ${_GRPC_GRPCPP} ${_PROTOBUF_LIBPROTOBUF})

add_executable(client async_client.cc protos/inference.pb.cc protos/inference.grpc.pb.cc)
target_link_libraries(client
    ${_GRPC_GRPCPP}
    ${_PROTOBUF_LIBPROTOBUF}
    absl::flags
    absl::flags_parse
)

