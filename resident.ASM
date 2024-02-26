.286
.model tiny
.code
org 100h
locals @@

PTR_CMD         equ 0080h               ;ptr of cmd line
PTR_VIDMEM    	equ 0b800h              ;ptr of video memory

x_coord_average equ 5
y_coord_average equ 7

override macro offs, int_comm
    mov  dx, offset offs
    push cs
    pop  ds
    mov  ax, int_comm
    int  21h                            ;set int vector addr: ds:dx
endm

Start:
        mov ax, 0
        mov es, ax

        ;call IntOverride09

        mov ax, 3509h
        int 21h                         ;get int vector addr: es:bx

        mov Old09Offs, bx
        mov bx, es
        mov Old09Seg, bx

        mov ax, 3508h
        int 21h

        mov Old08Offs, bx
        mov bx, es
        mov Old08Seg, bx

        push ds ;save ds

        override IntOverride09 2509h    ;set int vector addr: ds:dx
        override IntOverride08 2508h

        pop  ds                         ;restore ds

        mov dx, offset EndOfProg
        shr dx, 4
        inc dx                          ;sizeof(prog) / 16 + 1
        mov ax, 3100h
        int 21h

;-----------------------INTERRUPT--------------------------------------
;----------------------------------------------------------------------
IntOverride09	proc
        push sp
        push ax

        in  al, 60h                     ;scan code of symbol
        ;and al, 127d
        cmp al, 10d                     ;cmp symbol is 9

        jne @@check_zero                ;if you press not 9
        push ds
        push cs
        pop  ds                         ;change ds = cs

        xor register_output_mode, 1     ;output_mode = !(output_mode)

        pop ds                          ;return ds

        jmp @@end_if

@@check_zero:
        cmp al, 11d                     ;cmp symbol is 0
        jne @@end_if                    ;if you press not 0

        push bx cx dx si di bp ds es ss

        push cs
        pop  ds                         ;change ds = cs

        call draw_regs_table

        pop ss es ds bp di si dx cx bx
@@end_if:
        pop ax
        pop sp

        db 0eah                         ;far jump

Old09Offs   dw 0
Old09Seg    dw 0

IntOverride09   endp

IntOverride08   proc
        push ds
        push cs
        pop  ds                         ;change ds = cs

        cmp register_output_mode, 1     ;continuous register update mode
        jne @@end_if

        pop ds
        push sp ax bx cx dx si di bp ds es ss

        push cs
        pop  ds                         ;change ds = cs

        call draw_regs_table

        pop ss es ds bp di si dx cx bx ax sp
        push ds


@@end_if:
        pop ds
        db 0eah                         ;far jump

Old08Offs   dw 0
Old08Seg    dw 0

IntOverride08	endp
;---------------------------FUNCTIONS------------------------------------
;-------------------------PRINT_REGS_TABLE----------------------------
;draws a table with registers in video memory
;Entry: [bp+4] - [bp + 28]  - regs
;Destr: AX, BX, DI, SI, ES
;------------------------------------------------------------------------
draw_regs_table 	proc
        lea  si, frame_text
        add  si, 3
        call stringify_registers

        push PTR_VIDMEM                 ;es - ptr of video memory
        pop es

        push 15d                        ;width
        push 10h                        ;frame_color (10h - 0001'0000)
        push 0Bh                        ;border_color(0Bh - 0000'1011)
        push offset control_str_array   ;style of frame
        push 10d                        ;length

        call draw_frame

        lea si, frame_text
        call output_frame_text
        ret
draw_regs_table     endp
;------------------------------SAVE_REGISTERS----------------------------
;Saves the ascii codes of register values in an array
;Entry: [bp+6] - [bp + 30]  - regs:
;       [bp + 2]  - ret value from stringify_registers
;       [bp + 4]  - ret value from draw_regs_table
;       [bp + 6]  - cs
;       [bp + 8]  - ip
;       [bp + 10] - sp
;       [bp + 12] - ax
;       [bp + 14] - bx
;       [bp + 16] - cx
;       [bp + 18] - dx
;       [bp + 20] - si
;       [bp + 22] - di
;       [bp + 24] - bp
;       [bp + 26] - ds
;       [bp + 28] - es
;       [bp + 30] - ss
;Assumes: SI is offset frame_text
;Table view:    'cs ', value of regs, '\n'
;               'ip ', value of regs, '\n'
;               'sp ', value of regs, '\n'
;               'ax ', value of regs, '\n'
;               'bx ', value of regs, '\n'
;               'cx ', value of regs, '\n'
;               'dx ', value of regs, '\n'
;               'si ', value of regs, '\n'
;               'di ', value of regs, '\n'
;               'bp ', value of regs, '\n'
;               'ds ', value of regs, '\n'
;               'es ', value of regs, '\n'
;               'ss ', value of regs, '\n', '$'
;Destr: AX, BX, DI, SI
;------------------------------------------------------------------------
stringify_registers		proc
        push bp
        mov  bp, sp

        lea bx, hexadecimal_digits      ;bx is offset of table hexadecimal digits
        mov di, 30 + 1                  ;start with di = 31

@@for_cycle:
        cmp di, 4 + 1                   ;if (di == 5) finish saving
        je @@end_for_cycle

        mov al, [bp][di]                ;al = [bp + di]
        call byte_to_chars              ;ax is str of al
        mov [si], ax

        add si, 2
        dec di

        mov al, [bp][di]
        call byte_to_chars
        mov [si], ax

        add si, 6
        dec di

        jmp @@for_cycle

@@end_for_cycle:

        pop bp
        ret
stringify_registers		endp
;------------------------------BYTE_TO_CHARS----------------------------
;Converts 1 byte of a number to ascii codes
;Entry:   AL - the number to be translated
;Assumes: BX is offset hexadecimal_digits
;Return:  AL and AH - ascii codes of digits
;Destr:   AX
;------------------------------------------------------------------------
byte_to_chars       proc
        mov ah, al          ;AH = AL
        and al, 0F0h        ;delete the lowest  digit of a number in Al
        sub ah, al          ;delete the highest digit of a number in AH

        shr al, 4
        xlat                ;puts a digit in AL, its equivalent of the ASCII code

        xchg ah, al         ;swaps Al and AH
        xlat                ;puts a digit in AL, its equivalent of the ASCII code

        xchg ah, al         ;swaps Al and AH

        ret
byte_to_chars       endp

;------------------------------OUTPUT_FRAME_TEXT-------------------------
;Outputs text from the buffer to video memory(does not change colors)
;Entry: [bp+4] - [bp + 28]  - regs
;Assumes: SI is offset frame_text
;         es = 0b800h
;         di = the first character of the frame from which you can write text
;10d - ascii code of the newline character
;'$' - buffer end character
;Destr: di, si
;------------------------------------------------------------------------
output_frame_text   proc
        push bp
        mov  bp, sp

        push bx                 ;save regs
        push ax

        xor bx, bx              ;bx = 0

@@while_cycle:
        mov al, [si]            ;al is symbol
        inc si                  ;si++
        cmp al, '$'             ;end of text
        je @@end_while_cycle

        cmp al, 10              ;new line
        jne @@continue_line

        mov ax, 80
        sub ax, bx              ;bx - character counter per line
        shl ax, 1
        add di, ax              ;di += (80 - line_length) * 2
        xor bx, bx              ;bx = 0
        jmp @@while_cycle

@@continue_line:

        inc bx                  ;bx++
        stosb                   ;does not change color
        inc di
        jmp @@while_cycle


@@end_while_cycle:

        pop ax
        pop bx                  ;return regs
        pop bp

        ret
output_frame_text   endp


;------------------------------DRAW_FRAME----------------------------
;Draw a frame to video memory
;Entry: [bp+4]  - length
;       [bp+6]  - style of frame
;       [bp+8]  - border_color
;       [bp+10] - frame_color
;       [bp+12] - width
;Assumes: ES = 0b800h
;Retrn:   DI is the first character of the frame from which you can write text
;--------------------------------------------------------------------
draw_frame          proc
        push bp
        mov  bp, sp

        push bx                         ;save registers
        push cx
        push ax
        push dx

        mov cx, [bp+4]                  ;length
        mov bx, [bp+12]                 ;width
        shr bx, 1                       ;width  / 2
        shr cx, 1                       ;length / 2
        mov ax, x_coord_average
        mov dx, y_coord_average
        sub ax, cx                      ;y_coord_average - frame_width  / 2
        sub dx, bx                      ;x_coord_average - frame_length / 2
        imul dx, 80                     ;(y_coord_average - frame_width / 2) * 80
        mov di, ax
        add di, dx
        shl di, 1                       ;mov di, ((y_coord_average - frame_width / 2) * 80 + (x_coord_average - frame_length / 2)) * 2
        push di

        mov  bx, [bp + 6]

        push [bp + 10]
        push [bp + 8]
        push  bx
        push [bp + 4]

        call draw_line                  ;draw the first line of the frame

        add bx, 3                       ;bx is next line of array

        ;(80 - frame_length - 2) * 2
        mov cx, [bp+12]
        sub cx, 2                       ;cx is frame_width - 2

@@draw_inside_frame:
        mov ax, 80
        sub ax, [bp+4]
        shl ax, 1
        add di, ax                      ;di += (80 - frame_length) * 2

        push [bp + 10]
        push [bp + 8]
        push  bx
        push [bp + 4]

        call draw_line
        loop @@draw_inside_frame

        mov ax, 80
        sub ax, [bp+4]
        shl ax, 1
        add di, ax                      ;di += (80 - 2 - frame_length) * 2

        add bx, 3                       ;bx is next line of array

        push [bp + 10]
        push [bp + 8]
        push  bx
        push [bp + 4]

        call draw_line                  ;draw the last line of the frame

        pop di
        add di, 81 * 2                  ;di the first character of the frame from which you can write text

        pop dx
        pop ax
        pop cx                          ;ret regs
        pop bx
        pop bp

        ret 10
draw_frame  		endp
;------------------------------DRAW_LINE-----------------------------
;Draw a line to video memory
;Entry: [bp+4]  - length
;		[bp+6]  - style of frame
;		[bp+8]  - border_color
;		[bp+10] - frame_color
;Assumes: es = 0b800h
;		  di is ptr of the beginning of the line
;--------------------------------------------------------------------
draw_line       proc
        push bp
        mov  bp, sp

        push ax
        push bx                         ;save registers
        push cx

        mov  bx, [bp + 6]               ;bx - style of frame

        mov  ah, [bp + 8]
        add  ah, [bp + 10]              ;draw - first character
        mov  al, [bx]
        stosw

        mov  ah, [bp + 8]
        add  ah, [bp + 10]
        mov  al, [bx] + 1               ;draw - second character * (length - 2)
        mov  cx, [bp + 4]
        sub  cx,  2
        rep  stosw

        mov  ah, [bp + 8]
        add  ah, [bp + 10]              ;draw - third character
        mov  al, [bx] + 2
        stosw

        pop cx
        pop bx                          ;ret regs
        pop ax
        pop bp

        ret 8
draw_line           endp

control_str_array   db 0c9h, 0cdh, 0bbh
                    db 0bah, 020h, 0bah
                    db 0c8h, 0cdh, 0bch

frame_text	db 'cs ', 4 dup('0'), 10
            db 'ip ', 4 dup('0'), 10
            db 'sp ', 4 dup('0'), 10
            db 'ax ', 4 dup('0'), 10
            db 'bx ', 4 dup('0'), 10
            db 'cx ', 4 dup('0'), 10
            db 'dx ', 4 dup('0'), 10
            db 'si ', 4 dup('0'), 10
            db 'di ', 4 dup('0'), 10
            db 'bp ', 4 dup('0'), 10
            db 'ds ', 4 dup('0'), 10
            db 'es ', 4 dup('0'), 10
            db 'ss ', 4 dup('0'), 10, '$'

hexadecimal_digits  db '0123456789ABCDEF'

register_output_mode db 0, '$'

EndOfProg:
end     Start



