# gRPC Server Performance Report

| Metric               | Value                |
| -------------------- | -------------------- |
| Total CPU Samples    | 352.6 billion cycles |
| Main Server Thread   | 33.0% of CPU         |
| Event Engine Threads | 67.0% of CPU         |
| Server Thread Stacks | 2,815                |
| Event Engine Stacks  | 5,358                |

---

## 1. Thread Utilization Breakdown

| Thread Type               | Samples         | Percentage |
| ------------------------- | --------------- | ---------- |
| Main Server Thread        | 116,534,300,815 | 33.0%      |
| Event Engine (Background) | 236,075,621,546 | 67.0%      |
| Other                     | 0               | 0.0%       |

---

## 2. Subsystem CPU Breakdown

| Subsystem            | Samples         | % of Total |
| -------------------- | --------------- | ---------- |
| Event Engine Threads | 236,075,621,546 | 66.9%      |
| Call Destruction     | 113,663,175,116 | 32.2%      |
| CallData Lifecycle   | 95,192,252,636  | 26.9%      |
| Request Handling     | 85,563,615,064  | 24.2%      |
| Lock Operations      | 37,168,948,886  | 10.5%      |
| Debug Lock Graph     | 22,052,942,082  | 6.2%       |
| CQ Polling (cq_next) | 7,936,101,060   | 2.2%       |
| epoll_wait (I/O)     | 5,195,676,411   | 1.4%       |

---

## 3. Lock Contention & Synchronization

### 3.1 Lock Operation Summary

| Lock Type               | Samples           | % of Total |
| ----------------------- | ----------------- | ---------- |
| Mutex Operations        | 36,886,384,396    | 10.4%      |
| SpinLock Operations     | 8,329,892,504     | 2.3%       |
| Futex Operations        | 7,507,210,257     | 2.1%       |
| **Total Lock Overhead** | **~52.7 billion** | **~14.9%** |

### 3.2 Debug Lock Overhead (Development Build)

| Operation                     | Samples            | % of Total |
| ----------------------------- | ------------------ | ---------- |
| Debug Lock Leave/Enter        | 11,110,714,565     | 3.15%      |
| Deadlock Checking             | 10,985,576,388     | 3.11%      |
| Lock Graph Tracking           | 10,212,870,797     | 2.89%      |
| **Total Debug Lock Overhead** | **32,309,161,750** | **9.16%**  |

---

## 4. Completion Queue Metrics

| Operation             | Samples            | % of Total |
| --------------------- | ------------------ | ---------- |
| cq_next               | 7,936,101,060      | 2.25%      |
| Pollset Work          | 4,873,394,928      | 1.38%      |
| CQ Pop Operations     | 1,726,409,710      | 0.48%      |
| CQ Push Operations    | 1,361,673,329      | 0.38%      |
| **Total CQ Overhead** | **15,897,579,027** | **4.51%**  |

---

## 5. Network I/O Metrics

| Operation                   | Samples           | % of Total |
| --------------------------- | ----------------- | ---------- |
| TCP Operations (Flush/Send) | 15,427,221,360    | 4.37%      |
| sendmsg                     | 5,156,893,048     | 1.46%      |
| epoll_wait                  | 5,195,676,411     | 1.47%      |
| write                       | 822,698,752       | 0.23%      |
| read                        | 0                 | 0.00%      |
| **Total I/O**               | **~26.6 billion** | **~7.5%**  |

---

## 6. RPC Lifecycle Breakdown

| Phase                    | Samples             | % of Total |
| ------------------------ | ------------------- | ---------- |
| RPC Processing (Proceed) | 95,096,131,239      | 26.96%     |
| RPC Completion (Finish)  | 92,843,197,635      | 26.33%     |
| RPC Creation             | 13,844,231,127      | 3.92%      |
| RPC Destruction          | 13,754,891,807      | 3.90%      |
| **Total RPC Lifecycle**  | **215,538,451,808** | **61.1%**  |

---

## 7. Memory & Allocation Metrics

| Operation                       | Samples         | % of Total |
| ------------------------------- | --------------- | ---------- |
| Arena Allocations               | 94,414,518,063  | 26.7%      |
| Memory Operations (malloc/free) | 10,377,049,257  | 2.9%       |
| Thread Pool Overhead            | 235,823,072,360 | 66.8%      |

---

## 8. Syscall Overhead

| Category               | Samples        | % of Total |
| ---------------------- | -------------- | ---------- |
| Total Syscall Overhead | 13,274,427,154 | 3.7%       |

---

## 9. Top 20 Hot Paths

| Rank | Samples     | Path                                                                                                          |
| ---- | ----------- | ------------------------------------------------------------------------------------------------------------- |
| 1    | 251,875,969 | [unknown] -> [unknown] -> [unknown] -> [unknown]                                                              |
| 2    | 248,734,202 | CompletionQueue::Next -> AsyncNextInternal -> grpc_completion_queue_next -> cq_next                           |
| 3    | 228,842,309 | [unknown] -> [unknown] -> [unknown] -> [unknown]                                                              |
| 4    | 176,902,451 | main -> AsyncServer::Run -> HandleRpcs -> CallData::Proceed                                                   |
| 5    | 169,778,716 | CallDataFilterWithFlagsMethods -> DestructCallData -> CallData -> ServerCallData::~ServerCallData             |
| 6    | 167,222,980 | grpc_call_stack_destroy -> CallDataFilterWithFlagsMethods -> DestructCallData -> CallData                     |
| 7    | 166,151,058 | cq_next -> PopAndCheckEnd -> Push -> atomic<Node\*>::store                                                    |
| 8    | 164,388,559 | GetGraphId -> SpinLock::Lock -> TryLockImpl -> TryLockInternal                                                |
| 9    | 158,956,459 | BeginCompletionOp -> Call::PerformOps -> PerformOpsOnCall -> CompletionOp::FillOps                            |
| 10   | 158,279,531 | grpc_completion_queue_next -> cq_next -> PopAndCheckEnd -> atomic<Node\*>::load                               |
| 11   | 153,451,239 | FilterStackCall::DestroyCall -> grpc_call_stack_destroy -> CallDataFilterWithFlagsMethods -> DestructCallData |
| 12   | 150,679,565 | cq_next -> grpc_pollset_work -> pollset_work -> pollset_work                                                  |
| 13   | 148,347,789 | grpc_call_start_batch -> ExecCtx::~ExecCtx -> ExecCtx::Flush -> exec_ctx_run                                  |
| 14   | 147,972,301 | AsyncServer::Run -> HandleRpcs -> CompletionQueue::Next -> AsyncNextInternal                                  |
| 15   | 145,317,480 | HandleRpcs -> CallData::Proceed -> ServerAsyncResponseWriter::Finish -> ServerSendStatus                      |

---

## 10. Event Engine Thread Analysis

**Top stacks in event_engine threads:**

| Samples    | Stack Path                                        |
| ---------- | ------------------------------------------------- |
| 81,261,574 | syscall -> [unknown]                              |
| 45,829,857 | WorkStealingThreadPool::StartThread -> ThreadBody |
| 43,653,135 | epoll_wait -> [unknown]                           |
| 40,307,661 | ThreadBody -> busy_thread_count                   |
| 36,868,988 | **GI\_**libc_write -> [unknown]                   |
| 32,957,440 | ThreadBody -> WorkSignal::WaitWithTimeout         |
| 31,178,633 | ReceiveMessage::OnComplete -> **GI\_**libc_write  |
| 30,243,050 | TcpSend -> \_\_libc_sendmsg                       |
| 29,343,806 | FutexWaiter::Post -> syscall                      |
| 27,771,835 | ThreadBody -> IsForking                           |

---

## 11. Server Main Thread Analysis

**Top stacks in server main thread:**

| Samples     | Stack Path                                                     |
| ----------- | -------------------------------------------------------------- |
| 251,875,969 | [unknown] (likely kernel/scheduler)                            |
| 248,734,202 | HandleRpcs -> CompletionQueue::Next -> cq_next                 |
| 228,842,309 | [unknown] (likely kernel/scheduler)                            |
| 176,902,451 | main -> AsyncServer::Run -> HandleRpcs -> CallData::Proceed    |
| 169,778,716 | grpc_call_stack_destroy -> DestructCallData -> ~ServerCallData |
| 167,222,980 | FilterStackCall::DestroyCall -> grpc_call_stack_destroy        |
| 166,151,058 | cq_next -> MultiProducerSingleConsumerQueue operations         |
| 164,388,559 | DebugOnlyLockLeave -> GetGraphId -> SpinLock::Lock             |
| 158,956,459 | FinalizeResult -> BeginCompletionOp -> PerformOps              |
| 158,279,531 | AsyncNextInternal -> cq_next -> PopAndCheckEnd                 |

---

## 12. Top Leaf Functions (Where CPU Actually Spends Time)

| Count | Function                              |
| ----- | ------------------------------------- |
| 331   | [unknown]                             |
| 126   | std::\_\_is_constant_evaluated        |
| 123   | std::atomic<bool>::load               |
| 89    | absl::Status::Status                  |
| 87    | grpc_core::BitSet<36ul, 16ul>::is_set |
| 75    | std::operator&                        |
| 54    | operator new                          |
| 54    | grpc_core::TraceFlag::enabled         |
| 45    | malloc                                |
| 43    | absl::SpinLock::TryLockInternal       |

---

# Performance Analysis & Recommendations

## Key Findings

### 1. in table 10: Thread Pool Dominance (66.8% CPU)

The WorkStealingThreadPool in event_engine threads consumes the majority of CPU time. This includes:

TODO: from the finding1. ---> we could try to tune the thread pool size or investigate if work stealing is causing excessive contention.

### 2. in table 9 and 11: High Call Destruction Overhead

a big chunk of cpu cycles are spent in destroying.

RPC call destruction (`DestroyCall`, `grpc_call_stack_destroy`, destructors) represents nearly a third of CPU usage.

TODO: from finding2 --> we could investigate object pooling for CallData objects; profile memory allocation patterns in call lifecycle

### 3. in table 11: Debug Lock Overhead

Debug lock instrumentation (`DebugOnlyLockLeave`, deadlock checking, lock graph tracking) consumes significant CPU.

TODO: I did build with -DBDEBUG. maybe we'll need to disable ABSL debug lock features.

### 4. in table 3.1: Lock Contention

Combined mutex, spinlock, and futex operations represent significant overhead:

- Mutex: 10.4%
- SpinLock: 2.3%
- Futex: 2.1%

TODO: can we have a lock-free data structures in a inference server? i mean, there's no write o the db right? maybe not right now, but if we want to maintain state of the convos, I guess then yes, then mutexes would be needed, but let's investigate

- profiling lock contention hotspots could help. but i think these are internal things, nothing might come here, but worth a shot.
- also review CQ locking strategy. let's see

### 5. Completion Queue Efficiency

TODO: CQ doesn't need that much, as it's only being used for 2.2% of the cpu cycle, so optimization won't make much of difference in the whole. async queues maybe? batch processing maybe? i tried addinng more rps and it increased latency tremendously, so definitely multi-threaded CQs need to be implemented.

### 6. Significant [unknown] Stack Frames

Multiple top hot paths show `[unknown]` frames, indicating:

- Missing debug symbols
- Kernel time not fully resolved
- JIT or dynamically generated code

TODO:

This by far is what is consuming the most CPU time and we have no visibility into this. did a bit research and they suggested:

- Build with `-fno-omit-frame-pointer`
- Include debug symbols (`-g`)
- Use `perf record -g dwarf` for better stack unwinding

so will do these in v2
