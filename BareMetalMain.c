typedef __UINT64_TYPE__ u64;

#define STR2( x )       #x
#define STR( x )        STR2( x )


#define CSR_WRITE( csr, val )       __asm__ volatile( "csrw " #csr ", %0"   :: "r"((u64)(val)) )
#define CSR_READ( csr, val )        __asm__ volatile( "csrr %0, " #csr       : "=r"((val)) )
#define CSR_SET( csr, val )         __asm__ volatile( "csrs " #csr ", %0"   :: "r"((u64)(val)) )
#define CSR_CLR( csr, val )         __asm__ volatile( "csrc " #csr ", %0"   :: "r"((u64)(val)) )

#define MRET()                      __asm__ volatile( "mret" )
#define SRET()                      __asm__ volatile( "sret" )

// NOTE: platform dependent, hardcoded for QEMU virt
#define CLINT_BASE      0x2000000
#define CLINT_MTIME     0x200BFF8
#define CLINT_MTIMECMP  0x2004000
#define CLINT_MSIP      0x2000000
#define TIMER_PERIOD    10000000 

typedef struct 
{
    u64 x[ 32 ];       // x0-x31
    u64 sepc;          // slot 32
    u64 sstatus;       // slot 33
} task_ctx_t ;

#define OFF_X31         248     // ( offsetof( task_ctx_t, x[31] ) )
#define OFF_SEPC        256     // ( offsetof( task_ctx_t, sepc ) )
#define OFF_SSTATUS     264     // ( offsetof( task_ctx_t, sstatus ) )
#define TASK_CTX_SIZE   272     // ( sizeof( task_ctx_t ) )

task_ctx_t userTask0Ctx = {};
task_ctx_t userTask1Ctx = {};
u64 currentTask = 0;
u64 userTask0Counter = 0;
u64 userTask1Counter = 0;


__attribute__((naked)) void SupervisorTrap()
{
    __asm__ volatile(
        "la     t2,         currentTask\n"
        "ld     t2,         0(t2)\n"
        "la     t0,         userTask0Ctx\n"
        "li     t3,         " STR( TASK_CTX_SIZE ) "\n"
        "mul    t2,         t2,     t3\n"
        "add    t0,         t0,     t2\n"
        "sd     x31,        " STR( OFF_X31 ) "(t0)\n"
        "mv     t6,         t0\n"
        "sd     x0,           0(t6)\n"
        "sd     x1,           8(t6)\n"
        "sd     x2,          16(t6)\n"
        "sd     x3,          24(t6)\n"
        "sd     x4,          32(t6)\n"
        "sd     x5,          40(t6)\n"
        "sd     x6,          48(t6)\n"
        "sd     x7,          56(t6)\n"
        "sd     x8,          64(t6)\n"
        "sd     x9,          72(t6)\n"
        "sd     x10,         80(t6)\n"
        "sd     x11,         88(t6)\n"
        "sd     x12,         96(t6)\n"
        "sd     x13,        104(t6)\n"
        "sd     x14,        112(t6)\n"
        "sd     x15,        120(t6)\n"
        "sd     x16,        128(t6)\n"
        "sd     x17,        136(t6)\n"
        "sd     x18,        144(t6)\n"
        "sd     x19,        152(t6)\n"
        "sd     x20,        160(t6)\n"
        "sd     x21,        168(t6)\n"
        "sd     x22,        176(t6)\n"
        "sd     x23,        184(t6)\n"
        "sd     x24,        192(t6)\n"
        "sd     x25,        200(t6)\n"
        "sd     x26,        208(t6)\n"
        "sd     x27,        216(t6)\n"
        "sd     x28,        224(t6)\n"
        "sd     x29,        232(t6)\n"
        "sd     x30,        240(t6)\n"
        "csrr   t0,         sepc\n"
        "sd     t0,         " STR( OFF_SEPC ) "(t6)\n"
        "csrr   t0,         sstatus\n"
        "sd     t0,         " STR( OFF_SSTATUS ) "(t6)\n"
        "call   Splitmix64\n"
        "la     t0,         userTask0Ctx\n"
        "li     t1,         " STR( TASK_CTX_SIZE ) "\n"
        "mul    t2,         a0,     t1\n"
        "add    t0,         t0,     t2\n"
        "mv     t6,         t0\n"
        "ld     t0,         " STR( OFF_SEPC ) "(t6)\n"
        "csrw   sepc,       t0\n"
        "ld     t0,         " STR( OFF_SSTATUS ) "(t6)\n"
        "csrw   sstatus,    t0\n"
        "ld     x1,           8(t6)\n"
        "ld     x2,          16(t6)\n"
        "ld     x3,          24(t6)\n"
        "ld     x4,          32(t6)\n"
        "ld     x5,          40(t6)\n"
        "ld     x6,          48(t6)\n"
        "ld     x7,          56(t6)\n"
        "ld     x8,          64(t6)\n"
        "ld     x9,          72(t6)\n"
        "ld     x10,         80(t6)\n"
        "ld     x11,         88(t6)\n"
        "ld     x12,         96(t6)\n"
        "ld     x13,        104(t6)\n"
        "ld     x14,        112(t6)\n"
        "ld     x15,        120(t6)\n"
        "ld     x16,        128(t6)\n"
        "ld     x17,        136(t6)\n"
        "ld     x18,        144(t6)\n"
        "ld     x19,        152(t6)\n"
        "ld     x20,        160(t6)\n"
        "ld     x21,        168(t6)\n"
        "ld     x22,        176(t6)\n"
        "ld     x23,        184(t6)\n"
        "ld     x24,        192(t6)\n"
        "ld     x25,        200(t6)\n"
        "ld     x26,        208(t6)\n"
        "ld     x27,        216(t6)\n"
        "ld     x28,        224(t6)\n"
        "ld     x29,        232(t6)\n"
        "ld     x30,        240(t6)\n"
        "ld     x31,        248(t6)\n"
        "li     a0,         1\n"
        "ecall\n"                   // clear STIP
        "sret\n"
    );
}

u64 Splitmix64()
{
    u64 t;
    CSR_READ( time, t );
    t += 0x9e3779b97f4a7c15ULL;
    u64 x = t;
    x = ( x ^ ( x >> 30 ) ) * 0xbf58476d1ce4e5b9ULL;
    x = ( x ^ ( x >> 27 ) ) * 0x94d049bb133111ebULL;
    x = x ^ ( x >> 31 );
    u64 next = x & 1;
    currentTask = next;
    return next;
}

void UserTask0()
{
    for( ;; )
    {
        userTask0Counter++;
    }
}

void UserTask1()
{
    for( ;; )
    {
        userTask1Counter++;
    }
}

void SupervisorMain()
{
    // set trap vector
    CSR_WRITE( stvec, ( u64 ) SupervisorTrap );

    // init task contexts
    userTask0Ctx.sepc    = ( u64 ) UserTask0;
    userTask0Ctx.sstatus = 0x20;
    userTask1Ctx.sepc    = ( u64 ) UserTask1;
    userTask1Ctx.sstatus = 0x20;

    __asm__ volatile( "li a0, 0\n ecall\n" );   // arm timer

    // jump to task0
    UserTask0();
}

__attribute__((naked)) void MachineTrap()
{
    __asm__ volatile(
        "csrr   t0,         mcause\n"
        "li     t1,         9\n"
        "bne    t0,         t1,     .LTimerTrap\n"
        // ecall path
        "csrr   t0,         mepc\n"
        "addi   t0,         t0,     4\n"
        "csrw   mepc,       t0\n"
        "beqz   a0,         .LArmTimer\n"
        // a0 = 1: clear STIP only
        "li     t0,         0x20\n"
        "csrc   mip,        t0\n"
        "mret\n"
        // a0 = 0: arm timer
        ".LArmTimer:\n"
        "li     t0,         " STR( CLINT_MTIME ) "\n"
        "ld     t1,         0(t0)\n"
        "li     t0,         " STR( TIMER_PERIOD ) "\n"
        "add    t1,         t1,     t0\n"
        "li     t2,         " STR( CLINT_MTIMECMP ) "\n"
        "sd     t1,         0(t2)\n"
        "mret\n"
        // timer trap: rearm + set STIP
        ".LTimerTrap:\n"
        "li     t0,         " STR( CLINT_MTIME ) "\n"
        "ld     t1,         0(t0)\n"
        "li     t0,         " STR( TIMER_PERIOD ) "\n"
        "add    t1,         t1,     t0\n"
        "li     t2,         " STR( CLINT_MTIMECMP ) "\n"
        "sd     t1,         0(t2)\n"
        "li     t0,         0x20\n"
        "csrs   mip,        t0\n"
        "mret\n"
    );
}

// NOTE: build with 
// clang --target=riscv64 -march=rv64g -mabi=lp64 -nostdlib -std=c23 -mcmodel=medany \
    -g -O0 -fno-omit-frame-pointer -T Stack.ld -e BareMetalMain BareMetalMain.c -o BareMetalMain
__attribute__((naked)) void BareMetalMain()
{
    __asm__ volatile(
        "la     t0,         SupervisorMain\n"
        "csrw   mepc,       t0\n"
        "la     t1,         MachineTrap\n"
        "csrw   mtvec,      t1\n"
        "li     t2,         0x1800\n"
        "csrc   mstatus,    t2\n"
        "li     t3,         0x0802\n"
        "csrs   mstatus,    t3\n"
        "li     t4,         0xa0\n"
        "csrs   mie,        t4\n"
        "li     t1,         0x20\n"
        "csrs   mideleg,    t1\n"
        "li     t0,         0x2\n"
        "csrs   mcounteren, t0\n"
        "mret\n"
    );
}