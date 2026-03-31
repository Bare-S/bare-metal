default rel

section .data
; ===================================================================================
HTTP_RESPONSE_OK:
    db "HTTP/1.1 200 OK", 13, 10
HTTP_RESPONSE_OK_LEN:
    dq $ - HTTP_RESPONSE_OK

HTTP_RESPONSE_CREATED:
    db "HTTP/1.1 201 Created", 13, 10
HTTP_RESPONSE_CREATED_LEN:
    dq $ - HTTP_RESPONSE_CREATED

HTTP_RESPONSE_BAD_REQUEST:
    db "HTTP/1.1 400 Bad Request", 13, 10
HTTP_RESPONSE_BAD_REQUEST_LEN:
    dq $ - HTTP_RESPONSE_BAD_REQUEST

HTTP_RESPONSE_NOT_FOUND:
    db "HTTP/1.1 404 Not Found", 13, 10
HTTP_RESPONSE_NOT_FOUND_LEN:
    dq $ - HTTP_RESPONSE_NOT_FOUND

HTTP_RESPONSE_INTERNAL_ERROR:
    db "HTTP/1.1 500 Internal Server Error", 13, 10
HTTP_RESPONSE_INTERNAL_ERROR_LEN:
    dq $ - HTTP_RESPONSE_INTERNAL_ERROR
; ===================================================================================
CONTENT_TYPE_JSON:
    db "Content-Type: application/json", 13, 10
CONTENT_TYPE_JSON_LEN:
    dq $ - CONTENT_TYPE_JSON

CONTENT_TYPE_TEXT:
    db "Content-Type: text/plain", 13, 10
CONTENT_TYPE_TEXT_LEN:
    dq $ - CONTENT_TYPE_TEXT

CONTENT_TYPE_HTML:
    db "Content-Type: text/html", 13, 10
CONTENT_TYPE_HTML_LEN:
    dq $ - CONTENT_TYPE_HTML
; ===================================================================================
CONTENT_LENGTH:
    db "Content-Length: "
    CONTENT_LENGTH_LEN equ $ - CONTENT_LENGTH
; ===================================================================================
END_OF_HEADERS:
    db 13, 10
    END_OF_HEADERS_LEN equ $ - END_OF_HEADERS
; ===================================================================================
CONNECTION_CLOSE:
    db "Connection: close", 13, 10
    CONNECTION_CLOSE_LEN equ $ - CONNECTION_CLOSE
; ===================================================================================

; ===================================================================================
global HTTP_RESPONSE_OK
global HTTP_RESPONSE_CREATED_LEN

global HTTP_RESPONSE_CREATED
global HTTP_RESPONSE_OK_LEN

global HTTP_RESPONSE_BAD_REQUEST
global HTTP_RESPONSE_BAD_REQUEST_LEN

global HTTP_RESPONSE_NOT_FOUND
global HTTP_RESPONSE_NOT_FOUND_LEN

global HTTP_RESPONSE_INTERNAL_ERROR
global HTTP_RESPONSE_INTERNAL_ERROR_LEN

; ===================================================================================
global CONTENT_TYPE_JSON
global CONTENT_TYPE_JSON_LEN

global CONTENT_TYPE_TEXT
global CONTENT_TYPE_TEXT_LEN

global CONTENT_TYPE_HTML
global CONTENT_TYPE_HTML_LEN

; ===================================================================================
section .bss
    number_buffer resb 20              ; Буфер для конвертации числа в строку
    main_buffer resb 32768             ; Буфер для формирования ответа 32Кб

section .text
global send_response

extern strlen, strcpy, itoa, sys_write

; (rdi: fd клиента, rsi: указатель на JSON тело, rdx: указатель на сатус, rcx: длина статуса, r8: указатель на тип контента, r9: длина типа контента) => void
send_response:
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    push rbx

    mov r10, rdi                       ; Сохранение fd клиента в r10
    mov r11, rsi                       ; Сохранение указателя на JSON тело в r11
    mov r15, rcx                       ; Сохранение длины статуса ответа в r15
    mov rbx, r8                        ; Сохранение указателя на тип контента в rbx
    push r9                            ; Сохранение длины типа контента на стеке, так как r9 будет использоваться для itoa
    push rdx                           ; Сохранение указателя на статус ответа на стеке, так как rdx будет использоваться для strcpy
    xor r13, r13

    mov rdi, r11                       ; Установка rdi на указатель на JSON тело для strlen
    call strlen                        ; Получение длины JSON тела в rax
    mov r12, rax                       ; Сохранение длины JSON тела в r12

    mov rdi, r12                       ; Установка rdi на длину JSON тела для itoa
    lea rsi, [number_buffer]           ; Установка rsi на буфер для itoa
    call itoa                          ; Конвертация длины JSON тела в строку, результат в rax
    mov r14, rax                       ; Сохранение длины строки с числом в r14

    lea rdi, [main_buffer]             ; Установка rdi на буфер для формирования ответа
    add rdi, r13                       ; Смещение для записи в main_buffer
    pop rdx                            ; Восстановление указателя на статус ответа
    mov rsi, rdx                       ; Установка rsi на строку статуса ответа
    call strcpy                        ; Копирование строки статуса ответа в main_buffer
    add r13, r15                       ; Увеличение смещения на длину строки статуса ответа

    lea rdi, [main_buffer]
    add rdi, r13
    pop r9                             ; Восстановление длины типа контента в r9
    mov rsi, rbx
    call strcpy
    add r13, r9

    lea rdi, [main_buffer]
    add rdi, r13
    lea rsi, [CONTENT_LENGTH]
    call strcpy
    add r13, CONTENT_LENGTH_LEN

    lea rdi, [main_buffer]
    add rdi, r13
    lea rsi, [number_buffer]
    call strcpy
    add r13, r14

    lea rdi, [main_buffer]
    add rdi, r13
    lea rsi, [END_OF_HEADERS]
    call strcpy
    add r13, END_OF_HEADERS_LEN

    lea rdi, [main_buffer]
    add rdi, r13
    lea rsi, [CONNECTION_CLOSE]
    call strcpy
    add r13, CONNECTION_CLOSE_LEN

    lea rdi, [main_buffer]
    add rdi, r13
    lea rsi, [END_OF_HEADERS]
    call strcpy
    add r13, END_OF_HEADERS_LEN

    lea rdi, [main_buffer]
    add rdi, r13
    mov rsi, r11                       ; r11 уже с адрессом, поэтому mov
    call strcpy
    add r13, r12

    mov rdi, r10                       ; Установка rdi на fd клиента для sys_write
    lea rsi, [main_buffer]             ; Установка rsi на буфер с сформированным ответом
    mov rdx, r13                       ; Установка rdx на общую длину сформированного ответа
    call sys_write                     ; Отправка ответа клиенту

    pop rbx
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
; Отправляем сформированный ответ клиенту

    ret
