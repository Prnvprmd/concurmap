package my_map

import std.collection.ArrayList
import std.sync.ReentrantMutex
import std.convert.Parsable
import std.collection.*
import std.sync.*


class NodeV6 {
    NodeV6(
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

class NodeV6Ref {
    public var node: NodeV6;
    public var next: Option<NodeV6Ref>;

    NodeV6Ref(node: NodeV6, next! : Option<NodeV6Ref> = None) {
        this.node = node
        this.next = next
    }

    public func get(): NodeV6 {
        return node;
    }

    public func hasNext(): Bool {
        if (let Some(_) <- next) { return true }
        return false
    }

    public func getNext(): Option<NodeV6Ref> {
        return next;
    }

    public func setNext(next_val: NodeV6Ref): Unit {
        next = Some(next_val)
    }

    public func clearNext(): Unit {
        next = None
    }
}

func create_node_ref(k: String, v: Int64, next!: Option<NodeV6Ref> = None) {
    return NodeV6Ref(NodeV6(k, v), next: next);
}

class BucketV6 {
    public let lock = ReentrantMutex();
    public let head_ref = AtomicOptionReference<NodeV6Ref>(None);

    public func isEmpty() : Bool {
        if (let Some(NodeV6Ref) <- head_ref.load()) {
            return false;
        } else {
            return true;
        }
    }

    public func print_list() : Unit {
        var curr_node = head_ref.load();
        while(let Some(NodeV6Ref) <- curr_node) {
            println("${curr_node.getOrThrow().get().getKeyValue()}")
            curr_node = curr_node.getOrThrow().getNext();
        }
    }

    public func clear() {
        head_ref.store(None);
    }
}

class TableV6 {
    public var init_capacity: Int64 = 8;
    public var capacity: Int64 = 8;
    public var load_factor: Float32;
    public var expansion_rate: Float32;
    public var buckets : ArrayList<BucketV6>;

    TableV6(init_capacity : Int64
            , load_factor! : Float32 = 0.5
            , expansion_rate! : Float32 = 2.0) {
        buckets = ArrayList<BucketV6>(init_capacity, {x : Int64 => BucketV6()});
        this.init_capacity = init_capacity;
        this.capacity = init_capacity;
        this.load_factor = load_factor;
        this.expansion_rate = expansion_rate;
    }
    public func clear() {
        buckets = ArrayList<BucketV6>(init_capacity, {x : Int64 => BucketV6()});
    }
}

// Closed chaining, lock in the bucket. Table is array of buckets. Buckets are linked list of Key Value Pairs
class KeyValueV6 <: CustomMap {

    private var init_capacity: Int64;
    private var capacity: Int64;
    public let length = AtomicInt64(0);
    private var load_factor: Float32;
    private var expansion_rate: Float32;
    private var expansion_threshold : Int64;
    public var table_ref : AtomicReference<TableV6>;

    public let currently_expanding = AtomicInt64(0);
    public let resize_lock = ReentrantMutex();

    KeyValueV6(init_capacity! : Int64 = 8
            , load_factor! : Float32 = 0.5
            , expansion_rate! : Float32 = 2.0) {
        this.init_capacity = init_capacity;
        this.capacity = init_capacity;
        this.load_factor = load_factor;
        this.expansion_rate = expansion_rate;
        this.table_ref = AtomicReference(TableV6(init_capacity));
        this.expansion_threshold = Int64(Float32(table_ref.load().capacity) * table_ref.load().load_factor);
    }

    public func put(k: String, v: Int64): Unit {
        while(currently_expanding.load() == 1) {}

        var target_table = table_ref.load();

        var idx = idx_for(target_table.capacity, k);
        var bucket = target_table.buckets[idx];
        bucket.lock.lock();

        var curr_node = bucket.head_ref.load();
        while(let Some(NodeV6Ref) <- curr_node) {
            if(curr_node.getOrThrow().get().getKey() == k){
                break;
            }
            curr_node = curr_node.getOrThrow().getNext();
        }

        if (let Some(NodeV6Ref) <- curr_node) {
            curr_node.getOrThrow().get().setValue(v);
            bucket.lock.unlock();
        } else {
            bucket.head_ref.store(NodeV6Ref(NodeV6(k, v), next : bucket.head_ref.load()));
            bucket.lock.unlock();
            length.fetchAdd(1);
            maybe_trigger_expand();
        }
        return;
    }

    public func get(k: String): Option<Int64> {
        while(currently_expanding.load() == 1) {}

        var table0 = table_ref.load();

        var idx0 = idx_for(table0.capacity, k);
        var bucket0 = table0.buckets[idx0];
        bucket0.lock.lock();
        var node = bucket0.head_ref.load();
        while(let Some(NodeV6Ref) <- node) {
            if(node.getOrThrow().get().getKey() == k){
                bucket0.lock.unlock();
                return node.getOrThrow().get().getValue();
            }
            node = node.getOrThrow().getNext();
        }
        bucket0.lock.unlock();

        return None;
    }

    public func expand() {
        length.store(0);

        var oldT = table_ref.load();
        var new_capacity = Int64(Float32(oldT.capacity) * oldT.expansion_rate);
        var newT = TableV6(new_capacity);

        for(bucket in oldT.buckets) {
            bucket.lock.lock();
            if(bucket.isEmpty()) {
                bucket.lock.unlock();
                continue;
            }
            var node = bucket.head_ref.load();

            while(let Some(NodeV6Ref) <- node) {
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
    }

    public func maybe_trigger_expand() {
        var target_table = table_ref.load();
        if(length.load() < Int64(Float32(target_table.capacity) * target_table.load_factor)) {
            return;
        }
        trigger_expand();
    }

    public func trigger_expand() {
        if(currently_expanding.compareAndSwap(0,1)) {
            expand();
            currently_expanding.store(0);
        }
    }

    public func getKeys(): ArrayList<String> {
        let res = ArrayList<String>();
        for(bucket in table_ref.load().buckets) {
            if(bucket.isEmpty()) { continue; }
            var node = bucket.head_ref.load();
            while(let Some(NodeV6Ref) <- node) {
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
	
    public static func deserialize(str: String): KeyValueV6 {
        let splits = str.split("\n", removeEmpty: true)
        let keyValue = KeyValueV6()

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
        var oldT = table_ref.load();

        for(bucket in oldT.buckets) {
            bucket.clear();
        }      
        table_ref.load().clear();
        table_ref.store(TableV6(init_capacity));
        expansion_threshold = Int64(Float32(init_capacity) * table_ref.load().load_factor);

        currently_expanding.store(0);
    }
}