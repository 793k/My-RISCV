/* Linker script for My-RISCV CPU (Harvard: ROM=IF only, RAM=load/store) */
MEMORY {
    ROM (rx) : ORIGIN = 0x00000000, LENGTH = 8K
    RAM (rw) : ORIGIN = 0x40000000, LENGTH = 8K
}

SECTIONS {
    .text : {
        *(.text*)
    } > ROM

    /* .rodata goes to RAM so load instructions can read it via the bus.
       Boot code copies it from ROM (where it lives in flash) to RAM. */
    .rodata : {
        __rodata_start = .;
        *(.rodata*)
        *(.srodata*)
        __rodata_end = .;
    } > RAM AT > ROM

    __rodata_load_start = LOADADDR(.rodata);

    .data : {
        __data_start = .;
        *(.data*)
        *(.sdata*)
        __data_end = .;
    } > RAM AT > ROM

    __data_load_start = LOADADDR(.data);

    .bss : {
        __bss_start = .;
        *(.bss*)
        *(.sbss*)
        __bss_end = .;
    } > RAM

    __stack_top = ORIGIN(RAM) + LENGTH(RAM);
    __global_pointer$ = __data_start + 0x800;
}
