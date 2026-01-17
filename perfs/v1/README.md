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
