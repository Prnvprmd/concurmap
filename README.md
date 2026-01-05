# concurmap(Work In Progress)
A concurrent Hashmap implemented in cangjie


## Hashmap designs

### V1

- Open Addressing
- Used 2 types of Locks
    - 1 Global Lock(Higher Priority) which is acquired during rehashing/expanding step
    - Fine grained locks for each key-value pair
        - Only acquired after checking if the global lock is not acquired
        - Keeps spinning, until the lock is not acquired
- FNV1A hashing algo used

Tests: Passed, no deadlocks observed

### V2p1

- Open Addressing with Compare And Swaps instead of Locks
- Implemented 2 types of Locks(same as previous) using CAS primitives instead od mutex locks
- FNV1A hashing algo used

Tests: Passed, no deadlocks observed

### V3

- Closed chaining with fine grained mutex locks for each bucket
- Used a global atomic flag to indicate when table is rehashing/expanding
- FNV1A hashing algo used

Tests: Passed, no deadlocks observed

### V4p1

- Improved upon the previous design. Closed chaining with fine grained mutex locks for each bucket.
- Inspired by Redis' design, here the table is not Globally Locked when expanding/rehashing.
    - Used 2 tables in the same data structure. 2nd table is used only while expanding, where the elements from the 1st table are rehashed into the 2nd table.
    - When expanding, Atomic flag is set to signify the same.
    - if expanding, put and get are not blocked. 
        - Get checks both tables when expanding is in progress.
        - Put inserts the element directly into the 2nd table when expanding is in progress.
- FNV1A hashing algo used

Tests: Fails, deadlocks during parallelPerformanceTest and parallelStressTest. Also fails with OOM, not always reproducible.

### V5


- Based upon the previous design. Open addressing with fine grained mutex locks for each bucket/Key-Value pair.
- Inspired by Redis' design, here the table is not Globally Locked when expanding/rehashing.
    - Used 2 tables in the same data structure. 2nd table is used only while expanding, where the elements from the 1st table are rehashed into the 2nd table.
    - When expanding, Atomic flag is set to signify the same.
    - if expanding, put and get are not blocked. 
        - Get checks both tables when expanding is in progress.
        - Put inserts the element directly into the 2nd table when expanding is in progress.
- FNV1A hashing algo used

Tests: Passes most of the times. Deadlocks very rarely during parallelPerformanceTest and parallelStressTest. Not exactly reproducible.






## Commands

Generate samples/ops before running any tests

```sh

python3 ./gen_keys.py > ../samples/init_actions.txt 2> ../samples/actions.txt


```