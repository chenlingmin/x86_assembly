nasm c15_core.asm -f bin  -o c15_core.bin -l c15_core.lst && \
nasm c15.asm      -f bin  -o c15.bin      -l c15.lst && \
dd if=../c13/c13_mbr.bin  of=../learn.vhd          conv=notrunc && \
dd if=c15_core.bin        of=../learn.vhd seek=1   conv=notrunc && \
dd if=c15.bin             of=../learn.vhd seek=50  conv=notrunc && \
bochs