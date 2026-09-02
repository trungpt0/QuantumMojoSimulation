from circuit import QuantumCircuit
from dagcircuit import DAGCircuit
from transpiler import CouplingMap, TParOptimization, VF2Layout, TrivialLayout, SabreLayout, SabreDAG
from gates import GateOp

def main() raises:
    var qc = QuantumCircuit(3)
    qc.CX(0,1)
    qc.CX(1,2)
    var dag = DAGCircuit.from_circuit(qc)
    dag.print_dag()

    var cm = CouplingMap(4)
    cm.add_edge(1,0)
    cm.add_edge(0,2)
    cm.add_edge(2,3)
    
    var lay = SabreLayout(trials = 1)
    var dagl = lay.run(dag^, cm)
    print("layout =", dagl.layout)