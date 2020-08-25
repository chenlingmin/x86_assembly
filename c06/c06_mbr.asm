    jmp near start


    mytext db 'L',0x07,'a',0x07,'b',0x07,'e',0x07,'l',0x07,' ',0x07,'o',0x07,\
            'f',0x07,'f',0x07,'s',0x07,'e',0x07,'t',0x07,':',0x07
    number db 0,0,0,0,0

start:
    mov ax, 0x07c0              ;设置数据段基地址
    mov ds, ax

    mov ax, 0xb800              ;设置附加段基地址
    mov es, ax

    cld                         ;方向清零 DF 设置为0, std 指令设置 DF 为 1
    mov si, mytext
    mov di, 0
    mov cx, (number-mytext)/2
    rep movsw

    ;得到标号所代表的偏移地址
    mov ax, number

    mov bx, ax
    mov cx, 5                   ;循环次数
    mov si, 10                  ;除数
digit:
    xor dx, dx
    div si
    mov [bx], dl
    inc bx
    loop digit

    mov bx, number
    mov si, 4
show:
    mov al, [bx+si]
    add al, 0x30                ;ASCII
    mov ah, 0x04                ;黑底红字
    mov [es:di], ax
    add di, 2
    dec si
    jns show                    ;检查 SF 上次计算的符号位，为0时跳转 show

    mov word [es:di], 0x0744

    jmp near $

times 510-($-$$)    db 0
                    db 0x55, 0xaa

