# BoundedVec optimization experiment

This repo is an experiment that optimizes Noir by implementing a new method `BoundedVec.set_len`, which complements the existing `set_unchecked` and can reduce circuit size and proving cost compared to using the built-in `BoundedVec` with `push`/`extend`.

## Running the benchmark

```bash
./benchmark.sh
```

## Benchmark results

Circuit size (from `nargo info` and compiled circuit in `target/<package>.json`):

| Experiment  | Expression Width (main) | ACIR Opcodes (main) | Bytecode size |
|-------------|-------------------------|----------------------|---------------|
| Original    | 24,975                  | 17                   | 384,994 B     |
| Optimized   | 1,000                   | 0                    | 6,510 B       |

*Note: For circuit size, use **Expression Width**; the ACIR Opcodes column in `nargo info` is not a reliable total in this version. Brillig Opcodes is empty because both circuits are pure ACIR.*

Timing (averaged over 1 run; times in seconds):

| Metric         | Original | Optimized |
|----------------|----------|-----------|
| nargo_compile  | 14.470   | 0.564     |
| nargo_execute  | 0.137    | 0.068     |
| bb_write_vk    | 0.180    | 0.046     |
| bb_prove       | 0.330    | 0.148     |
| bb_verify      | 0.035    | 0.034     |

The optimized experiment shows a large reduction in Expression Width (24,975 → 1,000), in bytecode size (384,994 B → 6,510 B), much faster compile time, and faster execute, write_vk, and prove; verify times are similar.
