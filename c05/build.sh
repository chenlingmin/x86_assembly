nasm c05_mbr.asm -f bin  -o c05_mbr.bin -l c05_mbr.lst
dd if=c05_mbr.bin of=../learn.vhd bs=512 count=1 conv=notrunc
bochs