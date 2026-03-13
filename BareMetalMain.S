.section .text
.global BareMetalMain

// NOTE: from https://danielmangum.com/posts/risc-v-bytes-privilege-levels/

// to build run:
//clang --target=riscv64 -march=rv64g -mabi=lp64 -nostdlib -x assembler-with-cpp -g \
// -T BareMetalMain.ld -e BareMetalMain BareMetalMain.S -o BareMetalMain

BareMetalMain:
    csrr    s0,         instret         // Saved reg
    la      t0,         Supervisor      // Load "pfn"/PC of Supervisor
    // Machine Exception Program Counter holds addr of the interruptor
    // store PC of Supervisor; mret will jump to this
    csrw    mepc,       t0              
    la      t1,         MachineTrap
    csrw    mtvec,      t1              // Set Machine Trap Vector 
    li      t2,         0x1800          // 0x1800 = bits 12:11 — MPP field →
    csrc    mstatus,    t2              // clear it (set privilege to U-mode)
    li      t3,         0x0800          // 0x0800  = bit 11 — MPP[1] → set it (force MPP=01 = S-mode)
    csrs    mstatus,    t3
    li      t4,         0x0100          // 0x0100 = bit 8 — excpt 8 (U-mode ecall) → S-mode deleg
    csrs    medeleg,    t4
    csrsi   mcounteren, 0x4
    mret
    
// mstatus ( Machine Status ):
// MIE (bit 3) — machine interrupt enable (global on/off)
// MPIE (bit 7) — saved MIE before trap (restored on mret)
// MPP (bits 12:11) — privilege level before trap (where mret returns to)

MachineTrap:
    csrr    t0,         mepc
    csrr    t1,         mcause
    la      t2,         Supervisor
    csrw    mepc,       t2
    mret

Supervisor: 
    la      t0,         User
    csrw    sepc,       t0
    la      t1,         SupervisorTrap
    csrw    stvec,      t1
    csrsi   scounteren, 0x4  // S-mode Counter Enable
    sret

// scounteren
// bit 0 = cycle
// bit 1 = time
// bit 2 = instret

SupervisorTrap:
    csrr    t0,         sepc
    csrr    t1,         scause
    ecall                       // Environment Call - triggers trap

User:
    csrr    t0,         instret // Counts instructions retired by curr hart
    sub     t1, t0, s0
    ecall
