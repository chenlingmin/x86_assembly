nasm ../c08/c08_mbr.asm -f bin  -o ../c08/c08_mbr.bin -l ../c08/c08_mbr.lst
nasm c09_1.asm          -f bin  -o c09_1.bin          -l c09_1.lst
dd if=../c08/c08_mbr.bin of=../learn.vhd          conv=notrunc
dd if=c09_1.bin          of=../learn.vhd seek=100 conv=notrunc
bochs