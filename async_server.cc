#include <grpcpp/grpcpp.h>
#include "protos/inference.grpc.pb.h"
#include <thread>
#include <memory>
#include <vector>
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
      new CallData(service_, cq_); // re-arm immediately

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
  void Run(int num_threads)
  {
    std::string addr("0.0.0.0:50051");

    ServerBuilder builder;
    builder.AddListeningPort(addr, grpc::InsecureServerCredentials());
    builder.RegisterService(&service_);

    for (int i = 0; i < num_threads; ++i) {
      cqs_.emplace_back(builder.AddCompletionQueue());  // One CQ per thread
    }

    server_ = builder.BuildAndStart();

    for (int i = 0; i < num_threads; ++i) {
      workers_.emplace_back(&AsyncServer::HandleRpcs, this, i);
    }

    for (auto& w : workers_) w.join();
  }

private:
  void HandleRpcs(int thread_idx)
  {
    ServerCompletionQueue* cq = cqs_[thread_idx].get();

    // Seed this thread's CQ with initial CallData
    new CallData(&service_, cq);

    void *tag;
    bool ok;

    while (cq->Next(&tag, &ok))
    {
      if (ok) {
        static_cast<CallData *>(tag)->Proceed();
      }
    }
  }

  InferenceService::AsyncService service_;
  std::vector<std::unique_ptr<ServerCompletionQueue>> cqs_; 
  std::unique_ptr<Server> server_;
  std::vector<std::thread> workers_;
};

int main()
{
  AsyncServer server;
  server.Run(std::thread::hardware_concurrency());
}
