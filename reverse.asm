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

println macro info	    ;вывод на экран заданной строки
	push ax 		
	push dx 		
			    
	mov ah, 09h		    ; Команда вывода 
	lea dx, info		; Загрузка в dx смещения выводимого сообщения
	int 21h 		    ; Вызов прервывания для выполнения вывода
			    
	mov dl, 0Ah		    ; Символ перехода на новую строку
	mov ah, 02h		    ; Команда вывода символа
	int 21h 		    ; Вызов прерывания
			    
	mov dl, 0Dh		    ; Символ перехода в начало строки   
	mov ah, 02h		
	int 21h 		     
			    
	pop dx			
	pop ax			
endm

strcpy macro destination, source, count   ; Макрос, предназначенный для копирования из source в destination заданное количество символов
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

fseek macro symbolsInt, symbols, ID   ; перемещение курсора(позиции) в файле 
	push ax 		    
	push bx 		    
	push cx 		    
	push dx 		                  ; Сохраняем значения регистров
				
	mov ah, 42h		                  ; Записываем в ah код 42h - ф-ция DOS уставноки указателя файла 
	mov bx, ID                        ; Дескриптор файла
	xor al ,al				  
	mov al, symbolsInt	              ; al - с начала, с конца или с текущей позиции
	mov cx, 0		                  ; Обнуляем cx 
	mov dx, symbols 		          ; Обнуляем dx, т.е премещаем указатель на 0 символов от начала файла (cx*2^16)+dx 
	int 21h 		                  ; Вызываем прерывания DOS для исполнения кодманды	
				
	pop dx			                  ; Восстанавливаем значения регистров и выходим из процедуры
	pop cx			   
	pop bx			    
	pop ax			    
endm

    Main:
	    mov ax, @data		    ; Загружаем данные
	    mov es, ax		
			    
	    xor ch, ch	
	    mov cl, ds:[80h]		; Количество символов строки, переданной через командную строку
	    mov bl, cl
	    mov cmd_size, cl		; В cmd_size загружаем длину командной строки
	    dec bl			        ; Уменьшаем значение количества символов в строке на 1, т.к. первый символ пробел
	    mov si, 81h		        ; Смещение на параметр, переданный через командную строки
	    lea di, tempSourcePath	      
	
	    rep movsb		        ; Записать в ячейку адресом ES:DI байт из ячейки DS:SI
	
	    mov ds, ax		        ; Загружаем в ds данные  
	    mov cmd_size, bl	
	
        mov cl, bl
	    lea di, cmd_text
	    lea si, tempSourcePath
	    inc si
	    rep movsb
				
	    println startText	    ; Вывод строки о начале работы программы
			    
	    call parseCMD		    ; Вызов процедуры парсинга командной строки
	    cmp ax, 0		
	    jne endMain				; Если ax != 0, т.е. при выполении процедуры произошла ошибка - завершаем программу   
	
	    call openFiles		    ; Вызываем процедуру, которая открывает файл, переданный через командную строку
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
	    fseek 0, 0, sourceID            ; Перемещение указателя в начало исходного файла
	    xor cx, cx
	    mov cx, max_length

	    mov array_positions[bx], 0      ; Первая строка всегда начинается с позиции 0
	    add bx, 2                       ; Прибавляем 2, т.к. array_positions состоит из слов 
    
	findStartsOfStrings:                ; Здесь идет запись в массив позиций начала новых строк и проверка на файл с пустыми строками(из пробелов)
	    call readSymbolFromFile
	    add number, 1                   ; Счетчик позиций для записи в массив
	    cmp buf, spaceSymbol
	    je checkSpaces
	    cmp buf, tabulation
	    je checkSpaces
	    cmp buf, newLineSymbol
	    je checkSpaces                   ; В EOF сравним количество пробелов и number, а в number считаются все символы 
	    cmp buf, returnSymbol
	    je addToArray 
	    cmp buf, endl
	    je EOF
	    jmp findStartsOfStrings
	    
	checkSpaces:
	    add spaces, 1
	    jmp findStartsOfStrings
	
	addToArray:                          ; В EOF сравним количество пробелов и number, а в number считаются все символы
	    add spaces, 1 
	    push ax 
	    xor ax, ax 
	    ;add number, 1
	    ;dec ax
	    mov ax, number
	    ;dec ax                   ; Здесь в ax находится позиция первой буквы в новой строке
	    mov array_positions[bx], ax      ; Нумерация с 0
	    add bx, 2
	    ;sub number, 1                    ; Если позиция будет словом, то на 2 надо смещаться каждый раз, а не на 1
	    pop ax 
	    jmp findStartsOfStrings
	
	EOF: 
	    cmp number, 1                    ; Если сразу считали конец файла, то файл пустой
	    je emptyFile
	    add spaces, 1                    ; Для проверки пробелов: мы считали 0Dh, 0Ah, а 0 - конец файла - не считали, поэтому добавим его
	    push ax                          ; Т.к. cmp spaces, number делать нельзя, делаем замороченно
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
	    println startOutput                         ; Проверяем предыдущий символ перед концом файла - буква или каретка
	    fseek 2, 1, sourceID            ; Это важно, т.к. если каретка, то нужно отнять 2 у bx, т.к. мы занесли в массив лишнее начало строки
	    call readSymbolFromFile
	    cmp buf, returnSymbol
	    je decBx
	    cmp buf, newLineSymbol
	    je decBx
	    jmp writeLoop 
	    
	decBx:                               ; Для проверки, был ли переход на новую, но пустую строку, в начале которой конец файла
	    sub bx, 2
	    pop si
	    jmp stringLoop

    writeLoop:                           ; Идём по массиву array_positions в обратном порядке, читаем позицию начала очередной строки, смещаемся, читаем и выводим
	    sub bx, 2
	    push ax
	    xor ax, ax
	    add ax, 65534                      ; Это число получается при отнимании 2 у bx=0
	    cmp bx, ax
	    je endWriteLoop 	             ; Последним значением BX должно быть 0, чтобы вывести и первую строку тоже
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
	
	    mov ah, 40h                       ; Запись в outputFile очередного символа строки, прочитанного из файла
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
    
        mov ah, 3Fh 		        ; Загружаем в ah код 3Fh - код ф-ции чтения из файла
	    mov bx, sourceID		    ; В bx загружаем ID файла, из которого собираемся считывать
	    mov cx, 1			        ; В cx загружаем количество считываемых символов
	    lea dx, buf			        ; В dx загружаем смещения буффера, в который будет считывать данные из файла
	    int 21h 			        ; Вызываем прерывание для выполнения ф-ции
	
	    jnb successfullyRead	    ; Если ошибок во время счтения не произошло - прыгаем в goodRead
	
	    println errorReadSourceText	; Иначе выводим сообщение об ошибке чтения из файла
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
    
        cmp cmd_size, 0		        ; Если параметр не был передан, то переходим в notFound 
        je notFound
    
        mov cl, cmd_size
    
        lea di, cmd_text
        mov al, cmd_size
        add di, ax
        dec di
    
    findPoint:			            ; Ищем точку с конца файла, т.к. после неё идет раcширение файла
        mov al, '.'
        mov bl, [di]
        cmp al, bl
        je pointFound
        dec di
        loop findPoint
    
    notFound:			            ; Если точка не найдена выводим badCMDArgsMessage и завершаем программу
        println badCMDArgsMessage
        mov ax, 1
    ret
    
    pointFound: 		            ; Количество символов должно быть равно 3, т.к. "txt", если отлично от этого => файл не подходит
        mov al, cmd_size
        sub ax, cx
        cmp ax, 3  
        jne notFound    
    
        xor ax, ax
        lea di, cmd_text
        lea si, extension
        add di, cx
    
        mov cx, 3
    
        repe cmpsb			        ; Сравниваем со строкой Extension расширение файла, если всё совпало - копируем адрес файла в sourcePath 
        jne notFound
    
        strcpy sourcePath, cmd_text, cmd_size
        mov ax, 0
    ret 	
endp 
	 

openFiles proc		     
	    push bx 		    
	    push dx 			       
	    push si 				    
				 
	    mov ah, 3Dh				        ; Функция 3Dh - открыть существующий файл
	    mov al, 02h				        ; 100 - запрещений нет
	    lea dx, sourcePath	            ; Загружаем в dx название исходного файла 
	    int 21h 		    
			      
	    jb badOpenSource		        ; Если файл не открылся, то прыгаем в badOpenSource
			      
	    mov sourceID, ax		        ; Загружаем в sourceId значение из ax, полученное при открытии файла
	
	    mov ah, 3Ch				        ; Функция 3Ch - создать файл
	    xor cx, cx			 
	    lea dx, destinationPath	        ; Загружаем в dx название исходного файла 
	    int 21h
	
	    jb badOpenSource
	
	    mov ah, 3Dh				        ; Функция 3Dh - открыть существующий файл
	    mov al, 02h				        ; 100 - запрещений нет
	    lea dx, destinationPath	        ; Загружаем в dx название исходного файла 
	    int 21h 		    
	
	    jb badOpenSource 
	
	    mov destinationID, ax
	     
	    mov ax, 0				        ; Загружаем в ax 0, т.е. ошибок во время выполнения процедуры не произшло    
	    jmp endOpenProc 		        ; Прыгаем в endOpenProc и корректно выходим из процедуры
				
    badOpenSource:		    
	    println badSourceText	        ; Выводим соответсвующее сообщение
	
	    cmp ax, 02h		                ; Сравниваем ax с 02h
	    jne errorFound		            ; Если ax != 02h file error, прыгаем в errorFound
				
	    println fileNotFoundText        ; Выводим сообщение о том, что файл не найден  
				
	    jmp errorFound		            ; Прыгаем в errorFound
			       
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
				
	    mov ah, 3Eh		                     ; Загружаем в ah код 3Eh - код закрытия файла
	    mov bx, sourceID	                 ; В bx загружаем ID файла, подлежащего закрытию
	    int 21h 		                     ; Выпоняем прерывание для выполнения 
				
	    jnb goodCloseOfSource		         ; Если ошибок при закрытии не произошло, прыгаем в goodCloseOfSource
				
	    println errorClosingSource           ; Иначе выводим соответсвующее сообщение об ошибке	     
				  
	    inc cx				  
			
    goodCloseOfSource:		
	    mov ax, cx			                 ; Записываем в ax значение из cx, если ошибок не произошло, то это будет 0, иначе 1 или 2, в зависимости от
				                             ; количества незакрывшихся файлов
	    pop cx			    
	    pop bx			                     ; Восстанавливаем значения регистров и выходим из процедуры
	ret			    
endp 

end