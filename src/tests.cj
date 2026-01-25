package my_map

import std.collection.ArrayList
import std.collection.concurrent.*
import std.sync.*
import std.convert.*
import std.time.*
import std.fs.*
import std.io.SeekPosition
import std.collection.*
import std.random.*
import std.math.*


open class DeadlockException <: Exception {
    public init() {
        super("This is DeadlockException.")
    }
    public init(message: String) {
        super(message)
    }
    public open override func getClassName(): String {
        "DeadlockException"
    }
}


class HashMapTests {

    private let allTests = HashMap<String, () -> Unit>()
    private let performanceTests = HashMap<String, () -> Unit>()
    private let serialTests = HashMap<String, () -> Unit>()
    private let parallelTests = HashMap<String, () -> Unit>()
    private let correctnessTests = HashMap<String, () -> Unit>()

    private let map: CustomMap;

    HashMapTests(hashmap: CustomMap) {
        map = hashmap;
        registerTests();
    }

    public func registerTests() {
        performanceTests.put("getOperationTimes",{ => getOperationTimes()})
        performanceTests.put("parallelPerformanceTest",{ => parallelPerformanceTest()})
        parallelTests.put("parallelStressTest",{ => parallelStressTest()});

        let concatenate_maps = { a: HashMap<String, () -> Unit>, b: HashMap<String, () -> Unit> =>
            for ((k, v) in b) {
                a.put(k, v);
            }
            return a;
        }

        concatenate_maps(allTests, correctnessTests);
        concatenate_maps(allTests, performanceTests);
        concatenate_maps(allTests, serialTests);
        concatenate_maps(allTests, parallelTests);
    }

    public func run(name: String): Unit {
        if (let Some(f) <- allTests.get(name)) {
            map.clear();
            var start = MonoTime.now()
            try {
                f()
                println("[PASSED] ${name} - \t\t\t${Float64((MonoTime.now() - start).toMilliseconds()) / 1e3}s")
            } catch (e : DeadlockException) {
                println("[FAILED] ${name}, ${e}")
            } finally {
                map.clear();                
            }            
        } else {
            println("[TEST NOT FOUND] ${name}")
        }
    }

    public func runAllTests(runOnlyList!: ArrayList<String> = ArrayList<String>(), ignoreList! : ArrayList<String> = ArrayList<String>()): Unit {
        if(runOnlyList.size > 0) {
            for(s in runOnlyList) {
                run(s);
            }
            return;
        }
        for ((s,t) in allTests) {
            if(ignoreList.contains(s)) {
                continue;
            }
            run(s);
        }
    }

    private func getOperationTimes(n!: Int64 = 10) {

        let put_operations = readFileToArrayList("samples/put_operations.txt");
        if(put_operations.size == 0) {
            return;
        }

        let get_operations = readFileToArrayList("samples/get_operations.txt");
        if(get_operations.size == 0) {
            return;
        }

        var time : Int64 = 0;
        map.clear();

        for (idx in 0..n) {
            for (op_idx in 0..put_operations.size) {
                var op = put_operations[op_idx];
                let words = op.split(" ")
                let key = words[1]
                let value = Int64.parse(words[2])
                var start_put = MonoTime.now()
                map.put(key, value);
                var end_put = MonoTime.now();
                time += (end_put - start_put).toNanoseconds();
            }
            if(idx < n-1){
                map.clear();
            }        
        }
        println("\tPut Operation average time: \t${(Float64(time / (put_operations.size * n)))} ns")

        time = 0;

        for (_ in 0..n) {
            for (op_idx in 0..get_operations.size) {
                var op = get_operations[op_idx];
                let words = op.split(" ")
                let key = words[1]
                var start_get = MonoTime.now()
                map.get(key);
                var end_get = MonoTime.now();
                time += (end_get - start_get).toNanoseconds();
            }
        }
        println("\tGet Operation average time: \t${(Float64(time / (get_operations.size * n)))} ns")


        let init_actions = readFileToArrayList("samples/init_actions.txt");
        if(init_actions.size == 0) {
            return;
        }
        let next_actions = readFileToArrayList("samples/actions.txt");
        if(next_actions.size == 0) {
            return;
        }

        map.clear();

        var start_op = MonoTime.now()
        var end_op = MonoTime.now()
        time = 0;

        for (idx in 0..n) {
            for (split in init_actions) {
                let words = split.split(" ")
                if(words.size == 3) {
                    let key = words[1]
                    let value = Int64.parse(words[2])
                    start_op = MonoTime.now();
                    map.put(key, value);
                    end_op = MonoTime.now();
                    time += (end_op - start_op).toNanoseconds();
                } else {
                    let key = words[1]
                    start_op = MonoTime.now();
                    map.get(key);
                    end_op = MonoTime.now();
                    time += (end_op - start_op).toNanoseconds();
                }
            }
            for (split in next_actions) {
                let words = split.split(" ")
                if(words.size == 3) {
                    let key = words[1]
                    let value = Int64.parse(words[2])
                    start_op = MonoTime.now();
                    map.put(key, value);
                    end_op = MonoTime.now();
                    time += (end_op - start_op).toNanoseconds();
                } else {
                    let key = words[1]
                    start_op = MonoTime.now();
                    map.get(key);
                    end_op = MonoTime.now();
                    time += (end_op - start_op).toNanoseconds();
                }
            }
            map.clear();
        }

        println("\tMixed Operation average time: \t${time / ((init_actions.size + next_actions.size) * n)} ns")
        println("\tMy Hashmap total time: \t\t${(Float32(time / n)/1e6)} ms")

        map.clear();

        start_op = MonoTime.now();

        for (idx in 0..n) {
            if(idx == 0) {
                for (split in init_actions) {
                    let words = split.split(" ")
                    if(words.size == 3) {
                        let key = words[1]
                        let value = Int64.parse(words[2])
                        // start_op = MonoTime.now();
                        map.put(key, value);
                        // end_op = MonoTime.now();
                        // time += (end_op - start_op).toNanoseconds();
                    } else {
                        let key = words[1]
                        // start_op = MonoTime.now();
                        map.get(key);
                        // end_op = MonoTime.now();
                        // time += (end_op - start_op).toNanoseconds();
                    }
                }
            }
            // for (op in next_actions) {
            for (i in 0..next_actions.size) {
                let op = next_actions[i]
                let words = op.split(" ")
                if(words.size == 3) {
                    let key = words[1]
                    let value = Int64.parse(words[2])
                    map.put(key, value);
                } else {
                    let key = words[1]
                    map.get(key);
                }
            }
        }
        end_op = MonoTime.now();
        time += (end_op - start_op).toNanoseconds();


        println("\tThroughput: \t\t\t${(Float64(init_actions.size + next_actions.size * n) / Float64(time)) / 1e-6} ops/ms")
        // println("\tMy Hashmap total time: \t\t${(Float32(time / n)/1e6)} ms")

        map.clear();

    }

    private func parallelPerformanceTest(nthreads!: Int64 = 4, n! : Int64 = 10) {

        let init_actions = readFileToArrayList("samples/init_actions.txt");
        if(init_actions.size == 0) {
            return;
        }

        let next_actions = readFileToArrayList("samples/actions.txt");
        if(next_actions.size == 0) {
            return;
        }

        let mtx = ReentrantMutex()
        let count = AtomicInt64(0);

        let def_hashmap = ConcurrentHashMap<String, Int64>(8, concurrencyLevel : 4)


        for (split in init_actions) {
            let words = split.split(" ")
            if(words.size == 3) {
                let key = words[1]
                let value = Int64.parse(words[2])
                def_hashmap.put(key, value);
            } 
        }

        var start1 = MonoTime.now();
        var end1 = MonoTime.now();

        let time_at = AtomicInt64(0);
        let workdone = HashMap<Int64,Int64>()

        for(idx in 0..n){
            let def_hashmap2 = ConcurrentHashMap<String, Int64>(8, concurrencyLevel : 4)
            for (op in init_actions) {
                let words = op.split(" ")
                if(words.size == 3) {
                    let key = words[1]
                    let value = Int64.parse(words[2])
                    start1 = MonoTime.now()
                    def_hashmap2.put(key, value);
                    end1 = MonoTime.now();
                }
                time_at.fetchAdd((end1 - start1).toNanoseconds())
            }

            let list = ArrayList<Future<Unit>>();
            let thread_ids = HashSet<Int64>();

            // create 4 threads.
            for (i in 0..nthreads) {
                let fut = spawn {
                    thread_ids.put(Thread.currentThread.id);
                    workdone[Thread.currentThread.id] = 0;
                    var start = MonoTime.now();
                    var end = MonoTime.now();
                    while(true) {
                        mtx.lock()
                        var local_count = count.load();
                        if (local_count >= next_actions.size) {
                            mtx.unlock()
                            break  
                        }
                        let words = next_actions[local_count].split(" ")
                        count.fetchAdd(1);
                        workdone[Thread.currentThread.id]++;
                        mtx.unlock()
                        if(words.size == 3) {
                            let key = words[1];
                            let value = Int64.parse(words[2]);
                            start = MonoTime.now();
                            def_hashmap2.put(key, value);
                            end = MonoTime.now();
                        } else {
                            let key = words[1];
                            def_hashmap2.get(key);
                            end = MonoTime.now();
                        }
                        time_at.fetchAdd((end - start).toNanoseconds());
                    }
                }
                list.append(fut)
            }

            for (f in list) {
                f.get()
            }
        }

        println("\tDefault Hashmap Parallel time: \t${time_at.load() / ((init_actions.size + next_actions.size) * n)} ns")

        count.store(0);

        let my_mtx = ReentrantMutex();
        let finished = AtomicBool(false);

        time_at.store(0);

        for(idx in 0..n){
            map.clear();
            for (op in init_actions) {
                let words = op.split(" ")
                if(words.size == 3) {
                    let key = words[1]
                    let value = Int64.parse(words[2])
                    start1 = MonoTime.now()
                    map.put(key, value);
                    end1 = MonoTime.now();
                }
                time_at.fetchAdd((end1 - start1).toNanoseconds())
            }

            let my_list = ArrayList<Future<Unit>>();
            let thread_ids2 = HashSet<Int64>();



            let watchdog_thread = spawn {
                // sleep 500ms
                sleep(500 * Duration.millisecond);
                let previous_workdone = HashMap<Int64, Int64>();
                try {
                    for(t in thread_ids2) {
                        previous_workdone[t] = 0;
                    }
                } catch (e : NoneValueException) {
                }

                while(true) {
                    sleep(30 * Duration.millisecond);
                    if(finished.load()) {
                        break;
                    }
                    for(t in thread_ids2) {
                        if(previous_workdone[t] == workdone[t]) {
                            throw DeadlockException("Deadlock detected in thread id ${t} in iteration ${idx}, Workdone did not progress beyond ${workdone[t]}!")
                            return
                        } else {
                            previous_workdone[t] = workdone[t];
                        }
                    }
                }
            }

            my_list.append(watchdog_thread);

            for (i in 0..nthreads) {
                let fut = spawn {
                    thread_ids2.put(Thread.currentThread.id);
                    workdone[Thread.currentThread.id] = 0;
                    var start = MonoTime.now();
                    var end = MonoTime.now();
                    while(true) {
                        my_mtx.lock()
                        let local_count = count.load();
                        if (local_count >= next_actions.size) {
                            finished.store(true);
                            my_mtx.unlock()
                            break; 
                        }
                        let words = next_actions[local_count].split(" ")
                        count.fetchAdd(1);
                        workdone[Thread.currentThread.id]++;
                        my_mtx.unlock()
                        if(words.size == 3) {
                            let key = words[1];
                            let value = Int64.parse(words[2]);
                            start = MonoTime.now();
                            map.put(key, value);
                            end = MonoTime.now();
                        } else {
                            let key = words[1];
                            map.get(key);
                            end = MonoTime.now();
                        }
                        time_at.fetchAdd((end - start).toNanoseconds());
                    }
                }
                my_list.append(fut)
            }

            for (f in my_list) {
                f.get()
            }
        }

        println("\tMy Hashmap Parallel time: \t${time_at.load() / ((init_actions.size + next_actions.size) * n)} ns")

        map.clear();
    }

    public func generate_linearizability_history(nthreads !: Int64 = 4, ops_per_thread !: Int64 = 100, num_of_keys !: Int64 = 8) {
        // let map = HashMap<String, Int64>()

        let list = ArrayList<Future<Unit>>()
        var keys = ArrayList<String>();
        let output_lock = ReentrantMutex();

        for(i in 0..num_of_keys) {
            keys.append(Random().nextInt8().toString());
        }
        let new_keys = keys;

        // create 4 threads.
        for (i in 0..nthreads) {
            let fut = spawn {
                var op_counter = 0;
                let ops = ArrayList<String>(["get", "set"]);
                for(_ in 0..ops_per_thread) {
                    var op = ops[abs(Int64(Random().nextInt8())) % 2];
                    var k = new_keys[abs(Int64(Random().nextInt8())) % num_of_keys];
                    if(op == "set") {
                        var v = Random().nextInt8();
                        var start = DateTime.now().nanosecond;;
                        map.put(k, Int64(v));
                        var end = DateTime.now().nanosecond;;
                        synchronized(output_lock) {
                            println("id=${op_counter}, thr=${Thread.currentThread.id}, ${op}(${k},${v}) -> {ok}, [${start},${end}])");
                            op_counter++;
                        }
                        // // sleep(400 * Duration.nanosecond)
                        // sleep((Int64(abs(Random().nextInt8())) % 100) * Duration.nanosecond)
                    } else {
                        var start = DateTime.now().nanosecond;;
                        var v = map.get(k);
                        var end = DateTime.now().nanosecond;;
                        synchronized(output_lock) {
                            println("id=${op_counter}, thr=${Thread.currentThread.id}, ${op}(${k},None) -> ${v}, [${start},${end}])");
                            op_counter++;
                        }
                        // // sleep(150 * Duration.nanosecond)
                        // sleep((Int64(abs(Random().nextInt8())) % 100) * Duration.nanosecond)
                    }
                    // sleep((Int64(abs(Random().nextInt8())) % 100) * Duration.nanosecond)
                }
            }
            list.append(fut)
        }

        // println("${Op(0, 0, "", "", 0, 0, 0, 0).toString()}")

        // Wait for all threads finished.
        for (f in list) {
            f.get()
        }

        map.clear();
    }

    private func parallelStressTest(num_ops!: Int64 = 1000000, num_keys!: Int64 = 100000, n!: Int64 = 100, nthreads!: Int64 = 4) {

        let ops = SampleGenerator(2, weights : ArrayList<Float64>([1.0, 9.0])).sampleN(num_ops)
        let keys = generateUniqueStrings(num_keys, 8)
        let values = ArrayList<Int64>(num_ops, {x : Int64 => Random().nextInt64(100)})

        let sampler = SampleGenerator(num_keys, dist_fn : favor_early_exp_distribution)
        let key_samples = sampler.sampleN(num_ops)

        let my_mtx = ReentrantMutex()

        for (idx in 0..n) {
            let my_list = ArrayList<Future<Unit>>()
            let count_atomic = AtomicInt64(0);
            let current_threads = ArrayList<Int64>(nthreads, {x : Int64 => 0})
            let workdone = HashMap<Int64, Int64>();

            let watchdog_thread = spawn {
                let previous_workdone = HashMap<Int64, Int64>();
                while((checkIfAnyZero(current_threads) || workdone.size != nthreads)) {
                    sleep(200 * Duration.millisecond);
                }
                for(t in current_threads) {
                    previous_workdone.put(t, 0);
                }

                while(count_atomic.load() < num_ops) {
                    sleep(1000 * Duration.millisecond);
                    for(t in current_threads) {
                        if(previous_workdone.get(t) == workdone.get(t)) {
                            sleep(500 * Duration.millisecond);
                            if(previous_workdone.get(t) == workdone.get(t)) {
                                throw DeadlockException("Deadlock detected in thread id ${t}, Workdone did not progress beyond ${workdone[t]}!")
                                return
                            }                            
                        } else {
                            previous_workdone[t] = workdone[t];
                        }
                    }
                }
            }

            my_list.append(watchdog_thread);

            for (i in 0..nthreads) {
                let fut = spawn {
                    my_mtx.lock()
                    workdone.put(Thread.currentThread.id,0);
                    current_threads[i] = Thread.currentThread.id;
                    my_mtx.unlock()
                    while(true) {
                        my_mtx.lock()
                        let idx = count_atomic.load();
                        if (idx >= num_ops) {
                            my_mtx.unlock()
                            break  
                        }
                        let op = ops[idx]
                        count_atomic.fetchAdd(1);
                        workdone[Thread.currentThread.id]++;
                        my_mtx.unlock()
                        if(op == 0) {
                            let key = keys[key_samples[idx]]
                            map.get(key);
                        } else {
                            let key = keys[key_samples[idx]]
                            let val = values[idx]
                            map.put(key, val);
                        }
                    }
                }
                my_list.append(fut)
            }

            for (f in my_list) {
                f.get();
            }
            map.clear();
        }
    }

}
