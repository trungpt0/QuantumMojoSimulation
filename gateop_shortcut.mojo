from gates import GateOp

def _I(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("I", q, List[Float64]())

def _X(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("X", q, List[Float64]())

def _Y(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("Y", q, List[Float64]())

def _Z(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("Z", q, List[Float64]())

def _H(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("H", q, List[Float64]())

def _S(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("S", q, List[Float64]())

def _Sdg(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("SDG", q, List[Float64]())

def _T(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("T", q, List[Float64]())

def _Tdg(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("TDG", q, List[Float64]())

def _RX(q0: Int, params: Float64) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    var p = List[Float64]()
    p.append(params)
    return GateOp("RX", q, p)

def _RY(q0: Int, params: Float64) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    var p = List[Float64]()
    p.append(params)
    return GateOp("RY", q, p)

def _RZ(q0: Int, params: Float64) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    var p = List[Float64]()
    p.append(params)
    return GateOp("RZ", q, p)

def _P(q0: Int, params: Float64) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    var p = List[Float64]()
    p.append(params)
    return GateOp("P", q, p)

def _IP(q0: Int, params: Float64) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    var p = List[Float64]()
    p.append(params)
    return GateOp("IP", q, p)

def _SX(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("SX", q, List[Float64]())

def _V(q0: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    return GateOp("V", q, List[Float64]())

def _CX(c: Int, t: Int) -> GateOp:
    var q = List[Int]()
    q.append(c)
    q.append(t)
    return GateOp("CX", q, List[Float64]())

def _CY(c: Int, t: Int) -> GateOp:
    var q = List[Int]()
    q.append(c)
    q.append(t)
    return GateOp("CY", q, List[Float64]())

def _CZ(c: Int, t: Int) -> GateOp:
    var q = List[Int]()
    q.append(c)
    q.append(t)
    return GateOp("CZ", q, List[Float64]())

def _SWAP(q0: Int, q1: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    q.append(q1)
    return GateOp("SWAP", q, List[Float64]())

def _ECR(q0: Int, q1: Int) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    q.append(q1)
    return GateOp("ECR", q, List[Float64]())

def _RBS(q0: Int, q1: Int, params: Float64) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    q.append(q1)
    var p = List[Float64]()
    p.append(params)
    return GateOp("RBS", q, p)

def _CP(q0: Int, q1: Int, params: Float64) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    q.append(q1)
    var p = List[Float64]()
    p.append(params)
    return GateOp("CP", q, p)

def _CRX(q0: Int, q1: Int, params: Float64) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    q.append(q1)
    var p = List[Float64]()
    p.append(params)
    return GateOp("CRX", q, p)

def _CRY(q0: Int, q1: Int, params: Float64) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    q.append(q1)
    var p = List[Float64]()
    p.append(params)
    return GateOp("CRY", q, p)

def _CRZ(q0: Int, q1: Int, params: Float64) -> GateOp:
    var q = List[Int]()
    q.append(q0)
    q.append(q1)
    var p = List[Float64]()
    p.append(params)
    return GateOp("CRZ", q, p)

def _CCX(c0: Int, c1: Int, t: Int) -> GateOp:
    var q = List[Int]()
    q.append(c0)
    q.append(c1)
    q.append(t)
    return GateOp("CCX", q, List[Float64]())