# concurmap
A concurrent Hashmap implemented in cangjie

All hashmap design descriptions and tests are documented in docs/designs.md

## Performance

All runtimes are averaged over 5 runs using 100k keys.

| Description                                                                                                                                                                              | Version  | Put Op Time(ns) | Get Op Time(ns) | Mixed Op Time(ns) | Mixed Op throughput(ops/msec) |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------|-----------------|-----------------|-------------------|-------------------------------|
| Closed chaining, lock per bucket. Table is array of buckets. Buckets are linked list of Key Value Pairs                                                                           | V6      | 2347.0          | 188.4           | 2427.2            | 201.92                        |
| Open addressing with locks. Table is an Arraylist. No buckets, KV pairs are stored directly in the Table(ArrayList). Separate Array for locks.                                    | V7      | 1341.2          | 181.6           | 869.6             | 492.84                        |
| Open addressing with locks. Table is made up of AtomicOptionReference(Node References). Table also has separate array for locks                                                   | V8      | 391.0           | 239.4           | 407.4             | 974.17                        |
| Same as V8. Added Static work sharing to enable cooperative migration during rehashing/expansion.                                                                                 | V9      | 399.6           | 235.6           | 410.0             | 977.79                        |
| Open addressing with CAS fast path locks. Table is made up of AtomicOptionReference. No locks. Each table entry has an AtomicInt to signify if locked or not. FNV1A hashing algo. | V10     | 273.2           | 191.0           | 287.8             | 1295.60                       |
| Same as V10. Used same hashing function with different prime number and offset.                                                                                                   | V11     | 274.6           | 192.0           | 401.2             | 1133.59                       |
| Same as V10. Used similar hashing function with a different offset and no prime number.                                                                                           | V12     | 310.0           | 250.4           | 378.2             | 1125.78                       |
| std lib ConcurrentHashMap(concurrencyLevel = 4)                                                                                                                                   | default | 314.8           | 184.8           | 447.2             | 975.83                        |




Based on current performance tests, V10 has the best throughput and is better than the std lib ConcurrentHashMap.
