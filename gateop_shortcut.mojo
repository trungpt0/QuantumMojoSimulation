from gates import GateOp

def I(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("I", q, List[Float64]())

def X(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("X", q, List[Float64]())

def Y(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("Y", q, List[Float64]())

def Z(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("Z", q, List[Float64]())

def H(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("H", q, List[Float64]())

def S(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("S", q, List[Float64]())

def Sdg(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("SDG", q, List[Float64]())

def T(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("T", q, List[Float64]())

def Tdg(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("TDG", q, List[Float64]())

def RX(q0: Int, params: Float64) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    var p = List[Float64]()
    p.append(params)
    return GateOp("RX", q, p)

def RY(q0: Int, params: Float64) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    var p = List[Float64]()
    p.append(params)
    return GateOp("RY", q, p)

def RZ(q0: Int, params: Float64) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    var p = List[Float64]()
    p.append(params)
    return GateOp("RZ", q, p)

def P(q0: Int, params: Float64) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    var p = List[Float64]()
    p.append(params)
    return GateOp("P", q, p)

def IP(q0: Int, params: Float64) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    var p = List[Float64]()
    p.append(params)
    return GateOp("IP", q, p)

def SX(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("SX", q, List[Float64]())

def V(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("V", q, List[Float64]())

def CX(c: Int, t: Int) -> GateOp:
    var q = List[Int]()
    q.append(c)
    q.append(t)
    return GateOp("CX", q, List[Float64]())

def CY(c: Int, t: Int) -> GateOp:
    var q = List[Int]()
    q.append(c)
    q.append(t)
    return GateOp("CY", q, List[Float64]())

def CZ(c: Int, t: Int) -> GateOp:
    var q = List[Int]()
    q.append(c)
    q.append(t)
    return GateOp("CZ", q, List[Float64]())

def SWAP(q0: Int, q1: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    q.append(q1)
    return GateOp("SWAP", q, List[Float64]())

def ECR(q0: Int, q1: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    q.append(q1)
    return GateOp("ECR", q, List[Float64]())

def CCX(c0: Int, c1: Int, t: Int) -> GateOp:
    var q = List[Int]()
    q.append(c0)
    q.append(c1)
    q.append(t)
    return GateOp("CCX", q, List[Float64]())