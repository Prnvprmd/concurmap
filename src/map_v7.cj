package my_map

import std.collection.ArrayList
import std.sync.ReentrantMutex
import std.convert.*
import std.collection.*
import std.sync.*



class NodeV7 {
    NodeV7(
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




// // Open addressing with locks. Table is an arraylist, debuggable
// class KeyValueV7 <: CustomMap {
//     private var init_capacity: Int64;
//     private var capacity: Int64;
//     public let length = AtomicInt64(0);
//     private var load_factor: Float32;
//     private var expansion_rate: Float32;
//     private var expansion_threshold : Int64;
//     public var table : ArrayList<Option<NodeV7>>;
//     public var locks : ArrayList<ReentrantMutex>;
//     public var lock_ids : ArrayList<AtomicInt64>;

//     public let currently_expanding = AtomicInt64(0);
//     public let resize_lock = ReentrantMutex();

//     KeyValueV7(init_capacity! : Int64 = 8
//             , load_factor! : Float32 = 0.5
//             , expansion_rate! : Float32 = 2.0) {
//         this.init_capacity = init_capacity;
//         this.capacity = init_capacity;
//         this.load_factor = load_factor;
//         this.expansion_rate = expansion_rate;
//         this.table = ArrayList<Option<NodeV7>>(init_capacity, {x : Int64 => (None)});
//         this.locks = ArrayList<ReentrantMutex>(init_capacity, {x : Int64 => ReentrantMutex()});
//         this.lock_ids = ArrayList<AtomicInt64>(init_capacity, {x : Int64 => AtomicInt64(-1)});
//         this.expansion_threshold = Int64(Float32(capacity) * load_factor);
//         // this.new_capacity = Int64(Float32(init_capacity) * table_ref.load().expansion_rate);
//         // this.new_table_ref = AtomicReference(TableV6(new_capacity));
//     }

//     public func put(k: String, val: Int64): Unit {
//         while(currently_expanding.load() == 1) {}

//         var idx = idx_for(capacity, k);

//         while(true) {
//             locks[idx].lock();
//             lock_ids[idx].store(Thread.currentThread.id);
//             // while(!locks[idx].compareAndSwap(-1, Thread.currentThread.id)) {}

//             if (let Some(v) <- table[idx]) {
//                 // Not None
//                 if (table[idx].getOrThrow().getKey() == k) {
//                     table[idx].getOrThrow().setValue(val)
//                     // if(!lock_ids[idx].compareAndSwap(Thread.currentThread.id, -1)){
//                     //     println("Point 1; ${lock_ids[idx].load()} != ${Thread.currentThread.id}")
//                     // }
//                     try{
//                         locks[idx].unlock();
//                         // lock_ids[idx].store(-1);
//                     } catch (e : IllegalSynchronizationStateException) {
//                         println("Point 1; ${lock_ids[idx].load()} != ${Thread.currentThread.id}")
//                     }
//                     return;
//                 }
//             } else {
//                 // None, empty
//                 break;
//             }
//             idx++;
//             // if(!lock_ids[idx-1].compareAndSwap(Thread.currentThread.id, -1)){
//             //     println("Point 2; ${lock_ids[idx-1].load()} != ${Thread.currentThread.id}")
//             // }
//             try{
//                 locks[idx-1].unlock();
//                 // lock_ids[idx-1].store(-1);
//             } catch (e : IllegalSynchronizationStateException) {
//                 println("Point 2; ${lock_ids[idx-1].load()} != ${Thread.currentThread.id}")
//             }
//             if(idx >= capacity) {idx = 0;}
//         }
//         table[idx] = NodeV7(k, val)
//         // if(!lock_ids[idx].compareAndSwap(Thread.currentThread.id, -1)){
//         //     println("Point 3; ${lock_ids[idx].load()} != ${Thread.currentThread.id}")
//         // }
//         try{
//             locks[idx].unlock();
//             // lock_ids[idx].store(-1);
//         } catch (e : IllegalSynchronizationStateException) {
//             println("Point 3; ${lock_ids[idx].load()} != ${Thread.currentThread.id}")
//         }
        
//         var len = length.fetchAdd(1);

//         // maybe_trigger_expand();
//         if(len >= Int64(Float32(capacity) * load_factor)){
//             trigger_expand();
//         }
//     }

//     public func get(k: String): Option<Int64> {
//         while(currently_expanding.load() == 1) {}

//         var idx = idx_for(capacity, k);

//         while(true) {
//             locks[idx].lock();
//             lock_ids[idx].store(Thread.currentThread.id);

//             if (let Some(v) <- table[idx]) {
//                 // Not None
//                 if (table[idx].getOrThrow().getKey() == k) {
//                     let out = table[idx].getOrThrow().getValue()
//                     // if(!lock_ids[idx].compareAndSwap(Thread.currentThread.id, -1)){
//                     //     println("Point 4; ${lock_ids[idx].load()} != ${Thread.currentThread.id}")
//                     // }
//                     try {
//                         locks[idx].unlock();
//                         // lock_ids[idx].store(-1);
//                     } catch (e : IllegalSynchronizationStateException) {
//                         println("Point 4; ${lock_ids[idx].load()} != ${Thread.currentThread.id}")
//                     }
//                     return out;
//                 }
//             } else {
//                 // None, empty
//                 // if(!lock_ids[idx].compareAndSwap(Thread.currentThread.id, -1)){
//                 //     println("Point 5; ${lock_ids[idx].load()} != ${Thread.currentThread.id}")
//                 // }
//                 try {
//                     locks[idx].unlock();
//                     // lock_ids[idx].store(-1);
//                 } catch (e : IllegalSynchronizationStateException) {
//                     println("Point 5; ${lock_ids[idx].load()} != ${Thread.currentThread.id}")
//                 }
//                 return None;
//             }
//             idx++;
//             // if(!lock_ids[idx-1].compareAndSwap(Thread.currentThread.id, -1)){
//             //     println("Point 6; ${lock_ids[idx-1].load()} != ${Thread.currentThread.id}")
//             // }
//             try {
//                 locks[idx-1].unlock();
//                 // lock_ids[idx-1].store(-1);
//             } catch (e : IllegalSynchronizationStateException) {
//                 println("Point 6; ${lock_ids[idx-1].load()} != ${Thread.currentThread.id}")
//             }
//             if(idx >= capacity) {idx = 0;}
//         }
//         return None;
//     }

//     public func expand() {
//         var new_capacity = Int64(Float32(capacity) * expansion_rate);
//         length.store(0);
//         var len = 0;
//         var new_table = ArrayList<Option<NodeV7>>(new_capacity, {x : Int64 => (None)});

//         for(i in 0..capacity) {
//             if (let Some(v) <- table[i]) {} else {
//                 // None, empty
//                 continue;
//             }
//             let node = table[i].getOrThrow();
//             var key = node.getKey();
//             var val = node.getValue();
//             var idx = idx_for(new_capacity, key);

//             while(let Some(v) <- new_table[idx]) {
//                 idx++;
//                 if(idx >= new_capacity) {idx = 0;}
//             }

//             new_table[idx] = NodeV7(key, val);
//             len++;
//             table[i] = None;
//         }
//         table = new_table;
//         locks = ArrayList<ReentrantMutex>(new_capacity, {x : Int64 => ReentrantMutex()});
//         lock_ids = ArrayList<AtomicInt64>(new_capacity, {x : Int64 => AtomicInt64(-1)});
//         length.store(len);
//         capacity = new_capacity;
//     }

//     public func maybe_trigger_expand() {}

//     public func trigger_expand() {
//         if(currently_expanding.compareAndSwap(0,1)) {
//             expand();
//             currently_expanding.store(0);
//         }
//     }


//     public func getKeys(): ArrayList<String> {
//         let res = ArrayList<String>();

//         for(i in 0..capacity) {
//             if (let Some(v) <- table[i]) {} else {
//                 // None, empty
//                 continue;
//             }
//             let node = table[i].getOrThrow();
//             var key = node.getKey();
//             res.append(key);
//         }

//         return res
//     }

//     public func serialize(): String {
//         var output = StringBuilder(16000000)
//         for (key in getKeys()) {
//             output.append(key)
//             output.append(' ')
//             output.append(get(key).getOrThrow())
//             output.append('\n')
//         }
//         return output.toString()
        
//     }
	
//     public static func deserialize(str: String): KeyValueV7 {
//         let splits = str.split("\n", removeEmpty: true)
//         let keyValue = KeyValueV7()

//         for (split in splits) {
//             let words = split.split(" ")
//             let key = words[0]
//             let value = Int64.parse(words[1])

//             keyValue.put(key, value)
//         }
//         return keyValue
//     }

//     public func new_deserialize(lines: ArrayList<String>): Unit {
//         for (split in lines) {
//             let words = split.split(" ")
//             if(words.size == 3) {
//                 let key = words[1]
//                 let value = Int64.parse(words[2])
//                 put(key, value);
//             } else {
//                 let key = words[1]
//                 get(key);
//             }
//         }
//     }

//     public func get_capacity() : Int64 {
//         return capacity;
//     }

//     public func get_size() : Int64 {
//         return length.load();
//     }

//     public func idx_for(capacity : Int64, key : String) {
//         return Int64(hash_function(key) % UInt64(capacity));
//     }

//     @OverflowWrapping
//     private func hash_function(s: String): UInt64 {
//         let offset: UInt64 = 14695981039346656037;
//         let prime: UInt64 = 1099511628211;
//         var hash_value: UInt64 = offset;
//         for (c in s) {
//             hash_value ^= UInt64(UInt32(c));
//             hash_value *= prime;
//         }
//         return hash_value;
//     }

//     public func clear() : Unit {
//         currently_expanding.store(1);

//         length.store(0);
//         capacity = init_capacity;
//         table = ArrayList<Option<NodeV7>>(init_capacity, {x : Int64 => (None)});
//         locks = ArrayList<ReentrantMutex>(init_capacity, {x : Int64 => ReentrantMutex()});
//         lock_ids = ArrayList<AtomicInt64>(init_capacity, {x : Int64 => AtomicInt64(-1)});

//         currently_expanding.store(0);
//     }

// }


// Open addressing with locks. Table is an arraylist
class KeyValueV7 <: CustomMap {
    private var init_capacity: Int64;
    private var capacity: Int64;
    public let length = AtomicInt64(0);
    private var load_factor: Float32;
    private var expansion_rate: Float32;
    private var expansion_threshold : Int64;
    public var table : ArrayList<Option<NodeV7>>;
    public var locks : ArrayList<ReentrantMutex>;

    public let currently_expanding = AtomicInt64(0);
    public let resize_lock = ReentrantMutex();
    public let threads_in_critical_zone : AtomicInt64;

    KeyValueV7(init_capacity! : Int64 = 8
            , load_factor! : Float32 = 0.5
            , expansion_rate! : Float32 = 2.0) {
        this.init_capacity = init_capacity;
        this.capacity = init_capacity;
        this.load_factor = load_factor;
        this.expansion_rate = expansion_rate;
        this.table = ArrayList<Option<NodeV7>>(init_capacity, {x : Int64 => (None)});
        this.locks = ArrayList<ReentrantMutex>(init_capacity, {x : Int64 => ReentrantMutex()});
        this.expansion_threshold = Int64(Float32(capacity) * load_factor);
        this.threads_in_critical_zone = AtomicInt64(0);
        // this.new_capacity = Int64(Float32(init_capacity) * table_ref.load().expansion_rate);
        // this.new_table_ref = AtomicReference(TableV6(new_capacity));
    }

    public func put(k: String, val: Int64): Unit {
        while(currently_expanding.load() == 1) {}
        threads_in_critical_zone.fetchAdd(1);

        var idx = idx_for(capacity, k);

        while(true) {
            locks[idx].lock();

            if (let Some(v) <- table[idx]) {
                // Not None
                if (table[idx].getOrThrow().getKey() == k) {
                    table[idx].getOrThrow().setValue(val)
                    threads_in_critical_zone.fetchSub(1);
                    locks[idx].unlock();
                    return;
                }
            } else {
                // None, empty
                break;
            }
            idx++;
            // threads_in_critical_zone.fetchSub(1);
            locks[idx-1].unlock();
            if(idx >= capacity) {idx = 0;}
        }
        table[idx] = NodeV7(k, val)
        // threads_in_critical_zone.fetchSub(1);
        locks[idx].unlock();
        var len = length.fetchAdd(1);

        threads_in_critical_zone.fetchSub(1);
        // maybe_trigger_expand();
        if(len >= Int64(Float32(capacity) * load_factor)){
            trigger_expand();
        }
    }

    public func get(k: String): Option<Int64> {
        while(currently_expanding.load() == 1) {}
        threads_in_critical_zone.fetchAdd(1);

        var idx = idx_for(capacity, k);

        while(true) {
            locks[idx].lock();

            if (let Some(v) <- table[idx]) {
                // Not None
                if (table[idx].getOrThrow().getKey() == k) {
                    let out = table[idx].getOrThrow().getValue()
                    threads_in_critical_zone.fetchSub(1);
                    locks[idx].unlock();
                    return out;
                }
            } else {
                // None, empty
                threads_in_critical_zone.fetchSub(1);
                locks[idx].unlock();
                return None;
            }
            idx++;
            // threads_in_critical_zone.fetchSub(1);
            locks[idx-1].unlock();
            if(idx >= capacity) {idx = 0;}
        }
        threads_in_critical_zone.fetchSub(1);
        return None;
    }

    public func expand() {
        var new_capacity = Int64(Float32(capacity) * expansion_rate);
        length.store(0);
        var len = 0;
        var new_table = ArrayList<Option<NodeV7>>(new_capacity, {x : Int64 => (None)});

        for(i in 0..capacity) {
            if (let Some(v) <- table[i]) {} else {
                // None, empty
                continue;
            }
            let node = table[i].getOrThrow();
            var key = node.getKey();
            var val = node.getValue();
            var idx = idx_for(new_capacity, key);

            while(let Some(v) <- new_table[idx]) {
                idx++;
                if(idx >= new_capacity) {idx = 0;}
            }

            new_table[idx] = NodeV7(key, val);
            len++;
            table[i] = None;
        }
        table = new_table;
        locks = ArrayList<ReentrantMutex>(new_capacity, {x : Int64 => ReentrantMutex()});
        length.store(len);
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
            // if(!threads_in_critical_zone.compareAndSwap(0,0)) {
            //     // println("Currently ${threads_in_critical_zone.load()} threads in critical zone")
            //     while(threads_in_critical_zone.load() != 0) {}
            //     // println("After spin, Currently ${threads_in_critical_zone.load()} threads in critical zone")
            // }
            while(threads_in_critical_zone.load() != 0) {}
            expand();
            currently_expanding.store(0);
        }
    }


    public func getKeys(): ArrayList<String> {
        let res = ArrayList<String>();

        for(i in 0..capacity) {
            if (let Some(v) <- table[i]) {} else {
                // None, empty
                continue;
            }
            let node = table[i].getOrThrow();
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
	
    public static func deserialize(str: String): KeyValueV7 {
        let splits = str.split("\n", removeEmpty: true)
        let keyValue = KeyValueV7()

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
        return capacity;
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
        capacity = init_capacity;
        table = ArrayList<Option<NodeV7>>(init_capacity, {x : Int64 => (None)});
        locks = ArrayList<ReentrantMutex>(init_capacity, {x : Int64 => ReentrantMutex()});

        currently_expanding.store(0);
    }

}
