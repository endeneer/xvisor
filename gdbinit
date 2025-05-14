
# tar rem:1234
target extended-remote localhost:1234
add-inferior
inferior 2
attach 2
info threads

symbol-file build/vmm.elf
# b arch/common/generic_defterm.c:715
# b core/vmm_stdio.c:885

c
