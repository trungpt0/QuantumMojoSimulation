from gates import GateOp

def i(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("I", q, List[Float64]())

def x(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("X", q, List[Float64]())

def y(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("Y", q, List[Float64]())

def z(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("Z", q, List[Float64]())

def h(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("H", q, List[Float64]())

def s(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("S", q, List[Float64]())

def sdg(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("SDG", q, List[Float64]())

def t(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("T", q, List[Float64]())

def tdg(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("TDG", q, List[Float64]())

def rx(q0: Int, params: Float64) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    var p = List[Float64]()
    p.append(params)
    return GateOp("RX", q, p)

def ry(q0: Int, params: Float64) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    var p = List[Float64]()
    p.append(params)
    return GateOp("RY", q, p)

def rz(q0: Int, params: Float64) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    var p = List[Float64]()
    p.append(params)
    return GateOp("RZ", q, p)

def p(q0: Int, params: Float64) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    var p = List[Float64]()
    p.append(params)
    return GateOp("P", q, p)

def ip(q0: Int, params: Float64) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    var p = List[Float64]()
    p.append(params)
    return GateOp("IP", q, p)

def sx(q0: Int) -> GateOp:
    var q = List[Int]
    q.append(q0)
    return GateOp("SX", q, List[Float64]())

def v(q0: Int) -> GateOp:
    var q = List[Int]
    q.append(q0)
    return GateOp("V", q, List[Float64]())

def cx(c: Int, t: Int) -> GateOp:
    var q = List[Int]()
    q.append(c)
    q.append(t)
    return GateOp("CX", q, List[Float64]())

def cy(c: Int, t: Int) -> GateOp:
    var q = List[Int]()
    q.append(c)
    q.append(t)
    return GateOp("CY", q, List[Float64]())

def cz(c: Int, t: Int) -> GateOp:
    var q = List[Int]()
    q.append(c)
    q.append(t)
    return GateOp("CZ", q, List[Float64]())

def swap(q0: Int, q1: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    q.append(q1)
    return GateOp("SWAP", q, List[Float64]())

def ecr(q0: Int, q1: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    q.append(q1)
    return GateOp("ECR", q, List[Float64]())

def ccx(c0: Int, c1: Int, t: Int) -> GateOp:
    var q = List[Int]()
    q.append(c0)
    q.append(c1)
    q.append(t)
    return GateOp("CCX", q, List[Float64]())