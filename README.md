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
Original ACIR opcodes: 85868  
Optimized ACIR opcodes: xxx

| Metric | Original | Optimized |
|--------|----------|-----------|
| nargo_build | 7.717 |  |
| nargo_execute | 0.369 |  |
| bb_write_vk | 1.577 |  |
| bb_prove | 0.060 |  |
| bb_verify | 0.023 |  |