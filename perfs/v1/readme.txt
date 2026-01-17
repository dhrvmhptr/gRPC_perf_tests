CC helped me analyze the performance here. This is how he investigated. logging it here for future reference.

----> Quick summary without full analysis

$ perf report -n --stdio


-----> leaf function is WHERE the CPU is actually spending cycles.

$ echo "=== Top functions in leaf positions (where CPU actually spends time) ===" # Extract leaf function (last item before sample count)
sed 's/ [0-9]\*$//' out.folded | rev | cut -d';' -f1 | rev | sort | uniq -c | sort -rn | head -30

$ {
total=$(awk '{sum += $NF} END {print sum}' out.folded)
echo "Total samples: $total"
echo ""
echo "=== Breakdown by major subsystem ==="

        # epoll/io wait
        epoll=$(grep -E 'epoll_wait' out.folded | awk '{sum += $NF} END {print sum+0}')
        echo "epoll_wait (I/O):          $epoll ($(echo "scale=1; $epoll * 100 / $total" | bc)%)"

        # Debug lock overhead
        debug=$(grep -E 'DebugOnlyLockLeave|DebugOnlyDeadlockCheck|GetGraphId|ForgetDeadlockInfo' out.folded | awk '{sum += $NF} END {print sum+0}')
        echo "Debug lock graph:          $debug ($(echo "scale=1; $debug * 100 / $total" | bc)%)"

        # CQ polling
        cq=$(grep -E 'cq_next|pollset_work|grpc_pollset_work' out.folded | awk '{sum += $NF} END {print sum+0}')
        echo "CQ polling (cq_next):      $cq ($(echo "scale=1; $cq * 100 / $total" | bc)%)"

        # CallData processing
        proceed=$(grep -E 'CallData::Proceed|CallData::~CallData|CallData::CallData' out.folded | awk '{sum += $NF} END {print sum+0}')
        echo "CallData lifecycle:        $proceed ($(echo "scale=1; $proceed * 100 / $total" | bc)%)"

        # Response path
        finalize=$(grep -E 'FinalizeResult|BeginCompletionOp|PerformOps' out.folded | awk '{sum += $NF} END {print sum+0}')
        echo "Request handling:          $finalize ($(echo "scale=1; $finalize * 100 / $total" | bc)%)"

        # Call destruction
        destroy=$(grep -E 'DestroyCall|grpc_call_unref|FilterStackCall' out.folded | awk '{sum += $NF} END {print sum+0}')
        echo "Call destruction:          $destroy ($(echo "scale=1; $destroy * 100 / $total" | bc)%)"

        # Lock contention
        locks=$(grep -E 'Mutex::|SpinLock::|gpr_mu' out.folded | awk '{sum += $NF} END {print sum+0}')
        echo "Lock operations:           $locks ($(echo "scale=1; $locks * 100 / $total" | bc)%)"

        # Event engine background
        ee=$(grep -E '^event_engine' out.folded | awk '{sum += $NF} END {print sum+0}')
        echo "Event engine threads:      $ee ($(echo "scale=1; $ee * 100 / $total" | bc)%)"
      }

----------> Hot Paths will tell us the WHY of the cpu stack execution

$ total=$(awk '{sum += $NF} END {print sum}' out.folded)
   echo "Total samples: $total"
   echo ""
   echo "=== Top 15 Hot Paths (percentage of total CPU time) ==="
   echo ""
   sort -t' ' -k2 -rn out.folded | head -15 | while read line; do
     samples=$(echo "$line" | awk '{print $NF}')
     pct=$(echo "scale=2; $samples * 100 / $total" | bc)
     # Get last 3 meaningful frames for readability
     stack=$(echo "$line" | sed 's/ [0-9]*$//' | rev | cut -d';' -f1-3 | rev | sed 's/grpc_core:://g' | sed 's/absl::lts_20250512:://g' | sed 's/grpc:://g')
printf "%5.2f%% %s\n" "$pct" "$stack"
done

$ echo "=== Separating Main Thread vs Background Threads ==="
echo ""

      # Server main thread (HandleRpcs loop)
      server_total=$(grep '^server;' out.folded | awk '{sum+=$NF} END {print sum}')
      echo "Main server thread: $server_total samples"

      # Event engine (background)
      ee_total=$(grep '^event_engine' out.folded | awk '{sum+=$NF} END {print sum}')
      echo "Event engine threads: $ee_total samples"

      # Other
      other=$(grep -v '^server;\|^event_engine' out.folded | awk '{sum+=$NF} END {print sum}')
      echo "Other: $other samples"

      total=$((server_total + ee_total + other))
      echo ""
      echo "Total: $total"
      echo ""

      server_pct=$(awk "BEGIN {printf \"%.1f\", $server_total * 100 / $total}")
      ee_pct=$(awk "BEGIN {printf \"%.1f\", $ee_total * 100 / $total}")

      echo "Main server thread: $server_pct%"
      echo "Event engine background: $ee_pct%"



$ echo "=== Event Engine Thread Analysis==="
echo ""
echo "Top 10 stacks in event_engine threads:"
echo ""

grep '^event_engine' out.folded | sort -t' ' -k2 -rn | head -10 | awk '{
samples = $NF
     # Get last few frames
     gsub(/ [0-9]+$/, "")
n = split($0, f, ";") # Print last 5 frames
path = ""
start = n - 4
if (start < 1) start = 1
for (i = start; i <= n; i++) {
if (path != "") path = path ";"
path = path f[i]
}
gsub(/grpc_core::/, "", path)
gsub(/absl::lts_20250512::/, "", path)
gsub(/grpc_event_engine::experimental::/, "", path)
printf "%12d %s\n", samples, path
}'


----------> Additional Analysis Commands (used for performance_report.md)

# === Total samples and subsystem breakdown ===
$ total=$(awk '{sum += $NF} END {print sum}' out.folded) && echo "Total samples: $total" && echo "" && echo "=== Breakdown by major subsystem ===" && epoll=$(grep -E 'epoll_wait' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "epoll_wait (I/O):          $epoll ($(echo "scale=1; $epoll * 100 / $total" | bc)%)" && debug=$(grep -E 'DebugOnlyLockLeave|DebugOnlyDeadlockCheck|GetGraphId|ForgetDeadlockInfo' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "Debug lock graph:          $debug ($(echo "scale=1; $debug * 100 / $total" | bc)%)" && cq=$(grep -E 'cq_next|pollset_work|grpc_pollset_work' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "CQ polling (cq_next):      $cq ($(echo "scale=1; $cq * 100 / $total" | bc)%)" && proceed=$(grep -E 'CallData::Proceed|CallData::~CallData|CallData::CallData' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "CallData lifecycle:        $proceed ($(echo "scale=1; $proceed * 100 / $total" | bc)%)" && finalize=$(grep -E 'FinalizeResult|BeginCompletionOp|PerformOps' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "Request handling:          $finalize ($(echo "scale=1; $finalize * 100 / $total" | bc)%)" && destroy=$(grep -E 'DestroyCall|grpc_call_unref|FilterStackCall' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "Call destruction:          $destroy ($(echo "scale=1; $destroy * 100 / $total" | bc)%)" && locks=$(grep -E 'Mutex::|SpinLock::|gpr_mu' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "Lock operations:           $locks ($(echo "scale=1; $locks * 100 / $total" | bc)%)" && ee=$(grep -E '^event_engine' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "Event engine threads:      $ee ($(echo "scale=1; $ee * 100 / $total" | bc)%)"


# === Top 20 Hot Paths by sample count ===
$ sort -t' ' -k2 -rn out.folded | head -20 | awk '{
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
  gsub(/absl::lts_20250512::/, "", path)
  gsub(/grpc_event_engine::experimental::/, "", path)
  gsub(/grpc::/, "", path)
  printf "%15d %s\n", samples, path
}'


# === Additional Metrics (syscalls, memory, thread pool) ===
$ total=$(awk '{sum += $NF} END {print sum}' out.folded) && echo "=== Additional Metrics ===" && echo "" && syscall=$(grep -E 'syscall|__libc_sendmsg|__libc_write|__libc_read' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "Syscall overhead:          $syscall ($(echo "scale=1; $syscall * 100 / $total" | bc)%)" && spinlock=$(grep -E 'SpinLock' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "SpinLock operations:       $spinlock ($(echo "scale=1; $spinlock * 100 / $total" | bc)%)" && mutex=$(grep -E 'Mutex::' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "Mutex operations:          $mutex ($(echo "scale=1; $mutex * 100 / $total" | bc)%)" && threadpool=$(grep -E 'WorkStealingThreadPool' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "Thread pool overhead:      $threadpool ($(echo "scale=1; $threadpool * 100 / $total" | bc)%)" && arena=$(grep -E 'Arena' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "Arena allocations:         $arena ($(echo "scale=1; $arena * 100 / $total" | bc)%)" && memory=$(grep -E 'malloc|_int_malloc|_int_free|operator new|operator delete' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "Memory operations:         $memory ($(echo "scale=1; $memory * 100 / $total" | bc)%)"


# === Completion Queue Metrics ===
$ total=$(awk '{sum += $NF} END {print sum}' out.folded) && echo "=== Completion Queue Metrics ===" && cq_next=$(grep -E 'cq_next' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "cq_next:                   $cq_next ($(echo "scale=2; $cq_next * 100 / $total" | bc)%)" && cq_pop=$(grep -E 'MultiProducerSingleConsumerQueue::Pop' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "CQ Pop operations:         $cq_pop ($(echo "scale=2; $cq_pop * 100 / $total" | bc)%)" && cq_push=$(grep -E 'MultiProducerSingleConsumerQueue::Push' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "CQ Push operations:        $cq_push ($(echo "scale=2; $cq_push * 100 / $total" | bc)%)" && pollset=$(grep -E 'pollset_work|grpc_pollset_work' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "Pollset work:              $pollset ($(echo "scale=2; $pollset * 100 / $total" | bc)%)"


# === Lock Contention Detail ===
$ total=$(awk '{sum += $NF} END {print sum}' out.folded) && echo "=== Lock Contention Detail ===" && deadlock_check=$(grep -E 'DeadlockCheck|DebugOnlyDeadlockCheck' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "Deadlock checking:         $deadlock_check ($(echo "scale=2; $deadlock_check * 100 / $total" | bc)%)" && lock_graph=$(grep -E 'GetGraphId|ForgetDeadlockInfo' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "Lock graph tracking:       $lock_graph ($(echo "scale=2; $lock_graph * 100 / $total" | bc)%)" && debug_lock=$(grep -E 'DebugOnlyLockLeave|DebugOnlyLockEnter' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "Debug lock overhead:       $debug_lock ($(echo "scale=2; $debug_lock * 100 / $total" | bc)%)" && futex=$(grep -E 'Futex|FutexWaiter' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "Futex operations:          $futex ($(echo "scale=2; $futex * 100 / $total" | bc)%)"


# === Network I/O Metrics ===
$ total=$(awk '{sum += $NF} END {print sum}' out.folded) && echo "=== Network I/O Metrics ===" && sendmsg=$(grep -E '__libc_sendmsg|sendmsg' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "sendmsg:                   $sendmsg ($(echo "scale=2; $sendmsg * 100 / $total" | bc)%)" && write=$(grep -E '__GI___libc_write|__libc_write' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "write:                     $write ($(echo "scale=2; $write * 100 / $total" | bc)%)" && read_op=$(grep -E '__libc_read|__GI___libc_read' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "read:                      $read_op ($(echo "scale=2; $read_op * 100 / $total" | bc)%)" && tcp=$(grep -E 'TcpFlush|TcpSend|PosixEndpointImpl' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "TCP operations:            $tcp ($(echo "scale=2; $tcp * 100 / $total" | bc)%)"


# === RPC Lifecycle Metrics ===
$ total=$(awk '{sum += $NF} END {print sum}' out.folded) && echo "=== RPC Lifecycle Metrics ===" && create=$(grep -E 'CallData::CallData|RequestAsyncCall|RegisteredAsyncRequest' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "RPC creation:              $create ($(echo "scale=2; $create * 100 / $total" | bc)%)" && proceed=$(grep -E 'CallData::Proceed' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "RPC processing:            $proceed ($(echo "scale=2; $proceed * 100 / $total" | bc)%)" && finish=$(grep -E 'Finish|SendStatus' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "RPC completion:            $finish ($(echo "scale=2; $finish * 100 / $total" | bc)%)" && destroy=$(grep -E 'DestroyCall|~CallData|grpc_call_unref' out.folded | awk '{sum += $NF} END {print sum+0}') && echo "RPC destruction:           $destroy ($(echo "scale=2; $destroy * 100 / $total" | bc)%)"


# === Stack Trace Statistics ===
$ echo "=== Stack Trace Counts ===" && total_stacks=$(wc -l < out.folded) && echo "Total unique stack traces: $total_stacks" && server_stacks=$(grep -c '^server;' out.folded) && echo "Server thread stacks:      $server_stacks" && ee_stacks=$(grep -c '^event_engine' out.folded) && echo "Event engine stacks:       $ee_stacks"


# === Server Main Thread Analysis ===
$ total=$(awk '{sum += $NF} END {print sum}' out.folded) && echo "=== Server Main Thread Analysis ===" && echo "Top 10 stacks in server main thread:" && grep '^server;' out.folded | sort -t' ' -k2 -rn | head -10 | awk '{
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
  gsub(/absl::lts_20250512::/, "", path)
  gsub(/grpc_event_engine::experimental::/, "", path)
  printf "%15d %s\n", samples, path
}'
