#include <grpcpp/grpcpp.h>
#include "protos/inference.grpc.pb.h"
#include <iostream>

#include "absl/flags/flag.h"
#include "absl/flags/parse.h"

using grpc::ClientContext;
using grpc::CompletionQueue;
using grpc::Status;
using inference::InferenceService;
using inference::PredictRequest;
using inference::PredictResponse;

ABSL_FLAG(std::string, target, "hey this is a dummy input", "input to the inference server");

int main(int argc, char **argv)
{
  absl::ParseCommandLine(argc, argv);
  std::string target_str = absl::GetFlag(FLAGS_target);

  auto channel = grpc::CreateChannel(
      "localhost:50051", grpc::InsecureChannelCredentials());
  auto stub = InferenceService::NewStub(channel);

  CompletionQueue cq;
  ClientContext ctx;

  PredictRequest req;
  req.set_input(target_str);

  PredictResponse resp;
  Status status;

  auto rpc = stub->AsyncPredict(&ctx, req, &cq);
  rpc->Finish(&resp, &status, (void *)1);

  void *tag;
  bool ok;
  cq.Next(&tag, &ok);

  if (ok && status.ok())
  {
    std::cout << "Response: " << resp.output() << std::endl;
  }
  else
  {
    std::cerr << "RPC failed\n";
  }
}
