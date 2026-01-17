1. generate pbs

```bash
$ make all
```

2. build project

```bash
$ cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS="-DNDEBUG -O3 -fno-omit-frame-pointer" ..
$ cmake --build .
```

3. cd build

4. run server

5. run ghz performance test

from the root dir 

$ ghz   --proto inference.proto   --call inference.InferenceService/Predict   --insecure   --concurrency 64   --rps 5000   --total 300000   localhost:50051 --data '{"input":"AAAAAAAAAAAAAAAA"}'

6. flamegraph 

Using Linux perf_events (aka "perf") to capture 60 seconds of 99 Hertz stack samples

$ perf record -F 99 -p <server-process-id> -g -- sleep 60 --call-graph dwarf
$ perf script > out.perf

then flamegraph

$ ../FlameGraph/stackcollapse-perf.pl out.perf > out.folded
$ ../FlameGraph/flamegraph.pl out.folded > kernel.svg

# Results

v1: Increasing the concurrency and rps increases latency tremendously, so need to think of multiple COs to handle the load and test again
# gRPC_perf_tests
