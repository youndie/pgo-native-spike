// A self-contained subject for recipe/pgo.sh: small enough to train in a second, and shaped so
// that a profile has something to say. Eight implementors keep the compiler's closed-world
// devirtualisation from resolving the call, and a 90/10 receiver mix gives the profile a
// dominant target to promote. The real benchmark this study measured is probes/dispatch-bench.kt.
interface Shape { fun area(x: Long): Long }
class S1 : Shape { override fun area(x: Long) = x + 1 }
class S2 : Shape { override fun area(x: Long) = x + 2 }
class S3 : Shape { override fun area(x: Long) = x + 3 }
class S4 : Shape { override fun area(x: Long) = x + 4 }
class S5 : Shape { override fun area(x: Long) = x + 5 }
class S6 : Shape { override fun area(x: Long) = x + 6 }
class S7 : Shape { override fun area(x: Long) = x + 7 }
class S8 : Shape { override fun area(x: Long) = x + 8 }

fun main() {
    val shapes: Array<Shape> = arrayOf(S1(), S2(), S3(), S4(), S5(), S6(), S7(), S8())
    // 90 % S1, the rest spread - precomputed so the timed loop does no index arithmetic.
    val idx = IntArray(1000) { if (it % 10 == 0) 1 + (it / 10) % 7 else 0 }
    var acc = 0L
    for (round in 0 until 20_000) {
        for (i in idx.indices) acc = shapes[idx[i]].area(acc)
    }
    println(acc)
}
