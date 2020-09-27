nasm c17_mbr.asm  -f bin  -o c17_mbr.bin  -l c17_mbr.lst && \
nasm c17_core.asm -f bin  -o c17_core.bin -l c17_core.lst && \
nasm c17_1.asm    -f bin  -o c17_1.bin    -l c17_1.lst && \
nasm c17_2.asm    -f bin  -o c17_2.bin    -l c17_2.lst && \
dd if=c17_mbr.bin         of=../learn.vhd          conv=notrunc && \
dd if=c17_core.bin        of=../learn.vhd seek=1   conv=notrunc && \
dd if=c17_1.bin           of=../learn.vhd seek=50  conv=notrunc && \
dd if=c17_2.bin           of=../learn.vhd seek=100 conv=notrunc && \
bochs