echo "exe_timing_mojo.mojo is running..."
mojo -I . results/optimization_transpiler/exe_timing_mojo.mojo
echo "exe_timing_mojo.mojo done"
echo "exe_timing_qiskit.py is running..."
/usr/bin/python3 results/optimization_transpiler/exe_timing_qiskit.py
echo "exe_timing_qiskit.py done"
echo "Plot"
/usr/bin/python3 results/optimization_transpiler/exe_timing_plot.py
echo "Done"