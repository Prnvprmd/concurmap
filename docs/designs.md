
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

---------------------


## Test status

- V1 - ConcurrentModificationException, IllegalSynchronizationStateException
    - Very rare. Occurs once every 100 iterations of the same test.
- V2p1 - ConcurrentModificationException
- V3 - Deadlocks
- V4p1 - Deadlocks, possible OOM after that
- V5 - OOM
- V6 - Passes all tests
