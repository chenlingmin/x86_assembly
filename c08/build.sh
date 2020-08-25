nasm c08_mbr.asm -f bin  -o c08_mbr.bin -l c08_mbr.lst
nasm c08.asm -f bin  -o c08.bin -l c08.lst
dd if=c08_mbr.bin of=../learn.vhd          conv=notrunc
dd if=c08.bin     of=../learn.vhd seek=100 conv=notrunc
bochs