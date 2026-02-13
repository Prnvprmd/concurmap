package my_map

import std.collection.ArrayList
import std.sync.ReentrantMutex
import std.sync.*
import std.convert.Parsable



class NodeV8Ref {
    public var node: NodeV6;

    NodeV8Ref(node: NodeV6) {
        this.node = node
    }

    public func get(): NodeV6 {
        return node;
    }
}

// Has array of locks
class TableV8 {
    public var init_capacity: Int64 = 8;
    public var capacity: Int64 = 8;
    public var load_factor: Float32;
    public var expansion_rate: Float32;
    public var buckets : ArrayList<AtomicOptionReference<NodeV8Ref>>;
    public var locks : ArrayList<ReentrantMutex>;

    TableV8(init_capacity : Int64
            , load_factor! : Float32 = 0.5
            , expansion_rate! : Float32 = 2.0) {
        buckets = ArrayList<AtomicOptionReference<NodeV8Ref>>(init_capacity, {x : Int64 => AtomicOptionReference<NodeV8Ref>(None)});
        locks = ArrayList<ReentrantMutex>(init_capacity, {x : Int64 => ReentrantMutex()});
        this.init_capacity = init_capacity;
        this.capacity = init_capacity;
        this.load_factor = load_factor;
        this.expansion_rate = expansion_rate;
    }

    public func isEmpty(idx : Int64) : Bool {
        if (let Some(NodeV8Ref) <- buckets[idx].load()) {
            return false;
        } else {
            return true;
        }
    }

    public func clear() {
        buckets = ArrayList<AtomicOptionReference<NodeV8Ref>>(init_capacity, {x : Int64 => AtomicOptionReference<NodeV8Ref>(None)});
        locks = ArrayList<ReentrantMutex>(init_capacity, {x : Int64 => ReentrantMutex()});
    }
}

// Open addressing with locks. Table is made up of AtomicOptionReference
class KeyValueV8 <: CustomMap {
    private var init_capacity: Int64;
    private var capacity: Int64;
    public let length = AtomicInt64(0);
    private var load_factor: Float32;
    private var expansion_rate: Float32;
    private var expansion_threshold : Int64;
    public var table_ref : AtomicReference<TableV8>;

    public let currently_expanding = AtomicInt64(0);
    public let resize_lock = ReentrantMutex();

    KeyValueV8(init_capacity! : Int64 = 8
            , load_factor! : Float32 = 0.5
            , expansion_rate! : Float32 = 2.0) {
        this.init_capacity = init_capacity;
        this.capacity = init_capacity;
        this.load_factor = load_factor;
        this.expansion_rate = expansion_rate;
        this.table_ref = AtomicReference(TableV8(init_capacity));
        this.expansion_threshold = Int64(Float32(table_ref.load().capacity) * table_ref.load().load_factor);
        // this.new_capacity = Int64(Float32(init_capacity) * table_ref.load().expansion_rate);
        // this.new_table_ref = AtomicReference(TableV6(new_capacity));
    }

    public func put(k: String, v: Int64): Unit {
        while(currently_expanding.load() == 1) {}

        var target_table = table_ref.load();
        var idx = idx_for(target_table.capacity, k);

        while(true) {
            target_table.locks[idx].lock();

            if(target_table.isEmpty(idx)) {
                break;
            }
            let node = target_table.buckets[idx].load().getOrThrow().get();
            if(node.getKey() == k) {
                node.setValue(v);
                target_table.locks[idx].unlock();
                return;
            }
            target_table.locks[idx].unlock();
            idx++;
            if(idx >= capacity) {idx = 0;}
        }
        target_table.buckets[idx].store(NodeV8Ref(NodeV6(k, v)))
        target_table.locks[idx].unlock();
        var len = length.fetchAdd(1);

        // maybe_trigger_expand();
        if(len >= Int64(Float32(target_table.capacity) * target_table.load_factor)){
            trigger_expand();
        }
    }


    public func get(k: String): Option<Int64> {
        while(currently_expanding.load() == 1) {}

        var target_table = table_ref.load();
        var idx = idx_for(target_table.capacity, k);

        while(true) {
            target_table.locks[idx].lock();

            if(target_table.isEmpty(idx)) {
                target_table.locks[idx].unlock();
                return None;
            }
            let node = target_table.buckets[idx].load().getOrThrow().get();
            if(node.getKey() == k) {
                let out = node.getValue();
                target_table.locks[idx].unlock();
                return out;
            }
            target_table.locks[idx].unlock();
            idx++;
            if(idx >= capacity) {idx = 0;}
        }
        return None;
    }

    public func expand() {
        var new_capacity = Int64(Float32(capacity) * expansion_rate);
        length.store(0);
        var len = 0;
        var new_table = TableV8(new_capacity);

        var old_table = table_ref.load();

        for(i in 0..old_table.capacity) {
            if(old_table.isEmpty(i)) {
                continue;
            }
            let node = old_table.buckets[i].load().getOrThrow().get();
            var key = node.getKey();
            var val = node.getValue();
            var idx = idx_for(new_capacity, key);
            while(!new_table.isEmpty(idx)) {
                idx++;
                if(idx >= new_capacity) {idx = 0;}
            }
            new_table.buckets[idx].store(NodeV8Ref(NodeV6(key, val)))
            len++;
            old_table.buckets[i].store(None)
        }
        old_table.clear();
        length.store(len);
        table_ref.store(new_table);
        capacity = new_capacity;
    }



    public func maybe_trigger_expand() {
        // var target_table = table_ref.load();
        // if(length.load() < Int64(Float32(target_table.capacity) * target_table.load_factor)) {
        //     return;
        // }
        // trigger_expand();
    }




    public func trigger_expand() {
        if(currently_expanding.compareAndSwap(0,1)) {
            expand();
            currently_expanding.store(0);
        }
    }


    public func getKeys(): ArrayList<String> {
        let res = ArrayList<String>();
        let table = table_ref.load()

        for(i in 0..table.capacity) {
            if(table.isEmpty(i)) {
                continue;
            }
            let node = table.buckets[i].load().getOrThrow().get();
            var key = node.getKey();
            res.append(key);
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
	
    public static func deserialize(str: String): KeyValueV8 {
        let splits = str.split("\n", removeEmpty: true)
        let keyValue = KeyValueV8()

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
        return table_ref.load().capacity;
    }

    public func get_size() : Int64 {
        return length.load();
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

    public func clear() : Unit {
        currently_expanding.store(1);

        length.store(0);
        table_ref.load().clear();
        // expansion_threshold = Int64(Float32(init_capacity) * table_ref.load().load_factor);

        currently_expanding.store(0);
    }

}
