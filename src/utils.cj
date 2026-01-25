package my_map

import std.fs.*
import std.collection.ArrayList
import std.io.SeekPosition
import std.random.*
import std.collection.HashSet
import std.math.*

func readFileToArrayList(filename: String): ArrayList<String> { // Option<ArrayList<String>>
    // Open file in read-only mode
    let filePath: Path = Path(filename)
    if (!File.exists(filePath)) {
        return ArrayList<String>();
    }
    let file = File(filePath, OpenOption.Open(true, false))

    // 4 KB read buffer (good balance of memory vs speed)
    let buffer = Array<Byte>(4096, item: 0)

    // Stores completed lines as Strings
    var lines = ArrayList<String>()

    // Temporary buffer for currently-building line
    var lineBuf = ArrayList<Byte>()

    while (true) {
        let bytesRead = file.read(buffer)
        if (bytesRead == 0) { 
            break  // EOF 
        }

        var i: Int64 = 0
        while (i < bytesRead) {
            let b = buffer[i]

            if (b == 10) {   // '\n' (LF)
                // Convert accumulated bytes into a string
                let line = String.fromUtf8(lineBuf.toArray())
                lines.append(line)

                // Reset line accumulator
                lineBuf.clear()
            } else {
                lineBuf.append(b)
            }

            i = i + 1
        }
    }
    file.close()

    return lines;

}



func checkIfAnyZero(arr: ArrayList<Int64>) {
    // var acc: Int64 = -1;
    for(t in arr) {
        // acc &= t;
        // acc = acc & t;
        if(t == 0) {
            return true;
        }
    }
    return false;
}

func generateUniqueStrings(count: Int, string_length: Int): ArrayList<String> {
    let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    let charCount = Int64(chars.size)

    let result = ArrayList<String>()
    let seen = HashSet<String>()

    while (seen.size < count) {
        var s = StringBuilder()

        for (i in 0..string_length) {
            let idx = Random().nextInt64(charCount)
            s.append(Rune(chars[idx]))
        }

        let str = s.toString()
        if (!seen.contains(str)) {
            seen.put(str)
            result.append(str)
        }
    }

    return result
}


func uniform_distribution(idx : Int64, N : Int64) : Float64 {
    return 1.0;
}

func favor_early_distribution(idx : Int64, N : Int64) : Float64 {
    return Float64(N - idx);
}

func favor_late_distribution(idx : Int64, N : Int64) : Float64 {
    return Float64(idx);
}

func favor_early_exp_distribution(idx : Int64, N : Int64) : Float64 {
    return pow(1.5,N-idx);
}

func favor_late_exp_distribution(idx : Int64, N : Int64) : Float64 {
    return pow(1.5,idx)
}

func zipfian_distribution(idx: Int64, N: Int64): Float64 {
    let rank = Float64(idx + 1)
    return 1.0 / rank
}

func exponential_decay_distribution(idx: Int64, N: Int64): Float64 {
    return pow(0.05, Float64(idx))
}



class SampleGenerator {
    private let prob: ArrayList<Float64>
    private let alias: ArrayList<Int64>
    private let size: Int64

    // Constructor: n = number of discrete outcomes
    public SampleGenerator(n: Int64, dist_fn!: (Int64, Int64) -> Float64 = uniform_distribution, weights!: ArrayList<Float64> = ArrayList<Float64>()) {
        var scaled = ArrayList<Float64>()
        var sum: Float64 = 0.0
        if(weights.isEmpty()) {
            // Distribution Function
            for(i in 0..n) {
                let w = dist_fn(i, n)
                scaled.append(w)
                sum += w
            }
        } else {
            if(weights.size != n){
                throw IllegalArgumentException("weights.size ${weights.size} should be equal to n ${n}")
            }
            scaled = weights
            for(i in 0..n) {
                sum += weights[i]
            }
        }

        this.size = n
        this.prob = ArrayList<Float64>(n, {x : Int64 => 0.0})
        this.alias = ArrayList<Int64>(n, {x : Int64 => 0})


        // Normalize and scale
        for (i in 0..n) {
            scaled[i] = scaled[i] * Float64(n) / sum
        }

        let small = ArrayList<Int64>()
        let large = ArrayList<Int64>()

        for (i in 0..n) {
            if (scaled[i] < 1.0) {
                small.append(i)
            }
            else {
                large.append(i)
            }
        }

        // Build alias tables
        while (!small.isEmpty() && !large.isEmpty()) {
            let s = small[small.size - 1]
            let l = large[large.size - 1]
            small.remove(small.size - 1)
            large.remove(large.size - 1)

            prob[s] = scaled[s]
            alias[s] = l

            scaled[l] = scaled[l] + scaled[s] - 1.0

            if (scaled[l] < 1.0) {
                small.append(l)
            } else {
                large.append(l)
            }
        }

        // Remaining entries get prob = 1
        while (!large.isEmpty()) {
            let l = large[large.size - 1]
            large.remove(large.size - 1)
            prob[l] = 1.0
        }

        while (!small.isEmpty()) {
            let s = small[small.size - 1]
            small.remove(small.size - 1)
            prob[s] = 1.0
        }
    }

    // Sample a single Int64 value
    public func sample(): Int64 {
        let i = Random().nextInt64(size)
        let u = Float64(Random().nextInt64(1000000)) / 1000000.0

        if (u < prob[i]) {
            return i
        } else {
            return alias[i]
        }
    }

    // Sample N Int64 values
    public func sampleN(N: Int64): ArrayList<Int64> {
        let result = ArrayList<Int64>()
        for (_ in 0..Int32(N)) {
            result.append(sample())
        }
        return result
    }
}
