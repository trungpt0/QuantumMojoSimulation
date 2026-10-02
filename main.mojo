from circuit import QuantumCircuit
from dagcircuit import DAGCircuit
from transpiler import CouplingMap, TParOptimization, VF2Layout, TrivialLayout, SabreLayout, SabreDAG
from gates import GateOp

def main() raises:
    # var qc = QuantumCircuit(3)
    # qc.H(0)
    # qc.CX(0,1)
    # qc.X(1)
    # qc.Y(2)
    # qc.CX(1,2)
    # qc.H(3)
    # qc.CX(0,2)
    # var dag = DAGCircuit.from_circuit(qc)
    # dag.print_dag()

    # var cm = CouplingMap(3)
    # cm.add_edge(0,1)
    # cm.add_edge(1,2)

    # var lay = SabreLayout(trials = 10)
    # var dagl = lay.run(dag^, cm)
    # print("layout =", dagl.layout)

    var qc = QuantumCircuit(6)
    qc.CX(0,5)
    qc.CX(2,3)
    qc.CX(0,1)
    qc.CX(2,4)
    qc.CX(1,4)
    var dag = DAGCircuit.from_circuit(qc)
    dag.print_dag()

    var cm = CouplingMap(6)
    cm.add_edge(0,1)
    cm.add_edge(0,3)
    cm.add_edge(1,2)
    cm.add_edge(1,4)
    cm.add_edge(2,5)
    cm.add_edge(3,4)
    cm.add_edge(4,5)
    
    var lay = SabreLayout(trials = 30)
    var dagl = lay.run(dag^, cm)
    print("layout =", dagl.layout)