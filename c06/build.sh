nasm c06_mbr.asm -f bin  -o c06_mbr.bin -l c06_mbr.lst
dd if=c06_mbr.bin of=../learn.vhd bs=512 count=1 conv=notrunc
bochs