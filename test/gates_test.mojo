from circuit import QuantumCircuit
from qmath import PI

def main() raises:
    var qc = QuantumCircuit(2)
    qc.X_test()
    qc.Y_test()
    qc.Z_test()
    qc.H_test()
    qc.S_test()
    qc.T_test()
    qc.RX_test(PI)
    qc.RY_test(PI)
    qc.RZ_test(PI)
    qc.P_test(PI)
    qc.IP_test(PI)
    qc.CX_test()