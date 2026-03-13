STACK_SIZE = 0x400;    /* 1KB */

SECTIONS 
{
    . = 0x80000000;

    .text : 
    {
        *(.text.init)
        *(.text*)
    }

    .data : 
    {
        *(.data*)
        *(.bss*)
        *(.rodata*)
    }
    
    .stack : 
    {
        . = ALIGN(16);
        _stack_bottom = .;
        . += STACK_SIZE;
        _stack_top = .;
    }
}