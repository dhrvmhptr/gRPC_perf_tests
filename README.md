1. generate pbs

```bash
$ make all
```
2. mkdir build && cd build

3. build project
```bash
$ cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS="-DNDEBUG -O3 -fno-omit-frame-pointer" ..
$ cmake --build .
```
4. run server

5. run ghz performance test

from the root dir 
```bash
$ ghz   --proto inference.proto   --call inference.InferenceService/Predict   --insecure   --concurrency 64   --rps 5000   --total 300000   localhost:50051 --data '{"input":"AAAAAAAAAAAAAAAA"}'
```
6. flamegraph 

Using Linux perf_events (aka "perf") to capture 60 seconds of 99 Hertz stack samples
```bash
$ perf record -F 99 -p <server-process-id> -g -- sleep 60 --call-graph dwarf
$ perf script > out.perf
```
then flamegraph
```bash
$ cd ~ && git clone git@github.com:brendangregg/FlameGraph.git

cd back into dir where the out.perf is located

$ ~/FlameGraph/stackcollapse-perf.pl out.perf > out.folded
$ ~/FlameGraph/flamegraph.pl out.folded > kernel.svg
```
# Results

v1: Increasing the concurrency and rps increases latency tremendously, so need to think of multiple COs to handle the load and test again
