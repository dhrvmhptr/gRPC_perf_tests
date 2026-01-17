#include <grpcpp/grpcpp.h>
#include "protos/inference.grpc.pb.h"
#include <memory>
#include <string>

using grpc::Server;
using grpc::ServerBuilder;
using grpc::ServerCompletionQueue;
using grpc::ServerContext;
using grpc::Status;
using inference::InferenceService;
using inference::PredictRequest;
using inference::PredictResponse;

class CallData
{
public:
  CallData(InferenceService::AsyncService *service,
           ServerCompletionQueue *cq)
      : service_(service), cq_(cq), responder_(&ctx_), state_(CREATE)
  {
    Proceed();
  }

  void Proceed()
  {
    if (state_ == CREATE)
    {
      state_ = PROCESS;
      service_->RequestPredict(&ctx_, &request_, &responder_, cq_, cq_, this);
    }
    else if (state_ == PROCESS)
    {
      new CallData(service_, cq_); // accept next request

      std::string out = "stub_output_size=" +
                        std::to_string(request_.input().size());
      response_.set_output(out);

      state_ = FINISH;
      responder_.Finish(response_, Status::OK, this);
    }
    else
    {
      delete this;
    }
  }

private:
  InferenceService::AsyncService *service_;
  ServerCompletionQueue *cq_;
  ServerContext ctx_;

  PredictRequest request_;
  PredictResponse response_;
  grpc::ServerAsyncResponseWriter<PredictResponse> responder_;

  enum State
  {
    CREATE,
    PROCESS,
    FINISH
  };
  State state_;
};

class AsyncServer
{
public:
  void Run()
  {
    std::string addr("0.0.0.0:50051");

    ServerBuilder builder;
    builder.AddListeningPort(addr, grpc::InsecureServerCredentials());
    builder.RegisterService(&service_);
    cq_ = builder.AddCompletionQueue();
    server_ = builder.BuildAndStart();

    HandleRpcs();
  }

private:
  void HandleRpcs()
  {
    new CallData(&service_, cq_.get());
    void *tag;
    bool ok;

    while (cq_->Next(&tag, &ok))
    {
      static_cast<CallData *>(tag)->Proceed();
    }
  }

  InferenceService::AsyncService service_;
  std::unique_ptr<ServerCompletionQueue> cq_;
  std::unique_ptr<Server> server_;
};

int main()
{
  AsyncServer server;
  server.Run();
}
