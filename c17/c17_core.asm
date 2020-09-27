;-------------------------------------------------------------------------------
        ;以下是常量
        flat_4gb_code_seg_sel   equ 0x0008      ;平坦模型下的4GB代码段选择子
        flat_4gb_data_seg_sel   equ 0x0018      ;平坦模型下的4GB数据段选择子
        idt_linear_address      equ 0x8001f000  ;中断描述符表的线性基地址
;-------------------------------------------------------------------------------
        ;以下定义宏
        %macro  alloc_core_linear 0             ;在内核空间分配虚拟内存
                mov ebx, [core_tcb+0x06]
                add dword [core_tcb+0x06], 0x1000
                call flat_4gb_core_seg_sel:alloc_inst_a_page
        %endmacro
;-------------------------------------------------------------------------------
        %macro  alloc_user_linear 0             ;在任务空间分配虚拟内存
                mov ebx, [esi+0x06]
                add dword [esi+0x06], 0x1000
                call flat_4gb_core_seg_sel:alloc_inst_a_page
        %endmacro
;===============================================================================
SECTION core vstart=0x80004000

        ;以下是系统核心的头部，用于加载核心程序
        core_length     dd  core_end            ;核心程序总长度#00
        core_entry      dd  start               ;核心代码段入口点#04
;-------------------------------------------------------------------------------
        [bits 32]
;-------------------------------------------------------------------------------
         ;字符串显示例程（适用于平坦内存模型）
put_string:                                     ;显示0终止的字符串并移动光标
                                                ;输入：EBX=字符串的线性地址
        push ebx
        push ecx

        cli                                     ;硬件操作期间，关中断

    .getc:
        mov cl, [ebx]
        or  cl, cl                              ;检测串结束标志（0）
        jz .exit                                ;显示完毕，返回
        call put_char
        inc ebx
        jmp .getc

    .exit:

        sti                                     ;硬件操作完毕，开放中断

        pop ecx
        pop ebx

        retf                                    ;段间返回

;-------------------------------------------------------------------------------
put_char:                                       ;在当前光标处显示一个字符,并推进
                                                ;光标。仅用于段内调用
                                                ;输入：CL=字符ASCII码
        pushad

        ;以下取当前光标位置
        mov dx, 0x3d4
        mov al, 0x0e
        out dx, al
        inc dx                                  ;0x3d5
        in  al, dx                              ;高字
        mov ah, al

        dec dx                                  ;0x3d4
        mov al, 0x0f
        out dx, al
        inc dx                                  ;0x3d5
        in  al, dx                              ;低字
        mov bx, ax                              ;BX=代表光标位置的16位数
        and ebx, 0x0000ffff                     ;准备使用32位寻址方式访问显存

        cmp cl, 0x0d                            ;回车符？
        jnz .put_0a

        mov ax, bx                              ;以下按回车符处理
        mov bl, 80
        div bl
        mul bl
        mov bx, ax
        jmp .set_cursor

    .put_0a:
        cmp cl, 0x0a                            ;换行符？
        jnz .put_other
        add bx, 80                              ;增加一行
        jmp .roll_screen

    .put_other:                                 ;正常显示字符
        shl bx, 1
        mov [0x800b8000+ebx], cl                ;在光标位置处显示字符

        ;以下将光标位置推进一个字符
        shr bx, 1
        inc bx

    .roll_screen:
        cmp bx, 2000                            ;光标超出屏幕？滚屏
        jl  .set_cursor

        cld
        mov esi, 0x800b80a0                     ;小心！32位模式下movsb/w/d
        mov edi, 0x800b8000                     ;使用的是esi/edi/ecx
        mov ecx, 1920
        rep movsd
        mov bx, 3840                            ;清除屏幕最底一行
        mov ecx, 80                             ;32位程序应该使用ECX
    .cls:
        mov word [0x800b8000+ebx], 0x0720
        add bx, 2
        loop .cls

        mov bx, 1920

    .set_cursor:
        mov dx, 0x3d4
        mov al, 0x0e
        out dx, al
        inc dx                                  ;0x3d5
        mov al, bh
        out dx, al
        dec dx                                  ;0x3d4
        mov al, 0x0f
        out dx, al
        inc dx                                  ;0x3d5
        mov al, bl
        out dx, al

        popad

        ret
;-------------------------------------------------------------------------------
make_gate_descriptor:                           ;构造门的描述符（调用门等）
                                                ;输入：EAX=门代码在段内偏移地址
                                                ;       BX=门代码所在段的选择子
                                                ;       CX=段类型及属性等（各属
                                                ;          性位都在原始位置）
                                                ;返回：EDX:EAX=完整的描述符
        push ebx
        push ecx

        mov edx, eax
        and edx, 0xffff0000                     ;得到偏移地址高16位
        or  dx, cx                              ;组装属性部分到EDX

        and eax, 0x0000ffff                     ;得到偏移地址低16位
        shl ebx, 16
        or  eax, ebx                            ;组装段选择子部分

        pop ecx
        pop ebx

        retf

;-------------------------------------------------------------------------------
general_interrupt_handler:                      ;通用的中断处理过程
        push eax

        mov al, 0x20                            ;中断结束命令EOI
        out 0xa0, al                            ;向从片发送
        out 0x20, al                            ;向主片发送

        pop eax

        iretd
;-------------------------------------------------------------------------------
general_exception_handler:                      ;通用的异常处理过程
        mov ebx, excep_msg
        call flat_4gb_code_seg_sel:put_string

        hlt
;-------------------------------------------------------------------------------
rtm_0x70_interrupt_handle:                      ;实时时钟中断处理过程

        pushad

        mov al, 0x20                            ;中断结束命令EOI
        out 0xa0, al                            ;向8259A从片发送
        out 0x20, al                            ;向8259A主片发送

        mov al, 0x0c                            ;寄存器C的索引。且开放NMI
        out 0x70, al
        in  al, 0x71                            ;读一下RTC的寄存器C，否则只发生一次中断
                                                ;此处不考虑闹钟和周期性中断的情况
        ;找当前任务（状态为忙的任务）在链表中的位置
        mov eax, tcb_chain
    .b0:                                        ;EAX=链表头或当前TCB线性地址
        mov ebx, [eax]                          ;EBX=下一个TCB线性地址
        or  ebx, ebx
        jz  .irtn                               ;链表为空，或已到末尾，从中断返回
        cmp word [ebx+0x04], 0xffff             ;是忙任务（当前任务）？
        je  .b1
        mov eax, ebx                            ;定位到下一个TCB（的线性地址）
        jmp .b0

        ;将当前为忙的任务移到链尾
    .b1:
        mov ecx, [ebx]                          ;下游TCB的线性地址
        mov [eax], ecx                          ;将当前任务从链中拆除

    .b2:                                        ;此时，EBX=当前任务的线性地址
        mov edx, [eax]
        or  edx, edx                            ;已到链表尾端?
        jz  .b3
        mov eax, edx
        jmp .b2

    .b3:
        mov [eax], ebx                          ;将忙任务的TCB挂在链表尾端
        mov dword [ebx], 0x00000000             ;将忙任务的TCB标记为链尾

        ;从链首搜索第一个空闲任务
        mov eax, tcb_chain
    .b4:
        mov eax, [eax]
        or  eax, eax                            ;已到链尾（未发现空闲任务）
        jz .irtn                                ;未发现空闲任务，从中断返回
        cmp word [eax+0x04], 0x0000             ;是空闲任务？
        jnz .b4

        ;将空闲任务和当前任务的状态都取反
        not word [eax+0x04]                     ;设置空闲任务的状态为忙
        not word [ebx+0x04]                     ;设置当前任务（忙）的状态为空闲
        jmp far [eax+0x14]                      ;任务切换

    .irtn:
        popad

        iretd
;-------------------------------------------------------------------------------
        pgdt            dw 0                    ;用于设置和修改GDT
                        dd 0

        pidt            dw  0
                        dd  0

        ;任务控制块链
        tcb_chain       dd  0

        core_tcb  times 32  db 0         ;内核（程序管理器）的TCB

        page_bit_map    db  0xff,0xff,0xff,0xff,0xff,0xff,0x55,0x55
                        db  0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff
                        db  0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff
                        db  0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff
                        db  0x55,0x55,0x55,0x55,0x55,0x55,0x55,0x55
                        db  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
                        db  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
                        db  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
        page_map_len    equ $-page_bit_map

        ;符号地址检索表
        salt:
        salt_1          db  '@PrintString'
                    times 256-($-salt_1) db 0
                        dd  put_string
                        dw  flat_4gb_code_seg_sel
;
;        salt_2          db  '@ReadDiskData'
;                    times 256-($-salt_2) db 0
;                        dd  read_hard_disk_0
;                        dw  flat_4gb_code_seg_sel
;
;        salt_3          db  '@PrintDwordAsHexString'
;                    times 256-($-salt_3) db 0
;                        dd  put_hex_dword
;                        dw  flat_4gb_code_seg_sel
;
;        salt_4          db  '@TerminateProgram'
;                    times 256-($-salt_4) db 0
;                        dd  terminate_current_task
;                        dw  flat_4gb_code_seg_sel

        salt_item_len   equ $-salt_1
        salt_items      equ ($-salt)/salt_item_len

        excep_msg       db  '********Exception encounted********',0

        message_0       db  '  Working in system core with protection '
                        db  'and paging are all enabled.System core is mapped '
                        db  'to address 0x80000000.',0x0d,0x0a,0

        message_1       db  '  System wide CALL-GATE mounted.',0x0d,0x0a,0

        message_3       db  '********No more pages********',0

        core_msg0       db  '  System core task running!',0x0d,0x0a,0

        bin_hex         db '0123456789ABCDEF'   ;put_hex_dword子过程用的查找表

        core_buf   times 512 db 0               ;内核用的缓冲区

        cpu_brnd0       db 0x0d,0x0a,'  ',0
        cpu_brand  times 52 db 0
        cpu_brnd1       db 0x0d,0x0a,0x0d,0x0a,0

;-------------------------------------------------------------------------------
start:
        ;创建中断描述符IDT
        ;在此之前，禁止调用put_string过程，以及任何含有sti指令的过程

        ;前20个向量是处理器异常使用的
        mov eax, general_exception_handler      ;门代码在段内偏移地址
        mov bx, flat_4gb_code_seg_sel           ;门代码所在段的选择子
        mov cx, 0x8e00                          ;32位中断门，0特权级
        call flat_4gb_code_seg_sel:make_gate_descriptor

        mov ebx, idt_linear_address             ;中断描述符表的线性地址
        xor esi, esi
    .idt0:
        mov [ebx+esi*8], eax
        mov [ebx+esi*8+4], edx
        inc esi
        cmp esi, 19                             ;安装前20个异常中断处理过程
        jle .idt0

        ;其余为保留或硬件使用的中断向量
        mov eax, general_interrupt_handler      ;门代码在段内偏移地址
        mov bx, flat_4gb_code_seg_sel           ;门代码所在段的选择子
        mov cx, 0x8e00                          ;32位中断门，0特权级
        call flat_4gb_code_seg_sel:make_gate_descriptor

        mov ebx, idt_linear_address             ;中断描述符表的线性地址
    .idt1:
        mov [ebx+esi*8], eax
        mov [ebx+esi*8+4], edx
        inc esi
        cmp esi, 255                            ;安装普通的中断处理过程
        jle .idt1

        ;设置实时时钟中断处理过程
        mov eax, rtm_0x70_interrupt_handle      ;门代码在段内偏移地址
        mov bx, flat_4gb_code_seg_sel           ;门代码所在段的选择子
        mov cx, 0x8e00                          ;32位中断门，0特权级
        call flat_4gb_code_seg_sel:make_gate_descriptor

        mov ebx, idt_linear_address             ;中断描述符表的线性地址
        mov [ebx+0x70*8], eax
        mov [ebx+0x70*8+4], edx

        ;准备开放中断
        mov word [pidt], 256*8-1                ;IDT的界限
        mov dword [pidt+2], idt_linear_address
        lidt [pidt]                             ;加载中断描述符表寄存器IDTR

        ;设置8259A中断控制器
        mov al, 0x11
        out 0x20, al                            ;ICW1：边沿触发/级联方式
        mov al, 0x20
        out 0x21, al                            ;ICW2:起始中断向量
        mov al, 0x04
        out 0x21, al                            ;ICW3:从片级联到IR2
        mov al, 0x01
        out 0x21, al                            ;ICW4:非总线缓冲，全嵌套，正常EOI

        mov al, 0x11
        out 0xa0, al                            ;ICW1：边沿触发/级联方式
        mov al, 0x70
        out 0xa1, al                            ;ICW2:起始中断向量
        mov al, 0x04
        out 0xa1, al                            ;ICW3:从片级联到IR2
        mov al, 0x01
        out 0xa1, al                            ;ICW4:非总线缓冲，全嵌套，正常EOI

        ;设置和时钟中断相关的硬件
        mov al, 0x0b                            ;RTC寄存器B
        or  al, 0x80                            ;阻断NMI
        out 0x70, al
        mov al, 0x12                            ;设置寄存器B，禁止周期性中断，开放更
        out 0x71, al                            ;新结束后中断，BCD码，24小时制

        in  al, 0xa1                            ;读8259从片的IMR寄存器
        and al, 0xfe                            ;清除bit 0(此位连接RTC)
        out 0xa1, al                            ;写回此寄存器

        mov al, 0x0c
        out 0x70, al
        in  al, 0x71                            ;读RTC寄存器C，复位未决的中断状态

        sti                                     ;开放硬件中断

        mov ebx, message_0
        call flat_4gb_code_seg_sel:put_string

        ;显示处理器品牌信息
        mov eax, 0x80000002
        cpuid
        mov [cpu_brand + 0x00], eax
        mov [cpu_brand + 0x04], ebx
        mov [cpu_brand + 0x08], ecx
        mov [cpu_brand + 0x0c], edx

        mov eax, 0x80000003
        cpuid
        mov [cpu_brand + 0x10], eax
        mov [cpu_brand + 0x14], ebx
        mov [cpu_brand + 0x18], ecx
        mov [cpu_brand + 0x1c], edx

        mov eax, 0x80000004
        cpuid
        mov [cpu_brand + 0x20], eax
        mov [cpu_brand + 0x24], ebx
        mov [cpu_brand + 0x28], ecx
        mov [cpu_brand + 0x2c], edx

        mov ebx, cpu_brnd0                      ;显示处理器品牌信息
        call flat_4gb_code_seg_sel:put_string
        mov ebx, cpu_brand
        call flat_4gb_code_seg_sel:put_string
        mov ebx, cpu_brnd1
        call flat_4gb_code_seg_sel:put_string


        hlt

core_code_end:

;-------------------------------------------------------------------------------
SECTION core_trail
;-------------------------------------------------------------------------------
core_end: