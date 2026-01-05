package my_map

import std.fs.*
import std.collection.ArrayList
import std.io.SeekPosition

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