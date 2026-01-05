package my_map

import std.collection.ArrayList
import std.sync.ReentrantMutex
import std.convert.*
import std.collection.*
import std.sync.*


class NodeV3 {
    NodeV3(
        private var key: String,
        private var value: Int64,
        private var next! : Option<NodeV3> = None
    ) { }

    public func getKey(): String {
        return key;
    }

    public func getValue(): Int64 {
        return value;
    }

    public func setKey(newKey: String): Unit {
        key = newKey;
    }
    public func setValue(newValue: Int64): Unit {
        value = newValue;
    }
    public operator func ==(right : NodeV3) {
        return key == right.getKey() && value == right.getValue();
    }
    public func getNext() : Option<NodeV3>{
        // return next;
        return match (next) {
            case Some(NodeV3) => next 
            case None => NodeV3("",0)        // matched
        }
    }
    public func setNext(n : Option<NodeV3>) {
        next = n;
    }
}


class BucketV3 {
    public let lock = ReentrantMutex();
    public var head = AtomicReference(NodeV3("", 0));
    public var migrated = AtomicBool(false);
}

class TableV3 {
    public var capacity: Int64 = 8;
    public var load_factor: Float32;
    public var expansion_rate: Float32;
    public var buckets : ArrayList<BucketV3>;

    TableV3(init_capacity : Int64
            , load_factor! : Float32 = 0.5
            , expansion_rate! : Float32 = 2.0) {
        buckets = ArrayList<BucketV3>(init_capacity, {x : Int64 => BucketV3()});
        this.capacity = init_capacity;
        this.load_factor = load_factor;
        this.expansion_rate = expansion_rate;
    }
}


class KeyValueV3 <: CustomMap {
    private var init_capacity: Int64;
    private var capacity: Int64;
    public let length = AtomicInt64(0);
    private var load_factor: Float32;
    private var expansion_rate: Float32;
    public var table : TableV3;
    public var table_ptr : AtomicReference<TableV3>;
    private var expansion_threshold : Int64;

    public let resize_lock = ReentrantMutex();
    public let resize_in_progress = AtomicInt64(0);
    public let expansion_counter = AtomicInt64(0);

    KeyValueV3(init_capacity! : Int64 = 8
            , load_factor! : Float32 = 0.5
            , expansion_rate! : Float32 = 2.0) {
        this.init_capacity = init_capacity;
        this.capacity = init_capacity;
        this.load_factor = load_factor;
        this.expansion_rate = expansion_rate;
        table = TableV3(init_capacity);
        table_ptr = AtomicReference(table);
        expansion_threshold = Int64(Float32(table_ptr.load().capacity) * table_ptr.load().load_factor);
    }

    public func idx_for(capacity : Int64, key : String) {
        return Int64(hash_function(key) % UInt64(capacity));
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


    public func get(k: String): Option<Int64> {
        var v : Option<Int64> = None;
        while(true) {

            var T = table_ptr.load();
            var expansion_counter_init = expansion_counter.load();
            var idx = idx_for(T.capacity, k);
            var B = T.buckets[idx];
            B.lock.lock();

            if(resize_in_progress.load() > 0) {
                continue;
            }

            var head = B.head.load();

            var node = head;
            while(node.getKey() != "") {
                if(node.getKey() == k) {
                    v = node.getValue();
                    break;
                }
                node = node.getNext().getOrThrow();
            }

            var head2 = B.head.load();

            var expansion_counter_now = expansion_counter.load();

            if(expansion_counter_init == expansion_counter_now && head.getValue() == head2.getValue()) {
                B.lock.unlock();
                return v;
            }
            B.lock.unlock();
            // pause if needed
        }
        return None;
    }

    public func put(k: String, v: Int64): Unit {
        while(true) {

            var T = table_ptr.load();
            var expansion_counter_init = expansion_counter.load();
            var idx = idx_for(T.capacity, k);
            var B = T.buckets[idx];

            if(resize_in_progress.load() > 0) {
                continue;
            }

            B.lock.lock();

            var expansion_counter_now = expansion_counter.load();
            if(expansion_counter_init != expansion_counter_now) {
                B.lock.unlock();
                continue;
            }

            var node = B.head.load();
            var prev : NodeV3 = node;
            while(node.getKey() != "" && node.getKey() != k){
                prev = node;
                node = node.getNext().getOrThrow();
            }

            if(node.getKey() != "") {
                // update existing entry
                node.setValue(v);
                B.lock.unlock();
                return;
            } else {
                // insert new node
                B.head.store(NodeV3(k,v, next : B.head.load()));
                var _ = length.fetchAdd(1);
                B.lock.unlock();
                maybe_trigger_expand();
                return;
            }
        }
        return;
    }

    public func expand() {
        if(!resize_lock.tryLock()) {
            return;
        }
        length.store(0);

        var _ = resize_in_progress.fetchAdd(1);
        _ = expansion_counter.fetchAdd(1);

        var oldT = table_ptr.load();
        var newCap = Int64(Float32(oldT.capacity) * oldT.expansion_rate)
        var newT = TableV3(newCap);

        for(bucket in oldT.buckets) {
            bucket.lock.lock();
            var node = bucket.head.load();
            var k = node.getKey();
            if(k == "") {
                bucket.lock.unlock();
                continue;
            }
            while(node.getKey() != "") {
                var next_node = node.getNext().getOrThrow();
                var new_idx = idx_for(newCap, node.getKey());
                newT.buckets[new_idx].head.store(NodeV3(node.getKey(),node.getValue(), next : newT.buckets[new_idx].head.load()));
                _ = length.fetchAdd(1);
                node = next_node;
            }
            bucket.head.store(NodeV3("",0));
            bucket.migrated.store(true);
            bucket.lock.unlock();
        }
        table = newT;
        table_ptr.store(table);
        expansion_threshold = Int64(Float32(table_ptr.load().capacity) * table_ptr.load().load_factor);
        _ = resize_in_progress.fetchSub(1);
    }

    public func maybe_trigger_expand() {
        if(length.load() < expansion_threshold) {
            return;
        }
        trigger_expand();
    }

    public func trigger_expand() {
        if(resize_lock.tryLock()) {
            expand();
            resize_lock.unlock();
        } 
    }

    public func getKeys(): ArrayList<String> {
        let res = ArrayList<String>()
        for(bucket in table_ptr.load().buckets) {
            var node = bucket.head.load();
            if (node.getKey() == "") { continue }
            while(node.getKey() != "") {
                res.append(node.getKey())
                node = node.getNext().getOrThrow();
            }
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
	
    public static func deserialize(str: String): KeyValueV3 {
        let splits = str.split("\n", removeEmpty: true)
        let keyValue = KeyValueV3()

        var node: Option<NodeV3> = None

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


    public func get_capacity() : Int64 {
        return table_ptr.load().capacity;
    }

    public func get_size() : Int64 {
        return length.load();
    }

    public func clear() : Unit {
        length.store(0);
        table = TableV3(init_capacity);
        table_ptr = AtomicReference(table);
        expansion_threshold = Int64(Float32(table_ptr.load().capacity) * table_ptr.load().load_factor);

        resize_in_progress.store(0);
        expansion_counter.store(0);
    }
}

