package my_map

import std.collection.ArrayList
import std.sync.ReentrantMutex
import std.convert.*
import std.collection.*
import std.sync.*


class NodeV4p1 {
    NodeV4p1(
        private var key: String,
        private var value: Int64
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
    public func getKeyValue(): String {
        return "${key}: ${value}";
    }
}



class NodeV4p1Ref {
    public var node: NodeV4p1;
    public var next: Option<NodeV4p1Ref>;

    NodeV4p1Ref(node: NodeV4p1, next! : Option<NodeV4p1Ref> = None) {
        this.node = node
        this.next = next
    }

    public func get(): NodeV4p1 {
        return node;
    }

    public func hasNext(): Bool {
        if (let Some(_) <- next) { return true }
        return false
    }

    public func getNext(): Option<NodeV4p1Ref> {
        return next;
    }

    public func setNext(next_val: NodeV4p1Ref): Unit {
        next = Some(next_val)
    }

    public func clearNext(): Unit {
        next = None
    }
}

func create_node_ref(k: String, v: Int64, next!: Option<NodeV4p1Ref> = None) {
    return NodeV4p1Ref(NodeV4p1(k, v), next: next);
}

class BucketV4p1 {
    public let lock = ReentrantMutex();
    public let head_ref = AtomicOptionReference<NodeV4p1Ref>(None);

    public func isEmpty() : Bool {
        if (let Some(NodeV4p1Ref) <- head_ref.load()) {
            return false;
        } else {
            return true;
        }
    }

    public func print_list() : Unit {
        var curr_node = head_ref.load();
        while(let Some(NodeV4p1Ref) <- curr_node) {
            println("${curr_node.getOrThrow().get().getKeyValue()}")
            curr_node = curr_node.getOrThrow().getNext();
        }
    }

    public func clear() {
        head_ref.store(None);
    }
}

class TableV4p1 {
    public var init_capacity: Int64 = 8;
    public var capacity: Int64 = 8;
    public var load_factor: Float32;
    public var expansion_rate: Float32;
    public var buckets : ArrayList<BucketV4p1>;

    TableV4p1(init_capacity : Int64
            , load_factor! : Float32 = 0.5
            , expansion_rate! : Float32 = 2.0) {
        buckets = ArrayList<BucketV4p1>(init_capacity, {x : Int64 => BucketV4p1()});
        this.init_capacity = init_capacity;
        this.capacity = init_capacity;
        this.load_factor = load_factor;
        this.expansion_rate = expansion_rate;
    }
    public func clear() {
        buckets = ArrayList<BucketV4p1>(init_capacity, {x : Int64 => BucketV4p1()});
    }
}



class KeyValueV4p1 <: CustomMap {

    private var init_capacity: Int64;
    private var capacity: Int64;
    public let length = AtomicInt64(0);
    private var load_factor: Float32;
    private var expansion_rate: Float32;
    private var expansion_threshold : Int64;
    public var table_ref : AtomicReference<TableV4p1>;
    public var new_capacity : Int64;
    public var new_table_ref : AtomicReference<TableV4p1>;

    public let currently_expanding = AtomicInt64(-1);
    public let resize_lock = ReentrantMutex();

    KeyValueV4p1(init_capacity! : Int64 = 8
            , load_factor! : Float32 = 0.5
            , expansion_rate! : Float32 = 2.0) {
        this.init_capacity = init_capacity;
        this.capacity = init_capacity;
        this.load_factor = load_factor;
        this.expansion_rate = expansion_rate;
        this.table_ref = AtomicReference(TableV4p1(init_capacity));
        this.expansion_threshold = Int64(Float32(table_ref.load().capacity) * table_ref.load().load_factor);
        this.new_capacity = Int64(Float32(init_capacity) * table_ref.load().expansion_rate);
        this.new_table_ref = AtomicReference(TableV4p1(new_capacity));
    }

    public func get(k: String): Option<Int64> {
        var table0 = table_ref.load();

        var idx0 = idx_for(table0.capacity, k);
        var bucket0 = table0.buckets[idx0];
        bucket0.lock.lock();
        var node = bucket0.head_ref.load();
        while(let Some(NodeV4p1Ref) <- node) {
            if(node.getOrThrow().get().getKey() == k){
                bucket0.lock.unlock();
                return node.getOrThrow().get().getValue();
            }
            node = node.getOrThrow().getNext();
        }
        bucket0.lock.unlock();

        var ri = currently_expanding.load();

        if(ri != -1) {
            var table1 = table_ref.load();

            var idx1 = idx_for(table1.capacity, k);
            var bucket1 = table1.buckets[idx1];
            bucket1.lock.lock();
            node = bucket1.head_ref.load();
            while(let Some(NodeV4p1Ref) <- node) {
                if(node.getOrThrow().get().getKey() == k){
                    bucket1.lock.unlock();
                    return node.getOrThrow().get().getValue();
                }
                node = node.getOrThrow().getNext();
            }
            bucket1.lock.unlock();
        }

        return None;
    }

    public func put(k: String, v: Int64): Unit {
        var ri = currently_expanding.load();

        var target_table : TableV4p1;
        if(ri == -1){
            target_table = table_ref.load();
        } else {
            target_table = new_table_ref.load();
        }

        var idx = idx_for(target_table.capacity, k);
        var bucket = target_table.buckets[idx];
        bucket.lock.lock();

        var curr_node = bucket.head_ref.load();
        while(let Some(NodeV4p1Ref) <- curr_node) {
            if(curr_node.getOrThrow().get().getKey() == k){
                break;
            }
            curr_node = curr_node.getOrThrow().getNext();
        }

        if (let Some(NodeV4p1Ref) <- curr_node) {
            curr_node.getOrThrow().get().setValue(v);
            bucket.lock.unlock();
        } else {
            bucket.head_ref.store(NodeV4p1Ref(NodeV4p1(k, v), next : bucket.head_ref.load()));
            length.fetchAdd(1);
            bucket.lock.unlock();
            maybe_trigger_expand();
        }
        return;
    }
    
    public func expand() {
        currently_expanding.store(0);
        length.store(0);

        var oldT = table_ref.load();
        var newT = new_table_ref.load();

        for(bucket in oldT.buckets) {
            bucket.lock.lock();
            if(bucket.isEmpty()) {
                bucket.lock.unlock();
                continue;
            }
            var node = bucket.head_ref.load();

            while(let Some(NodeV4p1Ref) <- node) {
                var k = node.getOrThrow().get().getKey();
                var v = node.getOrThrow().get().getValue();
                var new_idx = idx_for(newT.capacity, k);
                var new_node = create_node_ref(k, v, next : newT.buckets[new_idx].head_ref.load());
                newT.buckets[new_idx].head_ref.store(new_node);
                length.fetchAdd(1);
                node = node.getOrThrow().getNext();
            }
            bucket.clear();
            bucket.lock.unlock();
        }
        oldT.clear();
        table_ref.store(newT);
        new_capacity = Int64(Float32(table_ref.load().capacity) * table_ref.load().expansion_rate);
        new_table_ref.store(TableV4p1(new_capacity))

        currently_expanding.store(-1);
    }

    public func maybe_trigger_expand() {
        var target_table = table_ref.load();
        if(length.load() < Int64(Float32(target_table.capacity) * target_table.load_factor)) {
            return;
        }
        trigger_expand();
    }

    public func trigger_expand() {
        if(resize_lock.tryLock() && currently_expanding.load() == -1) {
            expand();
            resize_lock.unlock();
        }
    }

    public func getKeys(): ArrayList<String> {
        let res = ArrayList<String>();
        for(bucket in table_ref.load().buckets) {
            if(bucket.isEmpty()) { continue; }
            var node = bucket.head_ref.load();
            while(let Some(NodeV4p1Ref) <- node) {
                res.append(node.getOrThrow().get().getKey());
                node = node.getOrThrow().getNext();
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
	
    public static func deserialize(str: String): KeyValueV4p1 {
        let splits = str.split("\n", removeEmpty: true)
        let keyValue = KeyValueV4p1()

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
        var oldT = table_ref.load();
        var newT = new_table_ref.load();

        for(bucket in oldT.buckets) {
            if(bucket.isEmpty()) { continue; }
            bucket.clear();
        }
        for(bucket in newT.buckets) {
            if(bucket.isEmpty()) { continue; }
            bucket.clear();
        }
        table_ref.store(TableV4p1(init_capacity));
        expansion_threshold = Int64(Float32(init_capacity) * table_ref.load().load_factor);
        new_capacity = Int64(Float32(init_capacity) * table_ref.load().expansion_rate);
        new_table_ref.store(TableV4p1(new_capacity));

        currently_expanding.store(-1);
    }

}

