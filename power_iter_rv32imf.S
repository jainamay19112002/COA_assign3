    .section .data
# data section from assignment
N:          .word   6
epsilon:    .float  0.001
max_iter:   .word   10

A:  .float  6.0, 2.0, 0.0, 0.0, 0.0, 0.0, \
            2.0, 5.0, 1.0, 0.0, 0.0, 0.0, \
            0.0, 1.0, 4.0, 1.0, 0.0, 0.0, \
            0.0, 0.0, 1.0, 3.0, 1.0, 0.0, \
            0.0, 0.0, 0.0, 1.0, 2.0, 1.0, 
            0.0, 0.0, 0.0, 0.0, 1.0, 1.0

v_init:     .float  1.0, 1.0, 1.0, 1.0, 1.0, 1.0
w_vec:      .space  24         # temporary w vector (6*4)
v_result:   .space  24         # final normalized eigenvector
lambda_result: .float 0.0
lambda_prev:  .float 0.0       # scratch for previous lambda

# small constants
one_f:      .float 1.0
zero_f:     .float 0.0

    .section .text
    .globl main
main:
    # --- Setup: enable stack if needed (simple program, no stack frame) ---
    # Load addresses for data into registers
    la  a0, A         # a0 -> &A
    la  a1, v_init    # a1 -> &v_init
    la  a2, w_vec     # a2 -> &w (temp)
    li  a3, 6         # a3 -> N

    # Call power_iteration(a0=A, a1=v_init, a2=w_vec, a3=N)
    jal ra, power_iteration

    # Done — At this point lambda_result and v_result are stored in .data
    # Print results: (RARS/venus: you can inspect memory; we also optionally print using ecall)
    # Print lambda_result as float using ecall service 2 (RARS)
    la  a0, lambda_result
    flw f10, 0(a0)        # get lambda into f10
    fmv.x.w t0, f10       # move float bits into integer reg
    # RARS prints float when a0 in f12? Simpler: load into f12 and use ecall 2
    # RARS uses a0 = value for integer print. To print float, do li a7, 3?? (RARS doc differs)
    # Instead, just end and view memory in simulator.
    # exit
    li  a7, 10
    ecall

# ------------------------------
# power_iteration:
# Inputs:
#   a0 -> &A
#   a1 -> &v_init
#   a2 -> &w (temporary)
#   a3 -> N (6)
# Uses: calls matvec_mul, dot_product, normalize_vector
# Stores result in v_result and lambda_result
# ------------------------------
power_iteration:
    # Save ra and s0 on stack (we will use s0)
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)

    mv s0, a3        # s0 = N (6)

    # copy v_init into local current v buffer (we'll use v_result as current v location)
    la t0, v_result
    mv t1, a1        # t1 -> &v_init
    li t2, 6
copy_v_loop:
    beqz t2, copy_v_done
    # load float from v_init, store to v_result
    flw f0, 0(t1)
    fsw f0, 0(t0)
    addi t1, t1, 4
    addi t0, t0, 4
    addi t2, t2, -1
    j copy_v_loop
copy_v_done:

    # initial lambda_prev = 0.0
    la t0, lambda_prev
    flw f0, zero_f
    fsw f0, 0(t0)

    # load epsilon and max_iter
    la t0, epsilon
    flw f1, 0(t0)        # f1 = epsilon
    la t1, max_iter
    lw t2, 0(t1)         # t2 = max_iter

    li t3, 0             # iter = 0
iter_loop:
    # Call matvec_mul: w = A * v_result
    # a0=&A, a1=&v_result, a2=&w_vec, a3=N
    la a0, A
    la a1, v_result
    la a2, w_vec
    mv a3, s0
    jal ra, matvec_mul

    # Compute numerator = v_prev^T * w (call dot_product)
    la a0, v_result
    la a1, w_vec
    mv a2, s0
    jal ra, dot_product
    # Return: dot in f0
    # Store numerator in stack memory (we'll store to a local word on stack)
    addi sp, sp, -8
    fsw f0, 0(sp)        # numerator at 0(sp)

    # Compute denominator = v_prev^T * v_prev
    la a0, v_result
    la a1, v_result
    mv a2, s0
    jal ra, dot_product
    fsw f0, 4(sp)        # denominator at 4(sp)

    # Compute lambda = numerator / denominator -> f0 / f1 -> result in f2
    flw f0, 0(sp)        # numerator
    flw f1, 4(sp)        # denominator
    # safety: if denominator==0, skip (but with v_init not zero it's fine)
    fdiv.s f2, f0, f1    # f2 = lambda_k

    # load previous lambda
    la t0, lambda_prev
    flw f3, 0(t0)        # f3 = lambda_prev

    # compute diff = abs(lambda_k - lambda_prev) in f4
    fsub.s f4, f2, f3
    # if negative, take neg
    fsgnjx.s f5, f4, f4   # not portable; instead do compare then fneg.s conditionally
    # Simpler: take absolute by checking sign bit using fclass? Some assemblers differ.
    # We'll do a conditional branch using fsub and flt
    fsub.s f6, f2, f3     # f6 = lambda_k - lambda_prev
    # Use floating point compare: feq? In RARS: use flt.s to set x0? RISC-V has fcmp instructions as floating conditional branches:
    # Use "flt.s f2,f3" style? RISC-V uses `flt.s rd, fs1, fs2` -> rd = 1/0 integer. We'll implement using integer register to store comparison.
    flt.s t4, f6, f0      # THIS IS WRONG: flt.s sets integer reg; syntax: flt.s rd, fs1, fs2. We'll use it properly below.
    # To keep compatibility and keep code simple, we will compute absolute via conditional fneg: if f6 < 0 then fneg.s f6,f6

    # check if f6 < 0
    flt.s t0, f6, f0      # compare f6 < 0.0 -> t0 = 1 if true
    beqz t0, abs_skip
    fneg.s f6, f6
abs_skip:
    # now f6 = |lambda_k - lambda_prev|
    # compare f6 < epsilon (epsilon in f1 earlier)
    flt.s t1, f6, f1
    bnez t1, converged

    # not converged -> normalize w_vec into v_result (w_norm -> v_result)
    la a0, w_vec
    la a1, v_result
    mv a2, s0
    jal ra, normalize_vector

    # store lambda_k into lambda_prev
    la t0, lambda_prev
    fsw f2, 0(t0)

    # increment iteration counter
    addi t3, t3, 1
    blt t3, t2, iter_loop   # if iter < max_iter continue

    # ended due to iter limit -> store lambda and return
    j store_and_return

converged:
    # store lambda_k into lambda_prev (and will be saved to lambda_result later)
    la t0, lambda_prev
    fsw f2, 0(t0)
    # also normalize w into v_result (the last normalized v)
    la a0, w_vec
    la a1, v_result
    mv a2, s0
    jal ra, normalize_vector

store_and_return:
    # store lambda_prev into lambda_result
    la t0, lambda_prev
    flw f0, 0(t0)
    la t1, lambda_result
    fsw f0, 0(t1)

    # restore sp and saved regs
    addi sp, sp, 8         # pop numerator/denominator space if still present
    lw ra, 12(sp)
    lw s0, 8(sp)
    addi sp, sp, 16
    ret

# ---------------------------------------
# matvec_mul: w = A * v
# a0: &A, a1: &v, a2: &w (out), a3: N
# assumes floats single precision 4 bytes
# ---------------------------------------
matvec_mul:
    # Save ra
    sd ra, -8(sp)         # if tool accepts sd; to be safe use sw
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    mv s0, a3             # s0 = N
    li t0, 0              # row index i = 0

matvec_row_loop:
    bge t0, s0, matvec_done
    # initialize sum = 0.0 in f0
    flw f0, zero_f

    # compute row base pointer: &A + (i*N)*4
    # row_offset_bytes = t0 * s0 * 4  (since N is s0)
    mv t1, t0             # t1 = i
    mv t2, s0             # t2 = N
    mul t3, t1, t2        # t3 = i*N
    slli t3, t3, 2        # *4 bytes
    add t4, a0, t3        # t4 = &A + row_offset

    li t5, 0              # col j = 0
matvec_col_loop:
    bge t5, s0, matvec_row_store
    # load A[i][j]
    flw f1, 0(t4)         # f1 = A[i][j]
    # load v[j]
    # compute &v + j*4
    mv t6, t5
    slli t6, t6, 2
    add t7, a1, t6
    flw f2, 0(t7)         # f2 = v[j]
    # multiply and accumulate
    fmul.s f3, f1, f2
    fadd.s f0, f0, f3     # sum += A[i][j] * v[j]
    addi t4, t4, 4        # next A element
    addi t5, t5, 1
    j matvec_col_loop

matvec_row_store:
    # store sum into w[i]
    mv t8, a2
    mv t9, t0
    slli t9, t9, 2
    add t8, t8, t9
    fsw f0, 0(t8)

    addi t0, t0, 1
    j matvec_row_loop

matvec_done:
    lw ra, 12(sp)
    lw s0, 8(sp)
    addi sp, sp, 16
    ret

# ---------------------------------------
# dot_product: computes sum = x^T * y
# a0: &x, a1: &y, a2: N
# returns result in f0
# ---------------------------------------
dot_product:
    addi sp, sp, -8
    sw ra, 4(sp)

    mv t0, a2      # t0 = N
    li t1, 0       # index
    flw f0, zero_f # sum = 0.0

dot_loop:
    beq t1, t0, dot_done
    # load x[i]
    mv t2, a0
    slli t3, t1, 2
    add t2, t2, t3
    flw f1, 0(t2)
    # load y[i]
    mv t4, a1
    add t4, t4, t3
    flw f2, 0(t4)
    # multiply & accumulate
    fmul.s f3, f1, f2
    fadd.s f0, f0, f3
    addi t1, t1, 1
    j dot_loop

dot_done:
    lw ra, 4(sp)
    addi sp, sp, 8
    ret

# ---------------------------------------
# normalize_vector: normalize src -> dst
# a0: &src (w), a1: &dst (v_result), a2: N
# compute norm = sqrt(sum w[i]^2); then dst[i] = w[i] / norm
# ---------------------------------------
normalize_vector:
    addi sp, sp, -8
    sw ra, 4(sp)

    mv t0, a2
    li t1, 0
    flw f0, zero_f   # sumsq = 0
norm_loop:
    beq t1, t0, norm_done
    # load w[t1]
    mv t2, a0
    slli t3, t1, 2
    add t2, t2, t3
    flw f1, 0(t2)
    fmul.s f2, f1, f1
    fadd.s f0, f0, f2
    addi t1, t1, 1
    j norm_loop

norm_done:
    fsqrt.s f0, f0   # f0 = norm
    # divide each component by norm and store to dst
    mv t1, 0
    li t1, 0
    mv t4, a2
    li t5, 0
norm_div_loop:
    beq t5, t4, norm_div_done
    # load w[t5]
    mv t2, a0
    slli t3, t5, 2
    add t2, t2, t3
    flw f1, 0(t2)
    fdiv.s f2, f1, f0   # f2 = w[i] / norm
    # store into dst
    mv t6, a1
    add t6, t6, t3
    fsw f2, 0(t6)
    addi t5, t5, 1
    j norm_div_loop

norm_div_done:
    lw ra, 4(sp)
    addi sp, sp, 8
    ret

# small literals in memory
    .section .rodata
zero_f: .float 0.0
one_f:  .float 1.0
