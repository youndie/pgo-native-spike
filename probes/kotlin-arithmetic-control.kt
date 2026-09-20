// THE POSITIVE CONTROL FOR RQ1's ATTRIBUTION, and it is not a formality.
//
// RQ1 is a gate that can stop this study, and its whole content is "what share of self CPU is
// Kotlin". A pipeline that reports five percent Kotlin for everything - because a symbol rule is
// wrong, because the binary is stripped, because perf resolved nothing - produces exactly the
// evidence a red gate produces. This program is the case where the answer is known in advance:
// integer arithmetic in a loop, no allocation on the hot path, no I/O, no collections. If the
// pipeline does not report it as overwhelmingly `kfun:`, the pipeline is what is being measured.
fun main() {
    var acc = 0L
    var i = 0L
    while (i < 40_000_000_000L) {
        acc = acc * 31 + i
        acc = acc xor (acc ushr 17)
        i++
    }
    println(acc)
}
