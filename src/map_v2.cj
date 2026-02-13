package my_map

import std.collection.ArrayList
import std.sync.ReentrantMutex
import std.convert.*
import std.collection.*
import std.sync.*





class KeyValueV2p1 <: CustomMap {

    private var init_capacity: Int64;
    private var capacity: Int64;
    private var length = AtomicInt64(0);
    private var load_factor: Float32;
    private var expansion_rate: Float32;
    private var expansion_threshold : Int64;
    private var table : ArrayList<NodeV1>;
    private var new_table : ArrayList<NodeV1>;
    private var lock_table : ArrayList<AtomicInt8>;

    let lock1_held = AtomicInt8(0);     // 0 == free, 1 == held

    KeyValueV2p1(init_capacity! : Int64 = 8
            , load_factor! : Float32 = 0.5
            , expansion_rate! : Float32 = 2.0) {
        this.init_capacity = init_capacity;
        this.capacity = init_capacity
        this.load_factor = load_factor;
        this.expansion_rate = expansion_rate;
        this.expansion_threshold = Int64(Float32(capacity) * load_factor);
        this.table = ArrayList<NodeV1>(capacity, {x : Int64 => NodeV1("", 0)});
        this.new_table = ArrayList<NodeV1>(Int64(Float32(capacity) * expansion_rate), {x : Int64 => NodeV1("", 0)});
        this.lock_table = ArrayList<AtomicInt8>(capacity, {x : Int64 => AtomicInt8(0)});
    }

    private func acquire_lock1() {
        // Fast exclusive acquisition: use a mutex or atomic CAS on lock1_held.
        // Using a mutex is fine; but for low-latency we can attempt CAS first.
        while(!lock1_held.compareAndSwap(0, 1)) {
            continue;
        }
        // At this point we hold lock1 logically.
        // No extra state needed. We do NOT touch lock2_owner here.
        // println("Acquired Lock1");
    }

    private func release_lock1() {
        lock1_held.store(0);

        // // Wake up any threads waiting for Lock1 to be free.
        // mon.lock();
        // mon.notifyAll(lock1_released);                 // wake waiters so they can retry acquiring Lock2
        // mon.unlock();
        // // println("Released Lock1");
    }


    private func acquire_lock2(idx : Int64) {
        while(true) {
            // Fast-path: check Lock1 is free
            if(lock1_held.load() == 0) {
                // try to become the Lock2 owner (atomic)
                if(lock_table[idx].compareAndSwap(0, 1)) {
                    // We have claimed Lock2; verify Lock1 is still free
                    if(lock1_held.load() == 0) {
                        // println("Acquired Lock2 for ${idx}");
                        return;                 // success: Lock2 held by this thread
                    } else {
                        // Race: Lock1 was taken just now. Release and retry.
                        // Release lock2_owner and continue (with backoff)
                        lock_table[idx].store(0);
                        // brief backoff to avoid immediate thrash
                        // small_backoff();
                        continue;
                    }
                }
            }
            // If we reach here: either Lock1 is held, or Lock2 was busy.

            // Spin for a short while (adaptive)

            // // After spinning, park the thread efficiently on condvar
            // mon.lock();
            // // Double-check before sleeping to avoid missed wakeups
            if(lock1_held.load() == 0 && lock_table[idx].load() == 0) {
                // Attempt final quick claim while holding m_wait is NOT required,
                // but to reduce thundering herd we can attempt CAS here (still atomic).
                if(lock_table[idx].compareAndSwap(0, 1)) {
                    // mon.unlock();
                    // confirm Lock1 still free
                    if(lock1_held.load() == 0) {
                        return;
                    } else {
                        // lost race, release and retry
                        lock_table[idx].store(0);
                        // mon.unlock();
                        // small_backoff()
                        continue;
                    }
                }
            }
            // Otherwise wait to be signalled when lock1 becomes free or lock2 is released
            // mon.wait(lock1_released);         // wait until Lock1 free event
            // mon.unlock();
        }
    }

    private func release_lock2(idx : Int64) {
        lock_table[idx].store(0);
        // println("Released Lock2 for ${idx}");
    }

    public func expand() {
        var new_capacity = Int64(Float32(capacity) * expansion_rate);
        length.store(0);

        for(item in table) {
            if (item.getKey() == "") { continue }
            var key = item.getKey();
            var val = item.getValue();
            var idx: Int64 = Int64(hash_function(key) % UInt64(new_capacity));
            while(new_table[idx].getKey() != "") {
                idx++;
                if(idx >= new_capacity) {idx = 0;}
            }
            new_table[idx] = NodeV1(key, val);
            length.fetchAdd(1);
        }

        capacity = new_capacity;
        lock_table = ArrayList<AtomicInt8>(capacity, {x : Int64 => AtomicInt8(0)});
        table = new_table;
        expansion_threshold = Int64(Float32(capacity) * load_factor);
        new_table = ArrayList<NodeV1>(Int64(Float32(capacity) * expansion_rate), {x : Int64 => NodeV1("", 0)});
    }

    private func lookUpBucket(k: String): Int64 {
        var idx: Int64 = Int64(hash_function(k) % UInt64(capacity));
        return idx;
    }

    public func put(k: String, v: Int64): Unit {
        var bucket_idx = lookUpBucket(k);

        while(true) {
            acquire_lock2(bucket_idx);
            if(table[bucket_idx].getKey() == "") {
                break;
            }
            if (table[bucket_idx].getKey() == k) {
                table[bucket_idx].setValue(v);
                release_lock2(bucket_idx);
                return;
            }
            release_lock2(bucket_idx);
            bucket_idx++;
            if(bucket_idx >= capacity) {bucket_idx = 0;}
        }
        table[bucket_idx] = NodeV1(k, v);
        release_lock2(bucket_idx);
        length.fetchAdd(1);

        maybe_trigger_expand();

        return
    }

    public func maybe_trigger_expand() {
        if(length.load() < Int64(Float32(capacity) * load_factor)) {
            return;
        }
        trigger_expand();
    }

    public func trigger_expand() {
        acquire_lock1();
        expand();
        release_lock1();
    }


    public func get(k: String): Option<Int64> {
        var bucket_idx = lookUpBucket(k);
        while(true) {
            acquire_lock2(bucket_idx);
            if(table[bucket_idx].getKey() == "") {
                release_lock2(bucket_idx);
                return None;
            }
            if (table[bucket_idx].getKey() == k) {
                let out = table[bucket_idx].getValue();
                release_lock2(bucket_idx);
                return out;
            }
            release_lock2(bucket_idx);
            bucket_idx++;
            if(bucket_idx >= capacity) {bucket_idx = 0;}
        }
        return None;
    }

    public func getKeysAndValues(): ArrayList<String> {
        let keys = ArrayList<String>()
        for(item in table) {
            if (item.getKey() == "") { continue }
            keys.append(item.getKey())
        }
        return keys
    }

    public func getKeys(): ArrayList<String> {
        let res = ArrayList<String>()
        for(item in table) {
            if (item.getKey() == "") { continue }
            res.append(item.getKey())
        }
        return res
    }

    public func serialize(): String {
        var output = StringBuilder(16000000)
        for (key in getKeys()) {
            output.append(key)
            output.append(' ')
            output.append(get(key).getOrThrow())
            output.append('\n')
        }
        return output.toString()
    }
	
    public static func deserialize(str: String): KeyValueV2p1 {
        let splits = str.split("\n", removeEmpty: true)
        let keyValue = KeyValueV2p1()

        for (split in splits) {
            let words = split.split(" ")
            let key = words[0]
            let value = Int64.parse(words[1])

            keyValue.put(key, value)
        }
        return keyValue
    }

    public func new_deserialize(lines: ArrayList<String>): Unit {
        for (action in lines) {
            let words = action.split(" ")
            if(words.size == 3) {
                let key = words[1]
                let value = Int64.parse(words[2])
                put(key, value);
            } else {
                let key = words[1]
                get(key);
            }
        }
    }

    @OverflowWrapping
    private func hash_function(s: String): UInt64 {
        let offset: UInt64 = 14695981039346656037;
        let prime: UInt64 = 1099511628211;
        var hash_value: UInt64 = offset;
        for (c in s) {
            hash_value ^= UInt64(UInt32(c));
            hash_value *= prime;
        }
        return hash_value;
    }


    public func get_capacity() : Int64 {
        return capacity;
    }

    public func get_size() : Int64 {
        return length.load();
    }

    public func clear() : Unit {
        capacity = init_capacity;
        length.store(0);
        table = ArrayList<NodeV1>(capacity, {x : Int64 => NodeV1("", 0)});
        new_table = ArrayList<NodeV1>(Int64(Float32(capacity) * expansion_rate), {x : Int64 => NodeV1("", 0)});
        lock_table = ArrayList<AtomicInt8>(capacity, {x : Int64 => AtomicInt8(0)});

        expansion_threshold = Int64(Float32(capacity) * load_factor);

        lock1_held.store(0);
    }
}
