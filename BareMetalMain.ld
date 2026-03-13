SECTIONS
{
  . = 0x80000000;       /* PC Entry Addr as expectd by QEMU virt */
  .text : { *(.text) }
}