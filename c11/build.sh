nasm c11_mbr.asm -f bin  -o c11_mbr.bin -l c11_mbr.lst
dd if=c11_mbr.bin of=../learn.vhd bs=512 count=1 conv=notrunc
bochs