from dagcircuit import DAGCircuit
from transpiler import CouplingMap

struct TrivialLayout:
    
    def __init__(out self):
        pass

    def run(self, dag: DAGCircuit, cm: CouplingMap) -> DAGCircuit:
        if dag.qubits > cm.nq:
            print("TrivialLayout: circuit has more qubits than hardware")
        return dag.copy()
