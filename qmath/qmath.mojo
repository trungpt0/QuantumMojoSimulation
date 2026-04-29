from std.time import monotonic

comptime PI = 3.141592653589793

def abs(x: Int) -> Int:
    return x if x >= 0 else -x

def abs(x: Float64) -> Float64:
    return x if x >= 0.0 else -x

def round(x: Float64, decimals: Int = 0) -> Float64:
    var factor = 1.0
    for _ in range(decimals):
        factor *= 10.0
    var shifted = x * factor
    var floored = Float64(Int(shifted + 0.5 if shifted >= 0.0 else shifted - 0.5))
    return floored / factor

def random_int(a: Int, b: Int) -> Int:
    if b <= a:
        return a
    var seed = Int(monotonic())
    seed ^= seed << 13
    seed ^= seed >> 7
    seed ^= seed << 17
    return a + (seed % (b - a))

def random_float64(mut seed: Int, lo: Float64, hi: Float64) -> Float64:
    if hi <= lo:
        return lo
    seed ^= seed << 13
    seed ^= seed >> 7
    seed ^= seed << 17
    var uint = Float64(seed & 0x7FFFFFFFFFFFFFFF) / Float64(0x8000000000000000)
    return lo + uint * (hi - lo)

# @always_inline
# def _splitmix64(inout s: UInt64) -> UInt64:
#     var s = 0
#     s += 0x9E3779B97F4A7C15
#     s = (s ^ (s >> 30)) * 0xBF58476D1CE4E5B9
#     s = (s ^ (s >> 27)) * 0x94D049BB133111EB
#     return s ^ (s >> 31)

# struct RNG:
#     var s0: UInt64
#     var s1: UInt64
#     var s2: UInt64
#     var s3: UInt64

#     def __init__(inout self, seed: Int):
#         var s = UInt64(seed)
#         self.s0 = _splitmix64(s)
#         self.s1 = _splitmix64(s)
#         self.s2 = _splitmix64(s)
#         self.s3 = _splitmix64(s)

#     def __init__(inout self):
#         self.__init__(Int(monotonic()))

#     @always_inline
#     def _rotl(self, x: UInt64, k: Int) -> UInt64:
#         return (x << k) | (x >> (64 - k))

#     @always_inline
#     def next(inout self) -> UInt64:
#         var result = self._rotl(self.s0 + self.s3, 23) + self.s0
#         var t = self.s1 << 17
#         self.s2 ^= self.s0
#         self.s3 ^= self.s1
#         self.s1 ^= self.s2
#         self.s0 ^= self.s3
#         self.s2 ^= t
#         self.s3 = self._rotl(self.s3, 45)
#         return result

#     @always_inline
#     def random_int(inout self, a: Int, b: Int) -> Int:
#         if b <= a:
#             return a
#         var r = Int(self.next() >> 1)
#         return a + (r % (b - a))

#     @always_inline
#     def random_float64(inout self, lo: Float64, hi: Float64) -> Float64:
#         if hi <= lo:
#             return lo
#         var bits = (self.next() >> 11) | 0x3FF0000000000000
#         var uint = bitcast[Float64](bits) - 1.0
#         return lo + uint * (hi - lo)

#     @always_inline
#     def random_bool(inout self) -> Bool:
#         return self.random_float64() < 0.5

def log2_int(x: Int) -> Int:
    var n = 0
    var v = x
    while v > 1:
        v = v >> 1
        n += 1
    return n

def inv() -> Float64:
    return 0.7071067811865475

struct Complex(Copyable):
    var re: Float64
    var im: Float64

    def __init__(out self, re: Float64, im: Float64):
        self.re = re
        self.im = im
    
    def add(self, other: Complex) -> Complex:
        return Complex(self.re + other.re, self.im + other.im)

    def dif(self, other: Complex) -> Complex:
        return Complex(self.re - other.re, self.im - other.im)

    def mul_fnumber(self, num: Float64) -> Complex:
        return Complex(num * self.re, num * self.im)

    def mul(self, other: Complex) -> Complex:
        return Complex(
            self.re * other.re - self.im * other.im,
            self.re * other.im + self.im * other.re
        )

def abs2(c: Complex) -> Float64:
    return c.re * c.re + c.im * c.im