The repo represents an experiment where we optimize noir's built-in `BoundedVec.extend_from_bounded_vec` implementation.


We do this by replicating the BoundedVec implementation here, and changing the built-in methods
while observing changes in performance through monitoring ACIR opcodes number, and time needed to compile, and do other operations

### Chosen Experiment
The target circuit verifies that a user's age is above 18 years old, and checks that this age is part of 
a JWT object that has been signed by ECDSA signature.
the public parameters of the circuit are:
- The issuer public key
- Time now (unix)

### Simulations
There's two simulations here
1. Uses default `BoundedVec.extend_from_bounded_vec`
2. Updates `BoundedVec.extend_from_bounded_vec` with optimized code

### Running the simulations
```shell
>>> ./benchmark.sh
```

### Current Results:

#### On input limited to 445 bytes
Original ACIR opcodes: 19652  
Optimized ACIR opcodes: 19060

| Metric | Original | Optimized |
|--------|----------|-----------|
| nargo_build | 0.856 | 0.779 |
| nargo_execute | 0.153 | 0.149 |
| bb_write_vk | 0.735 | 0.557 |
| bb_prove | 0.031 | 0.029 |
| bb_verify | 0.024 | 0.023 |


#### On input limited to 2000 bytes
Original ACIR opcodes: 85868  
Optimized ACIR opcodes: 83203

| Metric | Original | Optimized |
|--------|----------|-----------|
| nargo_build | 7.682 | 7.817 |
| nargo_execute | 0.363 | 0.385 |
| bb_write_vk | 1.554 | 1.435 |
| bb_prove | 0.062 | 0.065 |
| bb_verify | 0.023 | 0.023 |

It's important to note that timings were averaged over 20 runs. 
However, since the numbers are so close, it might give wrong conclusions because of fine measurement errors.
