from std.time import monotonic

comptime PI = 3.141592653589793

def random_int(a: Int, b: Int) -> Int:
    if b <= a:
        return a
    var seed = Int(monotonic())
    seed ^= seed << 13
    seed ^= seed >> 7
    seed ^= seed << 17
    return a + (seed % (b - a))

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