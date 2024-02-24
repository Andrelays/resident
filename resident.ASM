.286
.model tiny
.code
org 100h
locals @@

PTR_CMD    		equ 0080h  				;ptr of cmd line
PTR_VIDMEM    	equ 0b800h 				;ptr of video memory

x_coord_average equ 5
y_coord_average equ 5

Start:	push 0
		pop es

		mov ax, 3509h
		int 21h							;get int vector addr: es:bx

		mov Old09Offs, bx
		mov bx, es
		mov Old09Seg, bx

		push ds ;save ds
		mov  dx, offset IntOverride09
		push cs
		pop ds
		mov ax, 2509h
		int 21h							;set int vector addr: ds:dx
		pop ds 							;restore ds

		mov dx, offset EndOfProg
		shr dx, 4
		inc dx 							;sizeof(prog) / 16 + 1
		mov ax, 3100h
		int 21h

IntOverride09	proc
		push ax bx es

		push PTR_VIDMEM					;es - ptr of video memory
		pop es

		in  al, 60h						;scan code of symbol
		cmp al, 11d						;cmp symbol is 0
		jne @@end_if					;if you press not 0

		push ds							;save ds
		push cs
		pop  ds							;change ds = cs

		push 11d						;width
		push 10h						;frame_color (10h - 0001'0000)
		push 0Bh						;border_color(0Bh - 0000'1011)
		push offset control_str_array	;style of frame
		push 10d						;length

		call draw_frame

		pop ds							;ret ds

@@end_if:
		pop es bx ax

		db 0eah 		;far jump

Old09Offs	dw 0
Old09Seg	dw 0

IntOverride09	endp

;------------------------------DRAW_FRAME----------------------------
;Draw a frame to video memory
;Entry: [bp+4]  - length
;		[bp+6]  - style of frame
;		[bp+8]  - border_color
;		[bp+10] - frame_color
;		[bp+12] - width
;Assumes: es = 0b800h
;--------------------------------------------------------------------
draw_frame			proc
					push bp
					mov  bp, sp

					push bx							;save registers
					push cx
					push ax
					push dx
					push di

					mov cx, [bp+4]					;length
					mov bx, [bp+12]   				;width
					shr bx, 1						;width  / 2
					shr cx, 1						;length / 2
					mov ax, x_coord_average
					mov dx, y_coord_average
					sub ax, cx						;y_coord_average - frame_width  / 2
					sub dx, bx						;x_coord_average - frame_length / 2
					imul dx, 80						;(y_coord_average - frame_width / 2) * 80
					mov di, ax
					add di, dx
					shl di, 1						;mov di, ((y_coord_average - frame_width / 2) * 80 + (x_coord_average - frame_length / 2)) * 2

					mov  bx, [bp + 6]

					push [bp + 10]
					push [bp + 8]
					push  bx
					push [bp + 4]

					call draw_line					;draw the first line of the frame

					add bx, 3						;bx is next line of array

					;(80 - frame_length - 2) * 2
					mov cx, [bp+12]
					sub cx, 2						;cx is frame_width - 2

@@draw_inside_frame:
					mov ax, 80
					sub ax, [bp+4]
					shl ax, 1
					add di, ax						;di += (80 - frame_length) * 2

					push [bp + 10]
					push [bp + 8]
					push  bx
					push [bp + 4]

					call draw_line
					loop @@draw_inside_frame

					mov ax, 80
					sub ax, [bp+4]
					shl ax, 1
					add di, ax						;di += (80 - 2 - frame_length) * 2

					add bx, 3						;bx is next line of array

					push [bp + 10]
					push [bp + 8]
					push  bx
					push [bp + 4]

					call draw_line					;draw the last line of the frame

					pop di
					pop dx
					pop ax
					pop cx							;ret regs
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
draw_line   		proc
					push bp
					mov  bp, sp

					push ax
					push bx							;save registers
					push cx

	    			mov  bx, [bp + 6]				;bx - style of frame

	    			mov  ah, [bp + 8]
					add  ah, [bp + 10]				;draw - first character
					mov  al, [bx]
        			stosw

					mov  ah, [bp + 8]
					add  ah, [bp + 10]
	    			mov  al, [bx] + 1				;draw - second character * (length - 2)
	    			mov  cx, [bp + 4]
					sub  cx,  2
        			rep  stosw

					mov  ah, [bp + 8]
					add  ah, [bp + 10]				;draw - third character
					mov  al, [bx] + 2
					stosw

					pop cx
					pop bx							;ret regs
					pop ax
					pop bp

        			ret 8
draw_line   		endp

control_str_array 			db 0c9h, 0cdh, 0bbh
				  			db 0bah, 020h, 0bah
				  			db 0c8h, 0cdh, 0bch
EndOfProg:
end		Start



