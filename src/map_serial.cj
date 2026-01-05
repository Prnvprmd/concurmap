package my_map

import std.collection.ArrayList
import std.sync.ReentrantMutex
import std.convert.*
import std.collection.*



class Node {
    Node(
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

abstract class CustomMap {
    public func expand() : Unit;
    public func put(k: String, v: Int64): Unit;
    public func get(k: String): Option<Int64>;
    public func serialize(): String;
    public func new_deserialize(lines: ArrayList<String>): Unit;
    public func get_capacity() : Int64;
    public func get_size() : Int64
    public func getKeys(): ArrayList<String>;
    public func trigger_expand() : Unit;

    public func clear() : Unit;
}


class KeyValueSerial <: CustomMap {

    private var capacity: Int64 = 16;
    private var length: Int64 = 0;
    private let load_factor: Float32 = 0.5;
    private let expansion_rate: Int64 = 2;
    private var table = ArrayList<Node>(capacity, {x : Int64 => Node("", 0)});
    private var new_table = ArrayList<Node>(capacity * expansion_rate, {x : Int64 => Node("", 0)});

    let mutex = ReentrantMutex();

    KeyValueSerial() { }

    private func compare(a: String, b: String): Int64 {
        if (a == b) { return 0 }
        if (a < b) { return -1 }
        return 1
    }

    public func expand() : Unit {
        var new_capacity = capacity * expansion_rate;
        length = 0;
        
        for (key in getKeys()) {
            var idx: Int64 = Int64(hash_function(key) % UInt64(new_capacity));
            while(new_table[idx].getKey() != "") {
                idx++;
                if(idx >= new_capacity) {idx = 0;}
            }
            new_table[idx] = Node(key, get(key).getOrThrow());
            length++;
        }
        capacity = new_capacity;
        table = new_table;
        new_table = ArrayList<Node>(capacity * expansion_rate, {x : Int64 => Node("", 0)});
    }

    private func lookUpBucket(k: String): Int64 {
        var idx: Int64 = Int64(hash_function(k) % UInt64(capacity));
        return idx;
    }

    public func put(k: String, v: Int64): Unit {

        var bucket_idx = lookUpBucket(k);

        while(table[bucket_idx].getKey() != "") {
            if (compare(table[bucket_idx].getKey(), k) == 0) {
                table[bucket_idx].setValue(v);
                return;
            }
            bucket_idx++;
            if(bucket_idx >= capacity) {bucket_idx = 0;}
        }
        table[bucket_idx] = Node(k, v);
        length++;

        if(Float32(length) > Float32(capacity) * load_factor) {
            trigger_expand();
        }

        return
    }

    public func trigger_expand() {
        expand();
    }

    public func get(k: String): Option<Int64> {
        var bucket_idx = lookUpBucket(k);

        while(table[bucket_idx].getKey() != "") {
            if (compare(table[bucket_idx].getKey(), k) == 0) {
                return table[bucket_idx].getValue();
            }
            bucket_idx++;
            if(bucket_idx >= capacity) {bucket_idx = 0;}
        }
        return None;
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

    public static func deserialize(str: String): KeyValueSerial {
        let splits = str.split("\n", removeEmpty: true)
        let keyValue = KeyValueSerial()

        var node: Option<Node> = None

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
        return length;
    }

    public func clear() : Unit {
        capacity = 16;
        length = 0;
        table = ArrayList<Node>(capacity, {x : Int64 => Node("", 0)});
        new_table = ArrayList<Node>(capacity * expansion_rate, {x : Int64 => Node("", 0)});
    }
}
