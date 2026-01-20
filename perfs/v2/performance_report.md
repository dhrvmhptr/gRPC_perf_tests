# gRPC Server Performance Report: V2 Analysis

## Load Test Comparison (ghz benchmark)

| Metric           | V1       | V2       | Improvement         |
| ---------------- | -------- | -------- | ------------------- |
| Total Requests   | 300,000  | 300,000  | -                   |
| Requests/sec     | 4999.55  | 4999.61  | ~same               |
| Average Latency  | 5.94 ms  | 4.98 ms  | **16.2% faster**        |
| Fastest Response | 0.45 ms  | 0.41 ms  | **8.9% faster**         |
| Slowest Response | 29.10 ms | 36.29 ms | -24.7% (worse tail) |

### Latency Distribution Improvements

| Percentile | V1       | V2       | Improvement      |
| ---------- | -------- | -------- | ---------------- |
| P10        | 0.79 ms  | 0.72 ms  | **8.9% faster**      |
| P25        | 1.11 ms  | 1.00 ms  | **9.9% faster**      |
| P50        | 5.39 ms  | 3.79 ms  | **29.7% faster**     |
| P75        | 10.90 ms | 8.69 ms  | **20.3% faster**     |
| P90        | 12.05 ms | 11.44 ms | **5.1% faster**      |
| P95        | 12.68 ms | 12.23 ms | **3.5% faster**      |
| P99        | 16.31 ms | 14.20 ms | **12.9% faster**     |

### Response Distribution Analysis

**V1 Histogram:**

- 0.45-3.32 ms: 134,193 requests (44.7%)
- 3.32-6.18 ms: 24,467 requests (8.2%)
- 6.18-11.91 ms: 104,014 requests (34.7%)
- > 11.91 ms: 36,325 requests (12.1%)

**V2 Histogram:**

- 0.41-4.00 ms: 153,048 requests (51.0%) **+6.3% more fast requests**
- 4.00-7.58 ms: 55,921 requests (18.6%)
- 7.58-14.76 ms: 89,453 requests (29.8%)
- > 14.76 ms: 1,577 requests (0.5%) **massive reduction in slow requests**
---

## CPU Subsystem Breakdown Comparison

| Subsystem            | V1    | V2    | Change    |
| -------------------- | ----- | ----- | --------- |
| Event Engine Threads | 66.9% | 63.6% | **-3.3%**     |
| Call Destruction     | 32.2% | 34.5% | +2.3%     |
| CallData Lifecycle   | 26.9% | 28.5% | +1.6%     |
| Request Handling     | 24.2% | 26.0% | +1.8%     |
| Lock Operations      | 10.5% | 11.1% | +0.6%     |
| Debug Lock Graph     | 6.2%  | 5.1%  | **-1.1%**     |
| CQ Polling (cq_next) | 2.2%  | 3.8%  | +1.6%     |
| epoll_wait (I/O)     | 1.4%  | 0.9%  | **-0.5%**     |

---

## Lock Contention Analysis

| Lock Type           | V1    | V2     | Change     |
| ------------------- | ----- | ------ | ---------- |
| Mutex Operations    | 10.4% | 11.07% | +0.67%     |
| SpinLock Operations | 2.3%  | 1.81%  | **-0.49%**     |
| Futex Operations    | 2.1%  | 3.90%  | +1.8%      |
| Deadlock Checking   | 3.11% | 2.66%  | **-0.45%**     |
| Lock Graph Tracking | 2.89% | 2.59%  | **-0.30%**     |
| Debug Lock Overhead | 3.15% | 2.31%  | **-0.84%**     |

Total debug lock overhead reduced from ~9.16% to ~7.56%.

---

## Memory & Allocation Metrics

| Metric               | V1    | V2     | Change     |
| -------------------- | ----- | ------ | ---------- |
| Arena Allocations    | 26.7% | 27.44% | +0.74%     |
| Memory Operations    | 2.9%  | 2.92%  | ~same      |
| Thread Pool Overhead | 66.8% | 63.59% | **-3.21%** |

---

## Network I/O Metrics

| Operation        | V1    | V2    | Change     |
| ---------------- | ----- | ----- | ---------- |
| TCP Operations   | 4.37% | 3.27% | **-1.1%**  |
| sendmsg          | 1.46% | 1.10% | **-0.36%** |
| epoll_wait       | 1.47% | 0.9%  | **-0.57%** |
| Syscall Overhead | 3.7%  | 6.72% | +3.02%     |

---

## RPC Lifecycle Metrics

| Phase           | V1     | V2     | Change                       |
| --------------- | ------ | ------ | ---------------------------- |
| RPC Creation    | 3.92%  | 0.72%  | **-3.2% (huge improvement)**     |
| RPC Processing  | 26.96% | 28.42% | +1.46%                       |
| RPC Completion  | 26.33% | 28.62% | +2.29%                       |
| RPC Destruction | 3.90%  | 4.24%  | +0.34%                       |

---

## Key Improvements Achieved in V2

1. **Profiling Visibility**: From many unknown stack frames to only 6 - enabling proper performance analysis
2. **Median Latency (P50)**: 29.7% improvement (5.39ms -> 3.79ms)
3. **P99 Tail Latency**: 12.9% improvement (16.31ms -> 14.20ms)
4. **Event Engine Overhead**: Reduced by 3.3%
5. **Thread Pool Overhead**: Reduced by 3.21%
6. **RPC Creation Cost**: Reduced by 3.2% of total CPU
7. **I/O Efficiency**: TCP operations down 1.1%, epoll_wait down 0.57%
8. **SpinLock Contention**: Reduced by 0.49%
9. **Debug Lock Overhead**: Reduced by ~1.6% total

---

## To try in v3

- there's still a threadpool overhead of 63.59% so let's try a worker pool or something to ease it up
- each RPC completion is 28.62% and arena allocation is 27.44%. maybe we can reduce these
- Call Destruction takes 34.5% so should probably move away from repeated allo/dealloc
- mutex ops are quite high as well, lock-free queues?
-
