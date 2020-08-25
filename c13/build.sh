nasm c13_mbr.asm  -f bin  -o c13_mbr.bin  -l c13_mbr.lst && \
nasm c13_core.asm -f bin  -o c13_core.bin -l c13_core.lst && \
nasm c13.asm      -f bin  -o c13.bin      -l c13.lst && \
dd if=c13_mbr.bin  of=../learn.vhd          conv=notrunc && \
dd if=c13_core.bin of=../learn.vhd seek=1   conv=notrunc && \
dd if=c13.bin      of=../learn.vhd seek=50  conv=notrunc && \
dd if=diskdata.txt of=../learn.vhd seek=100 conv=notrunc && \
bochs