#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <out.folded> [output_report.txt]"
    echo "Example: $0 out.folded report.txt"
    exit 1
fi

FOLDED="$1"
OUTPUT="${2:-performance_report.txt}"

if [ ! -f "$FOLDED" ]; then
    echo "Error: File '$FOLDED' not found"
    exit 1
fi

# Calculate total samples once
TOTAL=$(awk '{sum += $NF} END {print sum}' "$FOLDED")

pct() {
    local val=$1
    echo "scale=2; $val * 100 / $TOTAL" | bc
}

{
echo "=============================================="
echo "     PERFORMANCE ANALYSIS REPORT"
echo "=============================================="
echo "Source: $FOLDED"
echo "Generated: $(date)"
echo "Total samples: $TOTAL"
echo ""

# ============================================
# 1. TOP LEAF FUNCTIONS
# ============================================
echo "=============================================="
echo "1. TOP 20 LEAF FUNCTIONS (where CPU actually spends time)"
echo "=============================================="
echo ""
sed 's/ [0-9]*$//' "$FOLDED" | rev | cut -d';' -f1 | rev | sort | uniq -c | sort -rn | head -20 | while read count func; do
    printf "%12d  %s\n" "$count" "$func"
done
echo ""

# ============================================
# 2. SUBSYSTEM BREAKDOWN
# ============================================
echo "=============================================="
echo "2. SUBSYSTEM BREAKDOWN"
echo "=============================================="
echo ""

epoll=$(grep -E 'epoll_wait' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')
debug=$(grep -E 'DebugOnlyLockLeave|DebugOnlyDeadlockCheck|GetGraphId|ForgetDeadlockInfo' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')
cq=$(grep -E 'cq_next|pollset_work|grpc_pollset_work' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')
proceed=$(grep -E 'CallData::Proceed|CallData::~CallData|CallData::CallData' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')
finalize=$(grep -E 'FinalizeResult|BeginCompletionOp|PerformOps' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')
destroy=$(grep -E 'DestroyCall|grpc_call_unref|FilterStackCall' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')
locks=$(grep -E 'Mutex::|SpinLock::|gpr_mu' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')
ee=$(grep -E '^event_engine' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')

printf "%-30s %15d (%5.1f%%)\n" "epoll_wait (I/O):" "$epoll" "$(pct $epoll)"
printf "%-30s %15d (%5.1f%%)\n" "Debug lock graph:" "$debug" "$(pct $debug)"
printf "%-30s %15d (%5.1f%%)\n" "CQ polling (cq_next):" "$cq" "$(pct $cq)"
printf "%-30s %15d (%5.1f%%)\n" "CallData lifecycle:" "$proceed" "$(pct $proceed)"
printf "%-30s %15d (%5.1f%%)\n" "Request handling:" "$finalize" "$(pct $finalize)"
printf "%-30s %15d (%5.1f%%)\n" "Call destruction:" "$destroy" "$(pct $destroy)"
printf "%-30s %15d (%5.1f%%)\n" "Lock operations:" "$locks" "$(pct $locks)"
printf "%-30s %15d (%5.1f%%)\n" "Event engine threads:" "$ee" "$(pct $ee)"
echo ""

# ============================================
# 3. THREAD DISTRIBUTION
# ============================================
echo "=============================================="
echo "3. THREAD DISTRIBUTION"
echo "=============================================="
echo ""

server_total=$(grep '^server;' "$FOLDED" 2>/dev/null | awk '{sum+=$NF} END {print sum+0}')
ee_total=$(grep '^event_engine' "$FOLDED" 2>/dev/null | awk '{sum+=$NF} END {print sum+0}')
other=$((TOTAL - server_total - ee_total))

printf "%-30s %15d (%5.1f%%)\n" "Main server thread:" "$server_total" "$(pct $server_total)"
printf "%-30s %15d (%5.1f%%)\n" "Event engine threads:" "$ee_total" "$(pct $ee_total)"
printf "%-30s %15d (%5.1f%%)\n" "Other:" "$other" "$(pct $other)"
echo ""

# ============================================
# 4. TOP 15 HOT PATHS
# ============================================
echo "=============================================="
echo "4. TOP 15 HOT PATHS (by sample count)"
echo "=============================================="
echo ""

sort -t' ' -k2 -rn "$FOLDED" | head -15 | awk -v total="$TOTAL" '{
    samples = $NF
    gsub(/ [0-9]+$/, "")
    n = split($0, f, ";")
    path = ""
    start = n - 3
    if (start < 1) start = 1
    for (i = start; i <= n; i++) {
        if (path != "") path = path " -> "
        path = path f[i]
    }
    gsub(/grpc_core::/, "", path)
    gsub(/absl::lts_[0-9]+::/, "", path)
    gsub(/grpc_event_engine::experimental::/, "", path)
    gsub(/grpc::/, "", path)
    pct = samples * 100 / total
    printf "%5.2f%% %12d  %s\n", pct, samples, path
}'
echo ""

# ============================================
# 5. EVENT ENGINE THREAD ANALYSIS
# ============================================
echo "=============================================="
echo "5. EVENT ENGINE THREAD ANALYSIS (Top 10)"
echo "=============================================="
echo ""

grep '^event_engine' "$FOLDED" 2>/dev/null | sort -t' ' -k2 -rn | head -10 | awk '{
    samples = $NF
    gsub(/ [0-9]+$/, "")
    n = split($0, f, ";")
    path = ""
    start = n - 4
    if (start < 1) start = 1
    for (i = start; i <= n; i++) {
        if (path != "") path = path ";"
        path = path f[i]
    }
    gsub(/grpc_core::/, "", path)
    gsub(/absl::lts_[0-9]+::/, "", path)
    gsub(/grpc_event_engine::experimental::/, "", path)
    printf "%12d %s\n", samples, path
}'
echo ""

# ============================================
# 6. SERVER MAIN THREAD ANALYSIS
# ============================================
echo "=============================================="
echo "6. SERVER MAIN THREAD ANALYSIS (Top 10)"
echo "=============================================="
echo ""

grep '^server;' "$FOLDED" 2>/dev/null | sort -t' ' -k2 -rn | head -10 | awk '{
    samples = $NF
    gsub(/ [0-9]+$/, "")
    n = split($0, f, ";")
    path = ""
    start = n - 4
    if (start < 1) start = 1
    for (i = start; i <= n; i++) {
        if (path != "") path = path ";"
        path = path f[i]
    }
    gsub(/grpc_core::/, "", path)
    gsub(/absl::lts_[0-9]+::/, "", path)
    gsub(/grpc_event_engine::experimental::/, "", path)
    printf "%12d %s\n", samples, path
}'
echo ""

# ============================================
# 7. ADDITIONAL METRICS
# ============================================
echo "=============================================="
echo "7. ADDITIONAL METRICS"
echo "=============================================="
echo ""

syscall=$(grep -E 'syscall|__libc_sendmsg|__libc_write|__libc_read' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')
spinlock=$(grep -E 'SpinLock' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')
mutex=$(grep -E 'Mutex::' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')
threadpool=$(grep -E 'WorkStealingThreadPool' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')
arena=$(grep -E 'Arena' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')
memory=$(grep -E 'malloc|_int_malloc|_int_free|operator new|operator delete' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')

printf "%-30s %15d (%5.2f%%)\n" "Syscall overhead:" "$syscall" "$(pct $syscall)"
printf "%-30s %15d (%5.2f%%)\n" "SpinLock operations:" "$spinlock" "$(pct $spinlock)"
printf "%-30s %15d (%5.2f%%)\n" "Mutex operations:" "$mutex" "$(pct $mutex)"
printf "%-30s %15d (%5.2f%%)\n" "Thread pool overhead:" "$threadpool" "$(pct $threadpool)"
printf "%-30s %15d (%5.2f%%)\n" "Arena allocations:" "$arena" "$(pct $arena)"
printf "%-30s %15d (%5.2f%%)\n" "Memory operations:" "$memory" "$(pct $memory)"
echo ""

# ============================================
# 8. COMPLETION QUEUE METRICS
# ============================================
echo "=============================================="
echo "8. COMPLETION QUEUE METRICS"
echo "=============================================="
echo ""

cq_next=$(grep -E 'cq_next' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')
cq_pop=$(grep -E 'MultiProducerSingleConsumerQueue::Pop' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')
cq_push=$(grep -E 'MultiProducerSingleConsumerQueue::Push' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')
pollset=$(grep -E 'pollset_work|grpc_pollset_work' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')

printf "%-30s %15d (%5.2f%%)\n" "cq_next:" "$cq_next" "$(pct $cq_next)"
printf "%-30s %15d (%5.2f%%)\n" "CQ Pop operations:" "$cq_pop" "$(pct $cq_pop)"
printf "%-30s %15d (%5.2f%%)\n" "CQ Push operations:" "$cq_push" "$(pct $cq_push)"
printf "%-30s %15d (%5.2f%%)\n" "Pollset work:" "$pollset" "$(pct $pollset)"
echo ""

# ============================================
# 9. LOCK CONTENTION DETAIL
# ============================================
echo "=============================================="
echo "9. LOCK CONTENTION DETAIL"
echo "=============================================="
echo ""

deadlock_check=$(grep -E 'DeadlockCheck|DebugOnlyDeadlockCheck' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')
lock_graph=$(grep -E 'GetGraphId|ForgetDeadlockInfo' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')
debug_lock=$(grep -E 'DebugOnlyLockLeave|DebugOnlyLockEnter' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')
futex=$(grep -E 'Futex|FutexWaiter' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')

printf "%-30s %15d (%5.2f%%)\n" "Deadlock checking:" "$deadlock_check" "$(pct $deadlock_check)"
printf "%-30s %15d (%5.2f%%)\n" "Lock graph tracking:" "$lock_graph" "$(pct $lock_graph)"
printf "%-30s %15d (%5.2f%%)\n" "Debug lock overhead:" "$debug_lock" "$(pct $debug_lock)"
printf "%-30s %15d (%5.2f%%)\n" "Futex operations:" "$futex" "$(pct $futex)"
echo ""

# ============================================
# 10. NETWORK I/O METRICS
# ============================================
echo "=============================================="
echo "10. NETWORK I/O METRICS"
echo "=============================================="
echo ""

sendmsg=$(grep -E '__libc_sendmsg|sendmsg' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')
write_op=$(grep -E '__GI___libc_write|__libc_write' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')
read_op=$(grep -E '__libc_read|__GI___libc_read' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')
tcp=$(grep -E 'TcpFlush|TcpSend|PosixEndpointImpl' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')

printf "%-30s %15d (%5.2f%%)\n" "sendmsg:" "$sendmsg" "$(pct $sendmsg)"
printf "%-30s %15d (%5.2f%%)\n" "write:" "$write_op" "$(pct $write_op)"
printf "%-30s %15d (%5.2f%%)\n" "read:" "$read_op" "$(pct $read_op)"
printf "%-30s %15d (%5.2f%%)\n" "TCP operations:" "$tcp" "$(pct $tcp)"
echo ""

# ============================================
# 11. RPC LIFECYCLE METRICS
# ============================================
echo "=============================================="
echo "11. RPC LIFECYCLE METRICS"
echo "=============================================="
echo ""

create=$(grep -E 'CallData::CallData|RequestAsyncCall|RegisteredAsyncRequest' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')
rpc_proceed=$(grep -E 'CallData::Proceed' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')
finish=$(grep -E 'Finish|SendStatus' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')
rpc_destroy=$(grep -E 'DestroyCall|~CallData|grpc_call_unref' "$FOLDED" 2>/dev/null | awk '{sum += $NF} END {print sum+0}')

printf "%-30s %15d (%5.2f%%)\n" "RPC creation:" "$create" "$(pct $create)"
printf "%-30s %15d (%5.2f%%)\n" "RPC processing:" "$rpc_proceed" "$(pct $rpc_proceed)"
printf "%-30s %15d (%5.2f%%)\n" "RPC completion:" "$finish" "$(pct $finish)"
printf "%-30s %15d (%5.2f%%)\n" "RPC destruction:" "$rpc_destroy" "$(pct $rpc_destroy)"
echo ""

# ============================================
# 12. STACK TRACE STATISTICS
# ============================================
echo "=============================================="
echo "12. STACK TRACE STATISTICS"
echo "=============================================="
echo ""

total_stacks=$(wc -l < "$FOLDED")
server_stacks=$(grep -c '^server;' "$FOLDED" 2>/dev/null || echo 0)
ee_stacks=$(grep -c '^event_engine' "$FOLDED" 2>/dev/null || echo 0)
unknown_heavy=$(grep -c '\[unknown\]' "$FOLDED" 2>/dev/null || echo 0)

printf "%-30s %d\n" "Total unique stack traces:" "$total_stacks"
printf "%-30s %d\n" "Server thread stacks:" "$server_stacks"
printf "%-30s %d\n" "Event engine stacks:" "$ee_stacks"
printf "%-30s %d\n" "Stacks with [unknown]:" "$unknown_heavy"
echo ""

echo "=============================================="
echo "END OF REPORT"
echo "=============================================="

} > "$OUTPUT"

echo "Report generated: $OUTPUT"
echo ""
echo "Quick summary:"
echo "  Total samples: $TOTAL"
server_pct=$(grep '^server;' "$FOLDED" 2>/dev/null | awk -v t="$TOTAL" '{sum+=$NF} END {printf "%.1f", sum*100/t}')
ee_pct=$(grep '^event_engine' "$FOLDED" 2>/dev/null | awk -v t="$TOTAL" '{sum+=$NF} END {printf "%.1f", sum*100/t}')
echo "  Main thread: ${server_pct}%"
echo "  Event engine: ${ee_pct}%"
