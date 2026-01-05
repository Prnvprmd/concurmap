package my_map

import std.collection.ArrayList
import std.sync.ReentrantMutex
import std.convert.*
import std.collection.*
import std.sync.*




class TableV5 {
    public var init_capacity : Int64;
    public var capacity: Int64 = 8;
    public var load_factor: Float32;
    public var expansion_rate: Float32;
    public var buckets : ArrayList<NodeV1>;
    public var locks : ArrayList<AtomicInt8>;


    TableV5(init_capacity : Int64
            , load_factor! : Float32 = 0.5
            , expansion_rate! : Float32 = 2.0) {
        this.init_capacity = init_capacity;
        this.capacity = init_capacity;
        this.load_factor = load_factor;
        this.expansion_rate = expansion_rate;
        this.buckets = ArrayList<NodeV1>(init_capacity, {x : Int64 => NodeV1("",0)});
        this.locks = ArrayList<AtomicInt8>(init_capacity, {x : Int64 => AtomicInt8(0)});
    }

    public func clear() {
        this.buckets = ArrayList<NodeV1>(1, {x : Int64 => NodeV1("",0)});
        this.locks = ArrayList<AtomicInt8>(1, {x : Int64 => AtomicInt8(0)});
    }
}


class KeyValueV5 <: CustomMap {

    private var init_capacity: Int64;
    private var capacity: Int64;
    private var length = AtomicInt64(0);
    private var load_factor: Float32;
    private var expansion_rate: Float32;
    private var expansion_threshold : Int64;
    private var table : TableV5;
    private var new_table : TableV5;

    let lock1_held = AtomicInt8(0);     // 0 == free, 1 == held

    KeyValueV5(init_capacity! : Int64 = 8
            , load_factor! : Float32 = 0.5
            , expansion_rate! : Float32 = 2.0) {
        this.init_capacity = init_capacity;
        this.capacity = init_capacity
        this.load_factor = load_factor;
        this.expansion_rate = expansion_rate;
        this.expansion_threshold = Int64(Float32(capacity) * load_factor);
        this.table = TableV5(init_capacity, load_factor : load_factor, expansion_rate : expansion_rate);
        this.new_table = TableV5(Int64(Float32(capacity) * expansion_rate), load_factor : load_factor, expansion_rate : expansion_rate);
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

    private func acquire_lock2(table : TableV5, idx : Int64) {
        while(true) {
            // Fast-path: check Lock1 is free
            if(lock1_held.load() == 0) {
                // try to become the Lock2 owner (atomic)
                if(table.locks[idx].compareAndSwap(0, 1)) {
                    // We have claimed Lock2; verify Lock1 is still free
                    if(lock1_held.load() == 0) {
                        // println("Acquired Lock2 for ${idx}");
                        return;                 // success: Lock2 held by this thread
                    } else {
                        // Race: Lock1 was taken just now. Release and retry.
                        // Release lock2_owner and continue (with backoff)
                        table.locks[idx].store(0);
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
            if(lock1_held.load() == 0 && table.locks[idx].load() == 0) {
                // Attempt final quick claim while holding m_wait is NOT required,
                // but to reduce thundering herd we can attempt CAS here (still atomic).
                if(table.locks[idx].compareAndSwap(0, 1)) {
                    // mon.unlock();
                    // confirm Lock1 still free
                    if(lock1_held.load() == 0) {
                        return;
                    } else {
                        // lost race, release and retry
                        table.locks[idx].store(0);
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

    private func release_lock2(table : TableV5, idx : Int64) {
        table.locks[idx].store(0);
    }

    private func lookUpBucket(k: String): Int64 {
        var idx: Int64 = Int64(hash_function(k) % UInt64(capacity));
        return idx;
    }

    public func get(k: String): Option<Int64> {
        var bucket_idx =  Int64(hash_function(k) % UInt64(table.capacity));
        while(true) {
            table.locks[bucket_idx].store(1);
            if(table.buckets[bucket_idx].getKey() == "") {
                table.locks[bucket_idx].store(0);
                return None;
            }
            if (table.buckets[bucket_idx].getKey() == k) {
                let out = table.buckets[bucket_idx].getValue();
                table.locks[bucket_idx].store(0);
                return out;
            }
            table.locks[bucket_idx].store(0);
            bucket_idx++;
            if(bucket_idx >= table.capacity) {bucket_idx = 0;}
        }

        var currently_expanding = lock1_held.load();
        if(currently_expanding == 1) {
            bucket_idx =  Int64(hash_function(k) % UInt64(new_table.capacity));
            while(true) {
                new_table.locks[bucket_idx].store(1);
                if(new_table.buckets[bucket_idx].getKey() == "") {
                    new_table.locks[bucket_idx].store(0);
                    return None;
                }
                if (new_table.buckets[bucket_idx].getKey() == k) {
                    let out = new_table.buckets[bucket_idx].getValue();
                    new_table.locks[bucket_idx].store(0);
                    return out;
                }
                new_table.locks[bucket_idx].store(0);
                bucket_idx++;
                if(bucket_idx >= table.capacity) {bucket_idx = 0;}
            }
        }
        return None;
    }

    public func put(k: String, v: Int64): Unit {
        var bucket_idx : Int64;
        var local_table : TableV5;
        var currently_expanding = lock1_held.load();

        if(currently_expanding == 1) {
            local_table = new_table;
        } else {
            local_table = table;
        }
        bucket_idx =  Int64(hash_function(k) % UInt64(local_table.capacity));

        while(true) {
            acquire_lock2(local_table, bucket_idx);
            if(local_table.buckets[bucket_idx].getKey() == "") {
                release_lock2(local_table, bucket_idx);
                break;
            }
            if (local_table.buckets[bucket_idx].getKey() == k) {
                // Key already exists, Update value
                local_table.buckets[bucket_idx].setValue(v);
                release_lock2(local_table, bucket_idx);
                return;
            }
            release_lock2(local_table, bucket_idx);
            bucket_idx++;
            if(bucket_idx >= local_table.capacity) {bucket_idx = 0;}
        }
        acquire_lock2(local_table, bucket_idx);
        local_table.buckets[bucket_idx] = NodeV1(k, v);
        length.fetchAdd(1);
        release_lock2(local_table, bucket_idx);

        maybe_trigger_expand();
        return
    }


    public func expand() : Unit {
        var new_capacity = Int64(Float32(table.capacity) * expansion_rate);
        length.store(0);
        for(item_idx in 0..table.buckets.size){
            let item = table.buckets[item_idx];
            if (item.getKey() == "") { continue }
            var key = item.getKey();
            var val = item.getValue();
            var idx: Int64 = Int64(hash_function(key) % UInt64(new_capacity));
            while(new_table.buckets[idx].getKey() != "") {
                idx++;
                if(idx >= new_capacity) {idx = 0;}
            }
            new_table.buckets[idx] = NodeV1(key, val);
            length.fetchAdd(1);
        }

        capacity = new_capacity;
        table = new_table;
        expansion_threshold = Int64(Float32(table.capacity) * load_factor);
        new_table = TableV5(Int64(Float32(table.capacity) * expansion_rate), load_factor : load_factor, expansion_rate : expansion_rate);

    }

    public func maybe_trigger_expand() {
        if(length.load() < Int64(Float32(table.capacity) * table.load_factor)) {
            return;
        }
        trigger_expand();
    }

    public func trigger_expand() {
        acquire_lock1();
        expand();
        release_lock1();
    }
    
    public func getKeys(): ArrayList<String> {
        let res = ArrayList<String>()
        for(item in table.buckets) {
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
    
    public static func deserialize(str: String): KeyValueV5 {
        let splits = str.split("\n", removeEmpty: true)
        let keyValue = KeyValueV5()

        for (actions in splits) {
            let words = actions.split(" ")
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


    public func get_capacity() : Int64 {
        return capacity;
    }

    public func get_size() : Int64 {
        return length.load();
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

    public func clear() : Unit {
        this.capacity = init_capacity
        this.expansion_threshold = Int64(Float32(this.capacity) * load_factor);
        this.table = TableV5(init_capacity, load_factor : load_factor, expansion_rate : expansion_rate);
        this.new_table = TableV5(Int64(Float32(capacity) * expansion_rate), load_factor : load_factor, expansion_rate : expansion_rate);
    }

}