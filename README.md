1. generate pbs

```bash
$ make all
```
2. mkdir build && cd build

3. build project
```bash
$ cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS="-DNDEBUG -O3 -fno-omit-frame-pointer -march=native" ..
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
$ cd ~ && git clone git@github.com:brendangregg/FlameGraph.git

$ cd perfs/ && sudo perf record -F 99 -g -p $(pgrep async_server) -- sleep 60
$ perf script | ~/FlameGraph/stackcollapse-perf.pl > out.folded
$ ./analyze_folded.sh out.folded report.txt
$ ~/Flamegraph/flamegraph.pl out.folded > flame.svg
```
