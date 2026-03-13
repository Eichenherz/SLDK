// NOTE: from https://danielmangum.com/posts/risc-v-bytes-privilege-levels/

// to build run:
//clang --target=riscv64 -march=rv64g -mabi=lp64 -nostdlib -x assembler-with-cpp -g -T BareMetalMain.ld -e BareMetalMain BareMetalMain.S -o BareMetalMain

// ==========================================================================================
// mstatus ( Machine Status ):
// ==========================================================================================
// Bit(s)  Name   Description
// ------------------------------------------------------------------------------------------
// 0       UIE    User-mode interrupt enable (legacy N-ext, ignore)
// 1       SIE    Supervisor interrupt enable
// 2       —      Reserved
// 3       MIE    Machine interrupt enable (global, THIS is what you clear on trap entry)
// 4       UPIE   Prior UIE (saved on trap)
// 5       SPIE   Prior SIE
// 6       —      Reserved
// 7       MPIE   Prior MIE (hardware saves MIE here on trap, mret restores it back)
// 8-9     SPP    Prior privilege level for S-mode (1 bit effectively)
// 10-11   MPP    Prior privilege level for M-mode (2 bits: 00=U, 01=S, 11=M)
// 12-13   FS     FPU state (00=off, 01=initial, 10=clean, 11=dirty)
// 14-15   XS     Custom extension state (same encoding as FS)
// 16      MPRV   Memory privilege: if set, loads/stores use MPP privilege not current
// 17      SUM    Supervisor User Memory access (S-mode can touch U pages)
// 18      MXR    Make eXecutable Readable (execute-only pages become readable)
// 19      TVM    Trap Virtual Memory (traps SFENCE.VMA in S-mode)
// 20      TW     Timeout Wait (traps WFI in S-mode)
// 21      TSR    Trap SRET (traps sret in S-mode)
// 22-31   —      Reserved
// 32-33   UXL    U-mode XLEN (01=32, 10=64, 11=128)
// 34-35   SXL    S-mode XLEN
// 36      SBE    S-mode big-endian
// 37      MBE    M-mode big-endian
// 38-62   —      Reserved
// 63      SD     State Dirty: FS or XS == 11 (dirty), summary bit
// ==========================================================================================

// ==========================================================================================
// mie ( Machine Interrupt Enable ):
// ==========================================================================================
// Bit     Name    Description
// ------------------------------------------------------------------------------------------
// 0       USIE    User software interrupt enable
// 1       SSIE    Supervisor software interrupt enable
// 2       —       Reserved
// 3       MSIE    Machine software interrupt enable
// 4       UTIE    User timer interrupt enable
// 5       STIE    Supervisor timer interrupt enable
// 6       —       Reserved
// 7       MTIE    Machine timer interrupt enable 
// 8       UEIE    User external interrupt enable
// 9       SEIE    Supervisor external interrupt enable
// 10      —       Reserved
// 11      MEIE    Machine external interrupt enable
// 12-63   —       Reserved / platform-defined
// ==========================================================================================

// ==========================================================================================
// mip ( Machine Interrupt Pending ):
// ==========================================================================================
// Bit     Name    Description
// ------------------------------------------------------------------------------------------
// 0       USIP    User software interrupt pending
// 1       SSIP    Supervisor software interrupt pending (writable by M-mode)
// 2       —       Reserved
// 3       MSIP    Machine software interrupt pending (writable via CLINT mmio)
// 4       UTIP    User timer interrupt pending
// 5       STIP    Supervisor timer interrupt pending (writable by M-mode)
// 6       —       Reserved
// 7       MTIP    Machine timer interrupt pending (read-only, cleared via mtimecmp)
// 8       UEIP    User external interrupt pending
// 9       SEIP    Supervisor external interrupt pending (writable by M-mode)
// 10      —       Reserved
// 11      MEIP    Machine external interrupt pending (read-only, set by PLIC)
// 12-63   —       Reserved / platform-defined
// ==========================================================================================

// ==========================================================================================
// mideleg ( Machine Interrupt Delegation ):
// ==========================================================================================
// Bit     Name    Description
// ------------------------------------------------------------------------------------------
// 0       USIP    Delegate user software interrupt to S-mode
// 1       SSIP    Delegate supervisor software interrupt to S-mode
// 2       —       Reserved
// 3       MSIP    Delegate machine software interrupt (cannot delegate, always M-mode)
// 4       UTIP    Delegate user timer interrupt to S-mode
// 5       STIP    Delegate supervisor timer interrupt to S-mode
// 6       —       Reserved
// 7       MTIP    Delegate machine timer interrupt (cannot delegate, always M-mode)
// 8       UEIP    Delegate user external interrupt to S-mode
// 9       SEIP    Delegate supervisor external interrupt to S-mode
// 10      —       Reserved
// 11      MEIP    Delegate machine external interrupt (cannot delegate, always M-mode)
// 12-63   —       Reserved / platform-defined
// ==========================================================================================

// ==========================================================================================
// medeleg ( Machine Exception Delegation ):
// ==========================================================================================
// Bit     Name                Description
// ------------------------------------------------------------------------------------------
// 0       INST_MISALIGN       Delegate instruction address misaligned to S-mode
// 1       INST_ACCESS         Delegate instruction access fault to S-mode
// 2       ILLEGAL_INST        Delegate illegal instruction to S-mode
// 3       BREAKPOINT          Delegate breakpoint to S-mode
// 4       LOAD_MISALIGN       Delegate load address misaligned to S-mode
// 5       LOAD_ACCESS         Delegate load access fault to S-mode
// 6       STORE_MISALIGN      Delegate store/AMO address misaligned to S-mode
// 7       STORE_ACCESS        Delegate store/AMO access fault to S-mode
// 8       ECALL_U             Delegate ecall from U-mode to S-mode
// 9       ECALL_S             Delegate ecall from S-mode 
// 10      —                   Reserved
// 11      ECALL_M             Delegate ecall from M-mode (cannot delegate, stays M-mode)
// 12      INST_PAGE_FAULT     Delegate instruction page fault to S-mode
// 13      LOAD_PAGE_FAULT     Delegate load page fault to S-mode
// 14      —                   Reserved
// 15      STORE_PAGE_FAULT    Delegate store/AMO page fault to S-mode
// 16-63   —                   Reserved / platform-defined
// ==========================================================================================

// NOTE: platform dependent, hardcoded for QEMU virt
#define CLINT_BASE      0x2000000
#define CLINT_MSIP      ( CLINT_BASE + 0x0000 )
#define CLINT_MTIMECMP  ( CLINT_BASE + 0x4000 )
#define CLINT_MTIME     ( CLINT_BASE + 0xBFF8 )
#define TIMER_PERIOD    100000000     

.section .data

userTask0Counter:   .dword 0
userTask1Counter:   .dword 0
currentTask:        .dword 0

#define TASK_CTX( name ) \
name:                    \
    .fill 34, 8, 0          // 34 dwords init to 0

TASK_CTX( userTask0Ctx )
TASK_CTX( userTask1Ctx )

.section .text

#define SAVE_CONTEXT( base )           \
    sd      x31,        31*8( base ) ; \
    mv      t6,         base         ; \
    sd      x0,         0*8( t6 )   ; \
    sd      x1,         1*8( t6 )   ; \
    sd      x2,         2*8( t6 )   ; \
    sd      x3,         3*8( t6 )   ; \
    sd      x4,         4*8( t6 )   ; \
    sd      x5,         5*8( t6 )   ; \
    sd      x6,         6*8( t6 )   ; \
    sd      x7,         7*8( t6 )   ; \
    sd      x8,         8*8( t6 )   ; \
    sd      x9,         9*8( t6 )   ; \
    sd      x10,        10*8( t6 )  ; \
    sd      x11,        11*8( t6 )  ; \
    sd      x12,        12*8( t6 )  ; \
    sd      x13,        13*8( t6 )  ; \
    sd      x14,        14*8( t6 )  ; \
    sd      x15,        15*8( t6 )  ; \
    sd      x16,        16*8( t6 )  ; \
    sd      x17,        17*8( t6 )  ; \
    sd      x18,        18*8( t6 )  ; \
    sd      x19,        19*8( t6 )  ; \
    sd      x20,        20*8( t6 )  ; \
    sd      x21,        21*8( t6 )  ; \
    sd      x22,        22*8( t6 )  ; \
    sd      x23,        23*8( t6 )  ; \
    sd      x24,        24*8( t6 )  ; \
    sd      x25,        25*8( t6 )  ; \
    sd      x26,        26*8( t6 )  ; \
    sd      x27,        27*8( t6 )  ; \
    sd      x28,        28*8( t6 )  ; \
    sd      x29,        29*8( t6 )  ; \
    sd      x30,        30*8( t6 )  ; \
    csrr    t0,         sepc        ; \
    sd      t0,         32*8( t6 )  ; \
    csrr    t0,         sstatus     ; \
    sd      t0,         33*8( t6 )

#define RESTORE_CONTEXT( base )        \
    mv      t6,         base         ; \
    ld      t0,         32*8( t6 )  ; \
    csrw    sepc,       t0           ; \
    ld      t0,         33*8( t6 )  ; \
    csrw    sstatus,    t0           ; \
    ld      x1,         1*8( t6 )   ; \
    ld      x2,         2*8( t6 )   ; \
    ld      x3,         3*8( t6 )   ; \
    ld      x4,         4*8( t6 )   ; \
    ld      x5,         5*8( t6 )   ; \
    ld      x6,         6*8( t6 )   ; \
    ld      x7,         7*8( t6 )   ; \
    ld      x8,         8*8( t6 )   ; \
    ld      x9,         9*8( t6 )   ; \
    ld      x10,        10*8( t6 )  ; \
    ld      x11,        11*8( t6 )  ; \
    ld      x12,        12*8( t6 )  ; \
    ld      x13,        13*8( t6 )  ; \
    ld      x14,        14*8( t6 )  ; \
    ld      x15,        15*8( t6 )  ; \
    ld      x16,        16*8( t6 )  ; \
    ld      x17,        17*8( t6 )  ; \
    ld      x18,        18*8( t6 )  ; \
    ld      x19,        19*8( t6 )  ; \
    ld      x20,        20*8( t6 )  ; \
    ld      x21,        21*8( t6 )  ; \
    ld      x22,        22*8( t6 )  ; \
    ld      x23,        23*8( t6 )  ; \
    ld      x24,        24*8( t6 )  ; \
    ld      x25,        25*8( t6 )  ; \
    ld      x26,        26*8( t6 )  ; \
    ld      x27,        27*8( t6 )  ; \
    ld      x28,        28*8( t6 )  ; \
    ld      x29,        29*8( t6 )  ; \
    ld      x30,        30*8( t6 )  ; \
    ld      x31,        31*8( t6 )



.global BareMetalMain

BareMetalMain: // Firmware-ish
    la      t0,         SupervisorMain  
    csrw    mepc,       t0              // mret will jump to this   
    la      t1,         MachineTrap
    csrw    mtvec,      t1              
    
    li      t2,         0x1800          
    csrc    mstatus,    t2              
    li      t3,         0x0802          
    csrs    mstatus,    t3              
    li      t4,         0xa0 
    csrs    mie,        t4

    li      t1,         0x20
    csrs    mideleg,    t1
    // Set Timer
    li      t2,         TIMER_PERIOD  
    li      t3,         CLINT_MTIMECMP
    sd      t2,         0(t3)
    // Read time counter in S mode
    li      t0,         0x2
    csrs    mcounteren, t0
    mret

MachineTrap: // NOTE: S can't access the timer CSRs directly so we use this Trap to bounce
    // Rearm timer
    li      t0,         CLINT_MTIME
    ld      t1,         0(t0)
    li      t0,         TIMER_PERIOD
    add     t1,         t1,     t0
    li      t2,         CLINT_MTIMECMP
    sd      t1,         0(t2)
    // Raise S mode TIE
    li      t4,         0x20
    csrs    mip,        t4
    mret

SupervisorMain: // Kernel-ish
    la      t0,         SupervisorTrap
    csrw    stvec,      t0

    la      t0,         userTask0Ctx
    la      t1,         UserTask0
    sd      t1,         256( t0 )       // sepc task0  ( 32*8 )
    li      t2,         0x20
    sd      t2,         264( t0 )       // sstatus task0 ( 33*8 ) SPP=0=U-mode, SPIE=1

    la      t0,         userTask1Ctx
    la      t1,         UserTask1
    sd      t1,         256( t0 )       // sepc task1  ( 32*8 )
    li      t2,         0x20
    sd      t2,         264( t0 )       // sstatus task1 ( 33*8 ) SPP=0=U-mode, SPIE=1

    j       UserTask0

SupervisorTrap: // Scheduler
    // Which task is running
    la      t0,         userTask0Ctx
    la      t2,         currentTask
    ld      t2,         0(t2)
    li      t3,         34*8            // NOTE: this works bc we know the layout of the 2 tasks
    mul     t2,         t2,     t3      // branchless if
    add     t0,         t0,     t2
    SAVE_CONTEXT( t0 )

    jal     Splitmix64          // a0 = 0 or 1; randomly decide which task to run

    la      t0,         currentTask
    sd      a0,         0(t0)       // update current_task

    la      t0,         userTask0Ctx
    li      t1,         34*8
    mul     t2,         a0,     t1
    add     t0,         t0,     t2  // t0 = ctx[a0]

    RESTORE_CONTEXT( t0 )
    sret


// Splitmix64 on time CSR -> 0 or 1
// seed += 0x9e3779b97f4a7c15
// x = seed
// x = (x ^ x>>30) * 0xbf58476d1ce4e5b9
// x = (x ^ x>>27) * 0x94d049bb133111eb
// x = x ^ x>>31
Splitmix64:
    csrr    a0,         time
    li      t0,         0x9e3779b97f4a7c15
    add     a0,         a0,         t0
    mv      t0,         a0
    srli    t1,         a0,         30
    xor     t0,         t0,         t1
    li      t1,         0xbf58476d1ce4e5b9
    mul     t0,         t0,         t1
    srli    t1,         t0,         27
    xor     t0,         t0,         t1
    li      t1,         0x94d049bb133111eb
    mul     t0,         t0,         t1
    srli    t1,         t0,         31
    xor     a0,         t0,         t1
    andi    a0,         a0,         1
    ret

UserTask0:
    la      t0,         userTask0Counter
    ld      t1,         0(t0)
    addi    t1,         t1, 1
    sd      t1,         0(t0)
    j       UserTask0

UserTask1:
    la      t0,         userTask1Counter
    ld      t1,         0(t0)
    addi    t1,         t1, 1
    sd      t1,         0(t0)
    j       UserTask1
