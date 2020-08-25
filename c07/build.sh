nasm c07_mbr.asm -f bin  -o c07_mbr.bin -l c07_mbr.lst
dd if=c07_mbr.bin of=../learn.vhd bs=512 count=1 conv=notrunc
bochs