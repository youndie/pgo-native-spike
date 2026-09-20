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
class S0 : Shape { override fun area(x: Long) = x + 0 }
class S1 : Shape { override fun area(x: Long) = x + 1 }
class S2 : Shape { override fun area(x: Long) = x + 2 }
class S3 : Shape { override fun area(x: Long) = x + 3 }
class S4 : Shape { override fun area(x: Long) = x + 4 }
class S5 : Shape { override fun area(x: Long) = x + 5 }
class S6 : Shape { override fun area(x: Long) = x + 6 }
class S7 : Shape { override fun area(x: Long) = x + 7 }

open class Base { open fun f(x: Long): Long = x + 0 }
class B1 : Base() { override fun f(x: Long) = x + 1 }
class B2 : Base() { override fun f(x: Long) = x + 2 }
class B3 : Base() { override fun f(x: Long) = x + 3 }
class B4 : Base() { override fun f(x: Long) = x + 4 }
class B5 : Base() { override fun f(x: Long) = x + 5 }
class B6 : Base() { override fun f(x: Long) = x + 6 }
class B7 : Base() { override fun f(x: Long) = x + 7 }

val shapes: Array<Shape> = arrayOf(S0(), S1(), S2(), S3(), S4(), S5(), S6(), S7())
val bases: Array<Base> = arrayOf(Base(), B1(), B2(), B3(), B4(), B5(), B6(), B7())

fun pick(i: Int, mode: String, n: Int): Int = when (mode) {
    "single" -> 0
    "uniform" -> i and 7
    "skewed" -> if (i % 10 == 0) 1 + (i / 10) % 7 else 0   // 90 % index 0
    else -> 0
}

fun itable(mode: String, n: Int): Long {
    var acc = 0L
    for (i in 0 until n) acc += shapes[pick(i, mode, n)].area(acc)
    return acc
}

fun vtable(mode: String, n: Int): Long {
    var acc = 0L
    for (i in 0 until n) acc += bases[pick(i, mode, n)].f(acc)
    return acc
}

// THE UNIT CONTROL: the same loop, the same arithmetic, no dispatch.
fun sum(n: Int): Long {
    var acc = 0L
    for (i in 0 until n) acc += acc + (i and 7)
    return acc
}

// THE KNOWN-ORDER PAIR: `both` does everything `itable` does plus a vtable call, so it must be
// slower. If it is not, the stand is wrong and no number from this run is used.
fun both(mode: String, n: Int): Long {
    var acc = 0L
    for (i in 0 until n) { acc += shapes[pick(i, mode, n)].area(acc); acc += bases[pick(i, mode, n)].f(acc) }
    return acc
}

fun time(label: String, n: Int, body: () -> Long) {
    body()                                     // warm the code paths
    val t0 = kotlin.system.getTimeNanos()
    val r = body()
    val t1 = kotlin.system.getTimeNanos()
    println("$label ${(t1 - t0).toDouble() / n} ns/op sink=$r")
}

fun main(args: Array<String>) {
    val n = if (args.isNotEmpty()) args[0].toInt() else 20_000_000
    for (mode in listOf("single", "uniform", "skewed")) {
        time("itable-$mode", n) { itable(mode, n) }
        time("vtable-$mode", n) { vtable(mode, n) }
        time("both-$mode", n) { both(mode, n) }
    }
    time("sum-control", n) { sum(n) }
}
