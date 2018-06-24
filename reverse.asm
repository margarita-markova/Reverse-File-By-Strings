.model small

.stack 100h

.data	  

maxCMDSize                 equ 127
cmd_size	               db  ?
cmd_text	               db  maxCMDSize + 2 dup(0)
sourcePath	               db  129 dup (0) 
tempSourcePath	           db  128 dup (0)					
			    
spaceSymbol	               equ ' '
newLineSymbol	           equ 0Dh
returnSymbol	           equ 0Ah
tabulation	               equ 9
endl		               equ 0
max_length	               equ 30

startProcessing            db "Processing started", '$'			
startText	               db  "Program is started", '$'
startOutput                db  "Start reverse output", '$'
badCMDArgsMessage          db  "Bad command-line arguments.", '$'
badSourceText	           db  "Open error", '$'    
fileNotFoundText           db  "File not found", '$'
endText 	               db  0Dh,0Ah,"Program is ended", '$'
errorReadSourceText        db  "Error reading from source file", '$'
errorClosingSource         db  "Cannot close source file", '$'
emptyFileMsg               db  "This file is empty", '$'

destinationPath            db 'c:\emu8086\MyBuild\outputFile.txt', 0
extension	               db "txt"	     
point2		               db '.'
buf		                   db  0			 
sourceID	               dw  0
destinationID              dw  0	

string		               db  0Dh, 0Ah
number		               dw  0
spaces                     dw  0     
array_positions            dw  max_length dup (?) 

.code

println macro info	    ;����� �� ����� �������� ������
	push ax 		
	push dx 		
			    
	mov ah, 09h		    ; ������� ������ 
	lea dx, info		; �������� � dx �������� ���������� ���������
	int 21h 		    ; ����� ����������� ��� ���������� ������
			    
	mov dl, 0Ah		    ; ������ �������� �� ����� ������
	mov ah, 02h		    ; ������� ������ �������
	int 21h 		    ; ����� ����������
			    
	mov dl, 0Dh		    ; ������ �������� � ������ ������   
	mov ah, 02h		
	int 21h 		     
			    
	pop dx			
	pop ax			
endm

strcpy macro destination, source, count   ; ������, ��������������� ��� ����������� �� source � destination �������� ���������� ��������
    push cx
    push di
    push si
    
    xor cx, cx
    
    mov cl, count
    lea si, source
    lea di, destination
    
    rep movsb
    
    pop si
    pop di
    pop cx
ENDM

fseek macro symbolsInt, symbols, ID   ; ����������� �������(�������) � ����� 
	push ax 		    
	push bx 		    
	push cx 		    
	push dx 		                  ; ��������� �������� ���������
				
	mov ah, 42h		                  ; ���������� � ah ��� 42h - �-��� DOS ��������� ��������� ����� 
	mov bx, ID                        ; ���������� �����
	xor al ,al				  
	mov al, symbolsInt	              ; al - � ������, � ����� ��� � ������� �������
	mov cx, 0		                  ; �������� cx 
	mov dx, symbols 		          ; �������� dx, �.� ��������� ��������� �� 0 �������� �� ������ ����� (cx*2^16)+dx 
	int 21h 		                  ; �������� ���������� DOS ��� ���������� ��������	
				
	pop dx			                  ; ��������������� �������� ��������� � ������� �� ���������
	pop cx			   
	pop bx			    
	pop ax			    
endm

    Main:
	    mov ax, @data		    ; ��������� ������
	    mov es, ax		
			    
	    xor ch, ch	
	    mov cl, ds:[80h]		; ���������� �������� ������, ���������� ����� ��������� ������
	    mov bl, cl
	    mov cmd_size, cl		; � cmd_size ��������� ����� ��������� ������
	    dec bl			        ; ��������� �������� ���������� �������� � ������ �� 1, �.�. ������ ������ ������
	    mov si, 81h		        ; �������� �� ��������, ���������� ����� ��������� ������
	    lea di, tempSourcePath	      
	
	    rep movsb		        ; �������� � ������ ������� ES:DI ���� �� ������ DS:SI
	
	    mov ds, ax		        ; ��������� � ds ������  
	    mov cmd_size, bl	
	
        mov cl, bl
	    lea di, cmd_text
	    lea si, tempSourcePath
	    inc si
	    rep movsb
				
	    println startText	    ; ����� ������ � ������ ������ ���������
			    
	    call parseCMD		    ; ����� ��������� �������� ��������� ������
	    cmp ax, 0		
	    jne endMain				; ���� ax != 0, �.�. ��� ��������� ��������� ��������� ������ - ��������� ���������   
	
	    call openFiles		    ; �������� ���������, ������� ��������� ����, ���������� ����� ��������� ������
	    cmp ax, 0		
	    jne endMain	
	
	    call processingFile   
	
	    call closeFiles 	
	    cmp ax, 0		
	    jne endMain
	
	endMain:
	    println endText 	
	    mov ah, 4Ch		
	    int 21h      
		   
processingFile proc 
    begin:
        println startProcessing
	    xor si, si
	    xor di, di 
	    xor bx, bx  
	    fseek 0, 0, sourceID            ; ����������� ��������� � ������ ��������� �����
	    xor cx, cx
	    mov cx, max_length

	    mov array_positions[bx], 0      ; ������ ������ ������ ���������� � ������� 0
	    add bx, 2                       ; ���������� 2, �.�. array_positions ������� �� ���� 
    
	findStartsOfStrings:                ; ����� ���� ������ � ������ ������� ������ ����� ����� � �������� �� ���� � ������� ��������(�� ��������)
	    call readSymbolFromFile
	    add number, 1                   ; ������� ������� ��� ������ � ������
	    cmp buf, spaceSymbol
	    je checkSpaces
	    cmp buf, tabulation
	    je checkSpaces
	    cmp buf, newLineSymbol
	    je checkSpaces                   ; � EOF ������� ���������� �������� � number, � � number ��������� ��� ������� 
	    cmp buf, returnSymbol
	    je addToArray 
	    cmp buf, endl
	    je EOF
	    jmp findStartsOfStrings
	    
	checkSpaces:
	    add spaces, 1
	    jmp findStartsOfStrings
	
	addToArray:                          ; � EOF ������� ���������� �������� � number, � � number ��������� ��� �������
	    add spaces, 1 
	    push ax 
	    xor ax, ax 
	    ;add number, 1
	    ;dec ax
	    mov ax, number
	    ;dec ax                   ; ����� � ax ��������� ������� ������ ����� � ����� ������
	    mov array_positions[bx], ax      ; ��������� � 0
	    add bx, 2
	    ;sub number, 1                    ; ���� ������� ����� ������, �� �� 2 ���� ��������� ������ ���, � �� �� 1
	    pop ax 
	    jmp findStartsOfStrings
	
	EOF: 
	    cmp number, 1                    ; ���� ����� ������� ����� �����, �� ���� ������
	    je emptyFile
	    add spaces, 1                    ; ��� �������� ��������: �� ������� 0Dh, 0Ah, � 0 - ����� ����� - �� �������, ������� ������� ���
	    push ax                          ; �.�. cmp spaces, number ������ ������, ������ �����������
	    push cx 
	    xor cx, cx                       
	    xor ax, ax
	    mov cx, spaces
	    mov ax, number
	    cmp ax, cx
	    je emptyFile
	    pop cx
	    pop ax
	    fseek 0, 0, destinationID
	    println startOutput                         ; ��������� ���������� ������ ����� ������ ����� - ����� ��� �������
	    fseek 2, 1, sourceID            ; ��� �����, �.�. ���� �������, �� ����� ������ 2 � bx, �.�. �� ������� � ������ ������ ������ ������
	    call readSymbolFromFile
	    cmp buf, returnSymbol
	    je decBx
	    cmp buf, newLineSymbol
	    je decBx
	    jmp writeLoop 
	    
	decBx:                               ; ��� ��������, ��� �� ������� �� �����, �� ������ ������, � ������ ������� ����� �����
	    sub bx, 2
	    pop si
	    jmp stringLoop

    writeLoop:                           ; ��� �� ������� array_positions � �������� �������, ������ ������� ������ ��������� ������, ���������, ������ � �������
	    sub bx, 2
	    push ax
	    xor ax, ax
	    add ax, 65534                      ; ��� ����� ���������� ��� ��������� 2 � bx=0
	    cmp bx, ax
	    je endWriteLoop 	             ; ��������� ��������� BX ������ ���� 0, ����� ������� � ������ ������ ����
	    pop ax

	    push si
	    mov si, array_positions[bx]
	    fseek 0, si, sourceID            
	    pop si

    stringLoop:
	    call readSymbolFromFile
	    cmp buf, endl
	    je endStringLoop
	    cmp buf, newLineSymbol
	    je endStringLoop
	
	    push ax
	    push bx
	    push cx
	    push dx
	
	    mov ah, 40h                       ; ������ � outputFile ���������� ������� ������, ������������ �� �����
	    lea dx, buf
	    mov bx, destinationID
	    mov cx, 1
	    int 21h 
	
	    pop dx
	    pop cx
	    pop bx
	    pop ax 
	    jmp stringLoop
	
    endStringLoop:
	    push ax
	    push bx
	    push cx
	    push dx
	
	    lea dx, string
	    mov ah, 40h
	    mov bx, destinationID
	    mov cx, 2
	    int 21h
	
	    pop dx
	    pop cx
	    pop bx
	    pop ax
	    jmp WriteLoop
	
	emptyFile:
	    println emptyFileMsg
	
    endWriteLoop: 
        pop ax
        jmp endMain
	ret
endp 
	
readSymbolFromFile proc
        push di
        push bx
        push dx
        push cx
    
        mov ah, 3Fh 		        ; ��������� � ah ��� 3Fh - ��� �-��� ������ �� �����
	    mov bx, sourceID		    ; � bx ��������� ID �����, �� �������� ���������� ���������
	    mov cx, 1			        ; � cx ��������� ���������� ����������� ��������
	    lea dx, buf			        ; � dx ��������� �������� �������, � ������� ����� ��������� ������ �� �����
	    int 21h 			        ; �������� ���������� ��� ���������� �-���
	
	    jnb successfullyRead	    ; ���� ������ �� ����� ������� �� ��������� - ������� � goodRead
	
	    println errorReadSourceText	; ����� ������� ��������� �� ������ ������ �� �����
	    mov ax, 0			
	    
    successfullyRead:
        pop cx
	    pop dx			       
	    pop bx 
	    pop di				      
	ret	   
endp
	
parseCMD proc
        xor ax, ax
        xor cx, cx
    
        cmp cmd_size, 0		        ; ���� �������� �� ��� �������, �� ��������� � notFound 
        je notFound
    
        mov cl, cmd_size
    
        lea di, cmd_text
        mov al, cmd_size
        add di, ax
        dec di
    
    findPoint:			            ; ���� ����� � ����� �����, �.�. ����� �� ���� ��c������� �����
        mov al, '.'
        mov bl, [di]
        cmp al, bl
        je pointFound
        dec di
        loop findPoint
    
    notFound:			            ; ���� ����� �� ������� ������� badCMDArgsMessage � ��������� ���������
        println badCMDArgsMessage
        mov ax, 1
    ret
    
    pointFound: 		            ; ���������� �������� ������ ���� ����� 3, �.�. "txt", ���� ������� �� ����� => ���� �� ��������
        mov al, cmd_size
        sub ax, cx
        cmp ax, 3  
        jne notFound    
    
        xor ax, ax
        lea di, cmd_text
        lea si, extension
        add di, cx
    
        mov cx, 3
    
        repe cmpsb			        ; ���������� �� ������� Extension ���������� �����, ���� �� ������� - �������� ����� ����� � sourcePath 
        jne notFound
    
        strcpy sourcePath, cmd_text, cmd_size
        mov ax, 0
    ret 	
endp 
	 

openFiles proc		     
	    push bx 		    
	    push dx 			       
	    push si 				    
				 
	    mov ah, 3Dh				        ; ������� 3Dh - ������� ������������ ����
	    mov al, 02h				        ; 100 - ���������� ���
	    lea dx, sourcePath	            ; ��������� � dx �������� ��������� ����� 
	    int 21h 		    
			      
	    jb badOpenSource		        ; ���� ���� �� ��������, �� ������� � badOpenSource
			      
	    mov sourceID, ax		        ; ��������� � sourceId �������� �� ax, ���������� ��� �������� �����
	
	    mov ah, 3Ch				        ; ������� 3Ch - ������� ����
	    xor cx, cx			 
	    lea dx, destinationPath	        ; ��������� � dx �������� ��������� ����� 
	    int 21h
	
	    jb badOpenSource
	
	    mov ah, 3Dh				        ; ������� 3Dh - ������� ������������ ����
	    mov al, 02h				        ; 100 - ���������� ���
	    lea dx, destinationPath	        ; ��������� � dx �������� ��������� ����� 
	    int 21h 		    
	
	    jb badOpenSource 
	
	    mov destinationID, ax
	     
	    mov ax, 0				        ; ��������� � ax 0, �.�. ������ �� ����� ���������� ��������� �� ��������    
	    jmp endOpenProc 		        ; ������� � endOpenProc � ��������� ������� �� ���������
				
    badOpenSource:		    
	    println badSourceText	        ; ������� �������������� ���������
	
	    cmp ax, 02h		                ; ���������� ax � 02h
	    jne errorFound		            ; ���� ax != 02h file error, ������� � errorFound
				
	    println fileNotFoundText        ; ������� ��������� � ���, ��� ���� �� ������  
				
	    jmp errorFound		            ; ������� � errorFound
			       
    errorFound: 		    
	    mov ax, 1
			   
    endOpenProc:
        pop si		 
	    pop dx							   
	    pop bx			
	ret			
endp		

closeFiles proc 		
	    push bx 		    
	    push cx 		    
				
	    xor cx, cx		   
				
	    mov ah, 3Eh		                     ; ��������� � ah ��� 3Eh - ��� �������� �����
	    mov bx, sourceID	                 ; � bx ��������� ID �����, ����������� ��������
	    int 21h 		                     ; �������� ���������� ��� ���������� 
				
	    jnb goodCloseOfSource		         ; ���� ������ ��� �������� �� ���������, ������� � goodCloseOfSource
				
	    println errorClosingSource           ; ����� ������� �������������� ��������� �� ������	     
				  
	    inc cx				  
			
    goodCloseOfSource:		
	    mov ax, cx			                 ; ���������� � ax �������� �� cx, ���� ������ �� ���������, �� ��� ����� 0, ����� 1 ��� 2, � ����������� ��
				                             ; ���������� ������������� ������
	    pop cx			    
	    pop bx			                     ; ��������������� �������� ��������� � ������� �� ���������
	ret			    
endp 

end