# Linearizability checker and stress-test harness in Python
# This code will:
# 1) implement a simple backtracking linearizability checker for a Map with `set` and `get`
# 2) provide a small stress-test harness that runs multiple threads against a thread-safe map,
#    records a history (start/end timestamps and return values), and invokes the checker.
#
# The checker uses the standard constraint: if op A ends before op B starts, A must be before B
# in any linearization. It searches for a sequential ordering (topological order) consistent with
# those constraints whose simulated sequential semantics produce the recorded returns.
#
# Run this cell to both define functions and run a small demonstration.

import threading
import time
import random
from dataclasses import dataclass, field
from typing import List, Optional, Tuple, Dict, Any
import copy

# ---------------------------
# History entry structure
# ---------------------------
@dataclass
class Op:
    id: int
    thread: int
    kind: str  # "get" or "set"
    key: Any
    value: Optional[Any]  # for set: value being written; for get: ignored
    ret: Optional[Any]    # recorded return value (for set typically "ok", for get the read value)
    start: int            # monotonic nanoseconds
    end: int              # monotonic nanoseconds

    def __repr__(self):
        return (f"Op(id={self.id}, thr={self.thread}, {self.kind}({self.key},{self.value}) -> {self.ret}, "
                f"[{self.start},{self.end}])")

# ---------------------------
# Utilities: time
# ---------------------------
def now_ns():
    return time.monotonic_ns()

# ---------------------------
# Linearizability checker
# ---------------------------
def is_linearizable(history: List[Op], initial_state: Dict = None) -> Tuple[bool, Optional[List[Op]]]:
    """
    Checks whether the provided history is linearizable w.r.t. a sequential map model.
    Returns (True, linearization_order) if linearizable; otherwise (False, None).
    """
    if initial_state is None:
        initial_state = {}

    n = len(history)
    ops = history.copy()

    # Build precedence constraints: if A.end < B.start => A must be before B
    must_before = {i: set() for i in range(n)}  # must_before[j] is set of indices that must come before j
    for i in range(n):
        for j in range(n):
            if history[i].end < history[j].start:
                must_before[j].add(i)
    # print(must_before)
    # print(-1)

    placed = [False]*n
    result_order = [None]*n
    cache = {}
    # print(0)

    # For pruning: memoize based on (placed_mask, frozenset of state items) maybe heavy; we'll memo only on placed mask
    # Represent placed mask as tuple of booleans -> string key
    def placed_key():
        return tuple(placed)

    # Backtracking
    def backtrack(state: Dict) -> Optional[List[Op]]:
        # print("inside backtrack")
        # If all placed, success
        if all(placed):
            return [result_order[i] for i in range(n)]

        # print(1)
        key = placed_key()
        if key in cache:
            return None  # we've failed from this partial placement before

        # print(2)
        # determine candidates: ops not placed whose must_before are already placed
        candidates = []
        for idx in range(n):
            if not placed[idx] and must_before[idx].issubset({i for i, p in enumerate(placed) if p}):
                candidates.append(idx)

        # print(3)
        # Try candidates in some order (heuristic: prefer earlier end time)
        candidates.sort(key=lambda i: history[i].end)

        # print(4)
        # print(candidates)
        for idx in candidates:
            # print("5 ", idx)
            op = history[idx]
            # print(op)

            # simulate op on a copy of state to check if recorded return matches sequential semantics
            new_state = state  # we'll mutate a copy only if op is applied
            # print(state)
            if op.kind == "set":
                # print("op set")
                # sequential set returns "ok" typically; we assume recorded ret should be "ok" or None
                expected_ret = "ok" if op.ret is not None else op.ret
                # Some tests may record None for set returns; allow "ok" or None equivalently
                if not (op.ret == "ok" or op.ret is None):
                    # if ret is something else, accept only if equals expected (fail)
                    pass
                # apply set
                new_state = state.copy()
                new_state[op.key] = op.value
            elif op.kind == "get":
                # print("op get")
                expected = state.get(op.key, None)
                # In recorded history, we may use a sentinel for "EMPTY" or None;
                # treat recorded None as absent; else must equal expected.
                # print("op get 1 ", op.ret, expected, type(op.ret), type(expected))
                if op.ret != expected:
                    # print("op get 2")
                    # mismatch -> can't place this op now
                    continue
                new_state = state  # no change
                # print("op get 3")
            else:
                # unsupported op kind
                continue

            # print("place op")
            # place op
            placed[idx] = True
            result_order[sum(1 for p in placed if p)-1] = op  # place in next slot
            res = backtrack(new_state)
            if res is not None:
                return res
            # backtrack
            placed[idx] = False
            result_order[sum(1 for p in placed if p)-1] = None

        # print(6)
        cache[key] = False
        return None
    
    # print(7)
    linearization = backtrack(initial_state.copy())

    # print(8)
    if linearization is not None:
        return True, linearization
    else:
        return False, None

# ---------------------------
# Small demonstrative history
# ---------------------------
def demo_small_history():
    # Create a small history with interleaving that is linearizable
    h = []
    t0 = now_ns()
    # T1 set(A,1) [0, 30]
    h.append(Op(id=0, thread=1, kind="set", key="A", value=1, ret="ok", start=t0, end=t0+30))
    # T2 get(A) overlapping [10,20] returns 1 -> legal
    h.append(Op(id=1, thread=2, kind="get", key="A", value=None, ret=1, start=t0+10, end=t0+20))
    # T3 get(A) after set finished -> must see 1
    h.append(Op(id=2, thread=3, kind="get", key="A", value=None, ret=1, start=t0+40, end=t0+50))
    return h

# ---------------------------
# Stress-test harness (generates history)
# ---------------------------
class ThreadSafeMap:
    def __init__(self):
        self.lock = threading.Lock()
        self.d = {}

    def set(self, k, v):
        with self.lock:
            # simulate small work to allow races
            tmp = self.d.get(k)
            time.sleep(0.00001 * random.random())
            self.d[k] = v
        return "ok"

    def get(self, k):
        with self.lock:
            time.sleep(0.00001 * random.random())
            return self.d.get(k, None)

def stress_test(num_threads=4, ops_per_thread=50, keys=("x","y","z")):
    m = ThreadSafeMap()
    history = []
    hist_lock = threading.Lock()
    op_counter = 0

    def worker(tid):
        nonlocal op_counter
        for _ in range(ops_per_thread):
            kind = random.choice(["get","set"])
            k = random.choice(keys)
            if kind == "set":
                v = random.randint(0,10)
                start = now_ns()
                ret = m.set(k,v)
                end = now_ns()
                with hist_lock:
                    history.append(Op(id=op_counter, thread=tid, kind="set", key=k, value=v, ret=ret, start=start, end=end))
                    op_counter += 1
            else:
                start = now_ns()
                r = m.get(k)
                end = now_ns()
                with hist_lock:
                    history.append(Op(id=op_counter, thread=tid, kind="get", key=k, value=None, ret=r, start=start, end=end))
                    op_counter += 1
            # small randomized delay to increase interleaving
            time.sleep(0.0001 * random.random())

    threads = []
    for t in range(num_threads):
        th = threading.Thread(target=worker, args=(t,))
        threads.append(th)
        th.start()
    for th in threads:
        th.join()

    # sort history by start time to be deterministic for the checker input ordering
    history.sort(key=lambda op: op.start)
    # reassign ids in sorted order
    for i, op in enumerate(history):
        op.id = i
    return history

# ---------------------------
# Run demonstration and a small stress test
# ---------------------------
if __name__ == "__main__":
    # print("Demo small history:")
    # h = demo_small_history()
    # for op in h:
    #     print(op)
    # ok, lin = is_linearizable(h)
    # print("Linearizable?", ok)
    # if ok:
    #     print("One linearization order:")
    #     for o in lin:
    #         print("   ", o)

    print("\nRunning a small stress test (Python thread-safe map) to generate a history and check linearizability...")
    history = stress_test(num_threads=4, ops_per_thread=20, keys=("x","y","z"))
    print(f"Generated {len(history)} operations.")
    # print first 10 ops for inspection

    for op in history[:10]:
        print(op)
    ok2, lin2 = is_linearizable(history)
    print("Stress test linearizable?", ok2)
    if not ok2:
        print("Non-linearizable history detected (note: our map is protected by a single lock so it should be linearizable).")
    else:
        print("Found linearization (first 10 ops in linearization):")
        for o in lin2[:10]:
            print("   ", o)

    print()

    with open('hist_my.txt', 'r') as file:
        hist = [line.strip() for line in file]
    history = []
    for h in hist:
        values = h.split(",")
        id_val = values[0].split("=")[1]
        thread_id = values[1].split("=")[1]
        kind = h.split(" ->")[0].split(", ")[2].split("(")[0]
        k = h.split(" ->")[0].split(", ")[2].split("(")[1].split(",")[0]
        v = h.split(" ->")[0].split(", ")[2].split("(")[1].split(",")[1].split(")")[0]
        if(v == "None"):
            v = None
        else:
            v = int(v)
        r = h.split("-> ")[1].split(", ")[0]
        if(r == r"{ok}"):
            r = "ok"
        elif(r == "None"):
            r = None
        elif(r[:2] == "So"):
            r = int(r[5:-1])
        start = h.split("[")[1].split(",")[0]
        end = h.split("[")[1].split("]")[0].split(",")[1]
        # print(f"{id_val} {thread_id} {kind} {k},{v} -> {r} [{start}, {end}]")
        history.append(Op(id=id_val, thread=thread_id, kind=kind, key=str(k), value=v, ret=r, start=start, end=end))
    # exit()

    for op in history[:10]:
        print(op)
    ok2, lin2 = is_linearizable(history)
    print("Stress test linearizable?", ok2)
    if not ok2:
        print("Non-linearizable history detected (note: our map is protected by a single lock so it should be linearizable).")
    else:
        print("Found linearization (first 10 ops in linearization):")
        for o in lin2[:10]:
            print("   ", o)

# The code above is self-contained and demonstrates the checker + harness.
# To adapt to a C map:
#  - Have your C implementation log start/end timestamps and return values to a file.
#  - Load that file into a list of Op entries (same format) and call is_linearizable on it.
#  - Alternatively, create a Python wrapper around your C map (ctypes) and test directly like the ThreadSafeMap above.

