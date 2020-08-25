nasm ../c08/c08_mbr.asm -f bin  -o ../c08/c08_mbr.bin -l ../c08/c08_mbr.lst
nasm c09_2.asm          -f bin  -o c09_2.bin          -l c09_2.lst
dd if=../c08/c08_mbr.bin of=../learn.vhd          conv=notrunc
dd if=c09_2.bin          of=../learn.vhd seek=100 conv=notrunc
bochs