
## Hashmap designs

### V1

- Open Addressing
- Used 2 types of Locks
    - 1 Global Lock(Higher Priority) which is acquired during rehashing/expanding step
    - Fine grained locks for each key-value pair
        - Only acquired after checking if the global lock is not acquired
        - Keeps spinning, until the lock is not acquired
- FNV1A hashing algo used

### V2p1

- Open Addressing with Compare And Swaps instead of Locks
- Implemented 2 types of Locks(same as previous) using CAS primitives instead od mutex locks
- FNV1A hashing algo used

### V3

- Closed chaining with fine grained mutex locks for each bucket
- Used a global atomic flag to indicate when table is rehashing/expanding
- FNV1A hashing algo used

### V4p1

- Improved upon the previous design. Closed chaining with fine grained mutex locks for each bucket.
- Inspired by Redis' design, here the table is not Globally Locked when expanding/rehashing.
    - Used 2 tables in the same data structure. 2nd table is used only while expanding, where the elements from the 1st table are rehashed into the 2nd table.
    - When expanding, Atomic flag is set to signify the same.
    - if expanding, put and get are not blocked. 
        - Get checks both tables when expanding is in progress.
        - Put inserts the element directly into the 2nd table when expanding is in progress.
- FNV1A hashing algo used

### V5

- Based upon the previous design. Open addressing with fine grained mutex locks for each bucket/Key-Value pair.
- Inspired by Redis' design, here the table is not Globally Locked when expanding/rehashing.
    - Used 2 tables in the same data structure. 2nd table is used only while expanding, where the elements from the 1st table are rehashed into the 2nd table.
    - When expanding, Atomic flag is set to signify the same.
    - if expanding, put and get are not blocked. 
        - Get checks both tables when expanding is in progress.
        - Put inserts the element directly into the 2nd table when expanding is in progress.
- FNV1A hashing algo used

### V6

- A basic closed chaining implementation with fine grained mutex locks for each bucket.
- When expanding, Atomic flag is set to signify the same, which blocks put and get operation until expansion is complete
- FNV1A hashing algo used

Closed chaining, lock per bucket. Table is array of buckets. Buckets are linked list of Key Value Pairs

### V7

- Basic Open Addressing implementation with fine grained mutex locks for each KV pair.
- Table is an ArrayList of Nodes. Separate ArrayList for locks.
- FNV1A hashing algo used

### V8

- Open Addressing implementation with fine grained mutex locks for each KV pair.
- Table is made up of ArrayList of AtomicOptionReference(Node References), to improve memory management as AtomicOptionReference can be made NULL.
- FNV1A hashing algo used

### V9

- Same as V8. 
- With Static work sharing to enable cooperative migration during rehashing/expansion.

### V10

- Open addressing implemented with CAS fast-path locking mechanism instead of mutex locks for faster lock acquisition. 
- Table is made up of ArrayList of AtomicOptionReference(Node References), and an ArrayList of AtomicInts for CAS
- FNV1A hashing algo used.

### V11

- Same as V10. 
- Same hashing function with different prime number and offset.

### V12

- Same as V10. 
- Similar hashing function with a different offset and no prime number.

### KeyValueConcurMap - Default

- std lib's ConcurrentHashMap(concurrencyLevel = 4)
- Created a wrapper class around it to validate tests and measure runtimes.


---------------------


## Tests

- ParallelStressTest
    - Randomly generate get and put operations. (Put : Get) ratio can be set.
    - Generate N(100k) Keys and Values 
    - Generate op ordering using a SampleGenerator which samples based on a given distribution
        - Distribution can be uniform, linearly increasing, exponential etc
        - Distribution such as exponential are useful as it helps in "same key hammering" by sampling the same key, which may help in detecting deadlocks
        - Defined in src/utils.cj
    - Spawn 4 threads that execute generated ops.
        - Spawn an extra thread(called watchdog thread) to detect deadlocks. Works most of the time and throws an error.


## Test Status

- V1 - ConcurrentModificationException, IllegalSynchronizationStateException
    - Very rare. Occurs once every 100 iterations of the same test.
- V2p1 - ConcurrentModificationException
- V3 - Deadlocks
- V4p1 - Deadlocks, possible OOM after that
- V5 - OOM
- V6 - Passes all tests
- V7 - Passes all tests
- V8 - Passes all tests
- V9 - Passes all tests
- V10 - Passes all tests
