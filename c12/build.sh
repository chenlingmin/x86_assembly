nasm c12_mbr.asm -f bin  -o c12_mbr.bin -l c12_mbr.lst
dd if=c12_mbr.bin of=../learn.vhd bs=512 count=1 conv=notrunc
bochs