package my_map

import std.collection.ArrayList
import std.sync.ReentrantMutex
import std.convert.*
import std.collection.*
import std.sync.*
import std.time.*

class NodeV1 {
    NodeV1(
        private let key: String,
        private var value: Int64
    ) { }

    public func getKey(): String {
        return key;
    }

    public func getValue(): Int64 {
        return value;
    }

    public func setValue(newValue: Int64): Unit {
        value = newValue;
    }
}


class KeyValueV1 <: CustomMap  {

    private var init_capacity: Int64;
    private var capacity: Int64;
    public let length = AtomicInt64(0);
    private var load_factor: Float32;
    private var expansion_rate: Float32;
    private var table : ArrayList<NodeV1>;
    private var new_table : ArrayList<NodeV1>;
    private var lock_table : ArrayList<ReentrantMutex>;

    private let Global_lock = ReentrantMutex();
    private var GlobalLocked = false;

    KeyValueV1(init_capacity! : Int64 = 8
            , load_factor! : Float32 = 0.5
            , expansion_rate! : Float32 = 2.0) {
        this.init_capacity = init_capacity;
        capacity = init_capacity;
        this.load_factor = load_factor;
        this.expansion_rate = expansion_rate;

        table = ArrayList<NodeV1>(capacity, {x : Int64 => NodeV1("", 0)});
        new_table = ArrayList<NodeV1>(1, {x : Int64 => NodeV1("", 0)});
        lock_table = ArrayList<ReentrantMutex>(capacity, {x : Int64 => ReentrantMutex()});
    }

    private func lockTable() {
        Global_lock.lock();
        GlobalLocked = true;
    }

    private func unlockTable() {
        GlobalLocked = false;
        Global_lock.unlock();
    }

    private func compare(a: String, b: String): Int64 {
        if (a == b) { return 0 }
        if (a < b) { return -1 }
        return 1
    }

    public func expand() {
        var new_capacity = Int64(Float32(capacity) * expansion_rate);
        length.store(0);
        new_table = ArrayList<NodeV1>(new_capacity, {x : Int64 => NodeV1("", 0)});
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
        lock_table = ArrayList<ReentrantMutex>(Int64(capacity), {x : Int64 => ReentrantMutex()});
        table = new_table;
        new_table = ArrayList<NodeV1>(1, {x : Int64 => NodeV1("", 0)});
    }

    private func lookUpBucket(k: String): Int64 {
        var idx: Int64 = Int64(hash_function(k) % UInt64(capacity));
        return idx;
    }

    public func put(k: String, v: Int64): Unit {
        while(true){
            if(Global_lock.tryLock()) {
                Global_lock.unlock();
                var bucket_idx = lookUpBucket(k);

                while(true) {
                    lock_table[bucket_idx].lock();
                    if(table[bucket_idx].getKey() == "") {
                        lock_table[bucket_idx].unlock();
                        break;
                    }
                    if (compare(table[bucket_idx].getKey(), k) == 0) {
                        table[bucket_idx].setValue(v);
                        lock_table[bucket_idx].unlock();
                        return;
                    }
                    lock_table[bucket_idx].unlock();
                    bucket_idx++;
                    if(bucket_idx >= capacity) {bucket_idx = 0;}
                }
                lock_table[bucket_idx].lock();
                table[bucket_idx] = NodeV1(k, v);
                length.fetchAdd(1);
                lock_table[bucket_idx].unlock();
                break;
            }
        }

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
        if(Global_lock.tryLock()) {
            expand();
            unlockTable();
        }
    }

    public func get(k: String): Option<Int64> {

        while(true) {
            if(Global_lock.tryLock()) {
                Global_lock.unlock();

                var bucket_idx = lookUpBucket(k);

                while(true) {
                    lock_table[bucket_idx].lock();
                    if(table[bucket_idx].getKey() == "") {
                        lock_table[bucket_idx].unlock();
                        return None;
                    }
                    if (compare(table[bucket_idx].getKey(), k) == 0) {
                        let out = table[bucket_idx].getValue();
                        lock_table[bucket_idx].unlock();
                        return out;
                    }
                    lock_table[bucket_idx].unlock();
                    bucket_idx++;
                    if(bucket_idx >= capacity) {bucket_idx = 0;}
                }
            }
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
	
    public static func deserialize(str: String): KeyValueV1 {
        let splits = str.split("\n", removeEmpty: true)
        let keyValue = KeyValueV1()

        var node: Option<NodeV1> = None

        for (split in splits) {
            let words = split.split(" ")
            let key = words[0]
            let value = Int64.parse(words[1])

            keyValue.put(key, value)
        }
        return keyValue
    }

    public func new_deserialize(lines: ArrayList<String>): Unit {
        for (split in lines) {
            let words = split.split(" ")
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
        while(true){
            if(Global_lock.tryLock()) {
                Global_lock.unlock();
                break;
            }
        }

        capacity = init_capacity;
        length.store(0);
        table = ArrayList<NodeV1>(capacity, {x : Int64 => NodeV1("", 0)});
        new_table = ArrayList<NodeV1>(1, {x : Int64 => NodeV1("", 0)});
    }
}
