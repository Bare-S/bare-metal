default rel
extern sys_socket, sys_connect, sys_read, sys_write, sys_close

%include "logger.inc"

section .data
sockaddr_in:
    dw 2                               ; AF_INET
    dw 0x3715                          ; 5431 в hex
    dd 0x0100007F                      ; 127.0.0.1
    dq 0                               ; padding для выравнивания до 16 байт

tcp_connect_msg:
    db "Connecting to PostgreSQL server", 0
tcp_connect_error_msg:
    db "Failed to connect to PostgreSQL server", 0

section .text
global tcp_connect, tcp_send, tcp_recv

tcp_connect:
    push rdi
    push rsi
    push rdx

    push rbx                           ; файловый деcкриптор сохранён в rbx

    mov rdi, 2                         ; AF_INET
    mov rsi, 1                         ; SOCK_STREAM
    mov rdx, 0                         ; protocol
    call sys_socket                    ; создаём сокет

    cmp rax, 0
    jl .error                          ; если ошибка, то выходим

    mov rbx, rax                       ; сохраняем дескриптор сокета в rbx

    mov rdi, rbx                       ; дескриптор сокета
    lea rsi, [sockaddr_in]             ; указатель на структуру sockaddr_in
    mov rdx, 16                        ; размер структуры sockaddr_in
    call sys_connect                   ; подключаемся к серверу

    cmp rax, 0
    jl .error                          ; если ошибка, то выходим

    mov rax, rbx                       ; возвращаем дескриптор сокета в rax
    pop rbx

    LOG_DB tcp_connect_msg

    pop rdx
    pop rsi
    pop rdi
    ret

.error:
    mov rdi, rbx                       ; сохраняем дескриптор сокета для закрытия
    call sys_close                     ; закрываем сокет
    mov rax, -1                        ; возвращаем 0 в случае ошибки
    pop rbx

    LOG_ERROR tcp_connect_error_msg

    pop rdx
    pop rsi
    pop rdi
    ret

; (rdi - дескриптор сокета, rsi - указатель на буфер данных, rdx - размер данных)
tcp_send:
    call sys_write                     ; отправляем данные
    ret

; (rdi - дескриптор сокета, rsi - указатель на буфер для приёма данных, rdx - размер буфера)
tcp_recv:
    call sys_read                      ; принимаем данные
    ret

