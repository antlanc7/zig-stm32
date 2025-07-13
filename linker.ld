MEMORY 
{
    FLASH (rx)  : ORIGIN = 0x08000000, LENGTH = 32K
    RAM   (rwx) : ORIGIN = 0x20000000, LENGTH = 6K
}
ENTRY(_start);
__reset_stack_pointer = ORIGIN(RAM) + LENGTH(RAM);
SECTIONS {
    .text : {
        _base = .;
        LONG(__reset_stack_pointer);
        LONG(_start | 1);
        . = _base + 12;
        LONG(hardFault_Handler);
        . = _base + 60;
        LONG(sysTick_Handler);
        . = _base + 172;
        LONG(usart1_irq_handler);
        LONG(usart2_irq_handler);
        /* The whole interrupt table is 332 bytes long. Advance to that position. */
        . = _base + 332;
        /* And here comes the rest of the code, ie. all symbols starting with .text */
        *(.text)
        *(.rodata*)
        . = ALIGN(4);
    } > FLASH  /* Put this in the flash memory region */
    .ARM.exidx : {
        *(.ARM.exidx*)
        . = ALIGN(4);
    } > FLASH

    /* ram, but not cleared on reset, eg boot/app comms */
    .noinit (NOLOAD) : {
        *(.noinit*)
    } > RAM
    . = ALIGN(4);

    .data : {
        _data = .;
        *(.data*)  /* Read-write initialized data */
        *(.ramtext*)    /* "text" functions to run in ram */
        . = ALIGN(4);
        _edata = .;
    } > RAM AT > FLASH
    _data_loadaddr = LOADADDR(.data);

    .bss : {
        _bss = .;
        *(.bss*)  /* Read-write zero initialized data */
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > RAM
}