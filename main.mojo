from circuit import QuantumCircuit
from dagcircuit import DAGCircuit
from transpiler.passes.optimization import RemoveIdentityEquivalent
from qmath import PI

def main() raises:
    var qc = QuantumCircuit(2)
    qc.H(0)
    qc.CX(0, 1)
    qc.RZ(0, 0)
    qc.RZ(0, 2*PI)
    qc.I(1)
    qc.I(0)
    qc.measure(0)
    qc.print_psi()
    var dag = DAGCircuit.from_circuit(qc)
    dag.print_dag()
    var passte = RemoveIdentityEquivalent()
    var dag_opt = passte.run(dag^)
    dag_opt.print_dag()
    var qc2 = dag_opt.to_circuit()
    qc2.print_psi()