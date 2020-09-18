nasm c16_core.asm -f bin  -o c16_core.bin -l c16_core.lst && \
nasm c16.asm      -f bin  -o c16.bin      -l c16.lst && \
dd if=../c13/c13_mbr.bin  of=../learn.vhd          conv=notrunc && \
dd if=c16_core.bin        of=../learn.vhd seek=1   conv=notrunc && \
dd if=c16.bin             of=../learn.vhd seek=50  conv=notrunc && \
bochs