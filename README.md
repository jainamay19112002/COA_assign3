**Assignment No. 3 — Dominant Eigenvalue and Eigenvector using Power Iteration (RV32IMF)**


Target ISA: RV32IMF (RISC-V 32-bit Integer + Multiply/Divide + Float)
Expected Effort: <=15  hours
1. Learning Objectives
By completing this assignment, you will learn to:
- Implement a numerical linear-algebra algorithm in RISC-V assembly.
- Use RV32F floating-point operations, nested loops, and memory addressing.
- Apply the Power Iteration algorithm to compute the dominant eigenvalue and eigenvector.
- Evaluate algorithmic performance using instruction count, loop optimization, and register allocation.
2. Problem Statement
Write a RISC-V assembly program that estimates the dominant eigenvalue (λmax) and corresponding eigenvector of a real symmetric 6×6 matrix using the Power Iteration method (A·v = λv).
Algorithm (Power Iteration)
Given A ∈ ℝ⁶ˣ⁶ and initial vector v(0):
Repeat for k = 1…Niter (max 10):
1. w = A × v(k−1)
2. λ(k) = (v(k−1))ᵀ w / (v(k−1))ᵀ v(k−1)
3. Normalize v(k) = w / ||w||
4. Stop if |λ(k) − λ(k−1)| < ε
Constraints
- Use single-precision floats (.float, flw, fsw, fadd.s, fmul.s, fdiv.s, fsqrt.s).
- Matrix A is symmetric, stored row-major.
- Initial vector v_init = [1,1,1,1,1,1].
- Convergence tolerance ε = 1e−3, max 10 iterations.
- Output to memory: lambda_result (dominant eigenvalue), v_result[6] (normalized eigenvector).
3. Program Specification
Inputs: 6×6 matrix A, initial vector v_init, ε, Niter
Outputs: Float lambda_result, array v_result[6]
Subroutines: matvec_mul, dot_product, normalize_vector, power_iteration
Registers: Integers x5–x15 for indices; Floats f0–f15 for arithmetic.
4. Template Data Section
.data
N:          .word   6
epsilon:    .float  0.001
max_iter:   .word   10

A:  .float  6.0, 2.0, 0.0, 0.0, 0.0, 0.0,
            2.0, 5.0, 1.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 4.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 3.0, 1.0, 0.0,
            0.0, 0.0, 0.0, 1.0, 2.0, 1.0,
            0.0, 0.0, 0.0, 0.0, 1.0, 1.0

v_init:     .float  1.0, 1.0, 1.0, 1.0, 1.0, 1.0
v_result:   .space  24
lambda_result: .float 0.0
5. Functional Requirements
Functions:
matvec_mul – Compute w = A×v (two nested loops).
dot_product – Compute vᵀ·w.
normalize_vector – Divide each component by ||w|| (fsqrt.s).
power_iteration – Perform iterative eigenvalue estimation and convergence check.
main – Initialize data, call subroutines, store λ and v.
6. Deliverables
1. Assembly file: power_iter_rv32imf.S
2. Execution evidence: screenshot or console dump showing λ and v_result.
3. Performance report (2 pages): instruction count, register allocation, loop optimization, precision analysis.
4. (Bonus +10 marks): use fmadd.s optimization.
7. Evaluation Rubric (100 Marks)
Criterion	Marks	Description
Correct eigenvalue/eigenvector computation	25	Produces correct λ, v within tolerance
RV32F floating-point ISA usage	15	Proper use of flw, fsw, fadd.s, fmul.s, fdiv.s
Modular subroutine design	10	JAL, stack usage, conventions
Matrix–vector and dot-product loops	20	Accurate addressing and iteration
Convergence logic	10	Proper float comparison and exit
Documentation	10	Readable, commented code
Performance report	10	Loop efficiency, instruction analysis
Bonus	+10	fmadd.s or optimization
8. Tools
Use either RARS or Venus (VS Code) simulators supporting RV32IMF.
9. Expected Output Example
Dominant Eigenvalue (λ): 7.8013
Eigenvector (v): [0.56, 0.49, 0.36, 0.25, 0.13, 0.07]
Iterations: 8
Converged: TRUE
10. Academic Integrity
All submissions must be individually authored. AI-generated or copied code will receive zero credit. Comments are mandatory for full marks.
 Appendix A — Installing and Using RARS
RARS (RISC-V Assembler and Runtime Simulator) is a Java-based IDE for writing and running RISC-V programs.

Installation:
1. Download from https://github.com/TheThirdOne/rars/releases
2. Run with:
   java -jar rars1_6.jar
3. Enable floating-point: Settings → Floating Point → Enabled (RV32F)

Usage:
- Open, assemble, run.
- Registers pane shows integer and float registers.
- Use 'li a7,2' + ecall to print float results.
 Appendix B — Using Venus with VS Code
Venus is a JavaScript-based RISC-V simulator that integrates with VS Code.

Setup:
1. Install VS Code → Extensions → 'Venus RISC-V Simulator'
2. Open your .S file → Click ▶ Run in Venus.
3. View output in the terminal window.

CLI Alternative:
   npm install -g venus
   venus-run your_file.S

Venus supports most RV32IMF instructions and is ideal for quick testing.
 Appendix C — Test Matrix and Expected Output
Matrix for Evaluation (A, symmetric 6×6):
[[6, 2, 0, 0, 0, 0],
 [2, 5, 1, 0, 0, 0],
 [0, 1, 4, 1, 0, 0],
 [0, 0, 1, 3, 1, 0],
 [0, 0, 0, 1, 2, 1],
 [0, 0, 0, 0, 1, 1]]

Expected Result (Approximate):
Dominant Eigenvalue λ ≈ 7.8013
Eigenvector v ≈ [0.56, 0.49, 0.36, 0.25, 0.13, 0.07]
Iterations ≈ 8, Converged = TRUE
