from circuit import QuantumCircuit
from dagcircuit import DAGCircuit
from transpiler import CouplingMap, TParOptimization, VF2Layout, TrivialLayout
from gates import GateOp

def main() raises:
    var qc = QuantumCircuit(5)
    qc.CX(0,1)
    qc.CX(1,2)
    qc.CX(2,3)
    qc.CX(3,4)
    var dag = DAGCircuit.from_circuit(qc)
    dag.print_dag()

    var cm = CouplingMap.ibm_q20_tokyo()
    
    var lay = TrivialLayout()
    var dagl = lay.run(dag^, cm)
    print("layout =", dagl.layout)
