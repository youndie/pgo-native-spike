// RQ2's subject: virtual and interface dispatch with a controlled receiver distribution.
//
// THE SITE MUST BE ONE THE COMPILER CANNOT RESOLVE ITSELF. Kotlin/Native devirtualises on a
// closed world, so a site with one reachable implementor is already a direct call and measures
// nothing about PGO. Eight implementors are instantiated and stored, which defeats that analysis
// while leaving the run-time distribution free to be whatever the arm says.
//
// THE THREE ARMS ARE THE BRIEF'S, and two of them have declared outcomes:
//   single  - one receiver at run time. The case promotion is for.
//   uniform - eight receivers in rotation. Each is 12.5 %, under the measured
//             icp-remaining-percent-threshold of 30, so NOTHING should be promoted.
//   skewed  - 90/10. The dominant target clears both 30 % and the 5 % total threshold, so it
//             should gain most of what `single` gains.
//
// A UNIT CONTROL SITS BESIDE EACH ARM: `sum` does the same arithmetic with no dispatch at all,
// so the dispatch cost is a difference rather than a level.

interface Shape { fun area(x: Long): Long }
class S0 : Shape { override fun area(x: Long) = x + 11 }
class S1 : Shape { override fun area(x: Long) = x + 1 }
class S2 : Shape { override fun area(x: Long) = x + 2 }
class S3 : Shape { override fun area(x: Long) = x + 3 }
class S4 : Shape { override fun area(x: Long) = x + 4 }
class S5 : Shape { override fun area(x: Long) = x + 5 }
class S6 : Shape { override fun area(x: Long) = x + 6 }
class S7 : Shape { override fun area(x: Long) = x + 7 }

open class Base { open fun f(x: Long): Long = x + 13 }
class B1 : Base() { override fun f(x: Long) = x + 1 }
class B2 : Base() { override fun f(x: Long) = x + 2 }
class B3 : Base() { override fun f(x: Long) = x + 3 }
class B4 : Base() { override fun f(x: Long) = x + 4 }
class B5 : Base() { override fun f(x: Long) = x + 5 }
class B6 : Base() { override fun f(x: Long) = x + 6 }
class B7 : Base() { override fun f(x: Long) = x + 7 }

val shapes: Array<Shape> = arrayOf(S0(), S1(), S2(), S3(), S4(), S5(), S6(), S7())
val bases: Array<Base> = arrayOf(Base(), B1(), B2(), B3(), B4(), B5(), B6(), B7())

// THE SINK IS PRINTED AND IT IS NOT DECORATION. The first version had `S0.area(x) = x + 0`,
// so the `single` arm accumulated zero for ever and the loop was dead. It timed fastest of all,
// which is exactly what a deleted loop looks like.
//
// THE INDEX SEQUENCE IS PRECOMPUTED, and that is the second thing this file got wrong. The first
// version chose the receiver inside the timed loop - `i and 7` for uniform, `i % 10` and `i / 10`
// for skewed - so the arms differed by a division as well as by a receiver distribution, and
// `skewed` timed SLOWER than `uniform`, the opposite of what promotion predicts. It was measuring
// the picker. Now every arm walks the same `IntArray` with the same load, and the only difference
// between them is which receivers that array names.
fun sequence(mode: String, n: Int): IntArray {
    val a = IntArray(n)
    for (i in 0 until n) a[i] = when (mode) {
        "single" -> 1
        "uniform" -> i and 7
        "skewed" -> if (i % 10 == 0) 1 + (i / 10) % 7 else 1   // 90 % index 1
        else -> 1
    }
    return a
}

fun itable(idx: IntArray): Long {
    var acc = 0L
    for (i in idx.indices) acc += shapes[idx[i]].area(acc)
    return acc
}

fun vtable(idx: IntArray): Long {
    var acc = 0L
    for (i in idx.indices) acc += bases[idx[i]].f(acc)
    return acc
}

// THE UNIT CONTROL: the same loop and the same array walk, no dispatch.
fun sum(idx: IntArray): Long {
    var acc = 0L
    for (i in idx.indices) acc += acc + idx[i]
    return acc
}

// THE KNOWN-ORDER PAIR: `both` does everything `itable` does plus a vtable call, so it must be
// slower. If it is not, the stand is wrong and no number from this run is used.
fun both(idx: IntArray): Long {
    var acc = 0L
    for (i in idx.indices) { acc += shapes[idx[i]].area(acc); acc += bases[idx[i]].f(acc) }
    return acc
}

fun time(label: String, n: Int, body: () -> Long) {
    // `kotlin.system.getTimeNanos` is deprecated to an error at 2.4.20; the monotonic time source
    // is the replacement the compiler names.
    body()                                     // warm the code paths
    var best = Double.MAX_VALUE
    var sink = 0L
    repeat(5) {
        val mark = kotlin.time.TimeSource.Monotonic.markNow()
        sink = body()
        val ns = mark.elapsedNow().inWholeNanoseconds.toDouble() / n
        if (ns < best) best = ns
    }
    println("$label $best ns/op sink=$sink")
}

fun main(args: Array<String>) {
    val n = if (args.isNotEmpty()) args[0].toInt() else 20_000_000
    for (mode in listOf("single", "uniform", "skewed")) {
        val idx = sequence(mode, n)
        time("itable-$mode", n) { itable(idx) }
        time("vtable-$mode", n) { vtable(idx) }
        time("both-$mode", n) { both(idx) }
        time("sum-$mode", n) { sum(idx) }
    }
}
