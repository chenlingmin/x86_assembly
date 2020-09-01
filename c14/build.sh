nasm c14_core.asm -f bin  -o c14_core.bin -l c14_core.lst && \
dd if=../c13/c13_mbr.bin  of=../learn.vhd          conv=notrunc && \
dd if=c14_core.bin        of=../learn.vhd seek=1   conv=notrunc && \
dd if=../c13/c13.bin      of=../learn.vhd seek=50  conv=notrunc && \
dd if=../c13/diskdata.txt of=../learn.vhd seek=100 conv=notrunc && \
bochs