default rel
%include "logger.inc"

section .data

msg_start:
    db "Starting backend server...", 0

err_socket:
    db "Failed to create socket", 0
err_setsockopt:
    db "Failed to set socket options", 0
err_bind:
    db "Failed to bind socket", 0
err_listen:
    db "Failed to listen", 0
err_accept:
    db "Failed to accept connection", 0
err_read:
    db "Failed to read from client", 0

opt_val:
    dd 1                               ; Значение для опции (включить)

section .bss
global envp_ptr
global request_buffer
    envp_ptr resq 1                    ; Указатель на envp для передачи в функции обработки запросов
    request_buffer resb 32768          ; Буфер для хранения входящих данных от клиента 32Кб

section .text
extern sys_socket, sys_bind, sys_listen, sys_accept, sys_write, sys_close, sys_setsockopt, sys_read, sys_exit
extern parse_http_request
extern route_request
extern handler_not_found

global server_init
global server_run

; ===========================================================================================
; server_init — парсит envp из стека
; Вызывать из _start перед server_run
; (rdi = указатель на rsp в момент _start)
; ===========================================================================================
server_init:
    mov rax, [rdi]                     ; argc
    lea rbx, [rdi + 8]                 ; argv

    inc rax                            ; пропускаем имя программы
    shl rax, 3                         ; умножаем индекс на 8 (размер указателя) для получения адреса аргумента
    add rbx, rax                       ; rbx = указатель на envp

    mov [envp_ptr], rbx
    ret

; ===========================================================================================
; server_run — создает сокет, слушает порт и запускает event loop
; (rdi = указатель на sockaddr_in структуру (порт + адрес), rsi = указатель на таблицу маршрутов)
; Не возвращает управление (бесконечный цикл)
; ===========================================================================================
server_run:
    push r12
    push r13
    push rbp
    push rbx

    mov rbp, rsi                       ; rbp = указатель на таблицу маршрутов (callee-saved)

; -------------------------------------------------------------------------------------------------------------------------------
; Создание сокета, установка опций, связывание с портом и начало прослушивания
; -------------------------------------------------------------------------------------------------------------------------------
    push rdi                           ; Сохраняем sockaddr_in

    mov rdi, 2                         ; IPV4
    mov rsi, 1                         ; Протокол TCP
    mov rdx, 0                         ; Авто настройка от linux
    call sys_socket
    lea r15, [err_socket]
    cmp rax, 0
    jl .exit_err

    mov r12, rax                       ; сохраним файловый дескриптор сокета в r12

    mov rdi, r12
    mov rsi, 1                         ; Уровень SOL_SOCKET
    mov rdx, 2                         ; Опция SO_REUSEADDR
    lea rcx, [opt_val]
    mov r8, 4
    call sys_setsockopt
    lea r15, [err_setsockopt]
    cmp rax, 0
    jl .exit_err

; -------------------------------------------------------------------------------------------------------------------------------
; Связывание сокета с портом и адресом
; -------------------------------------------------------------------------------------------------------------------------------
    pop rsi                            ; Восстанавливаем sockaddr_in
    mov rdi, r12
    mov rdx, 16
    call sys_bind
    lea r15, [err_bind]
    cmp rax, 0
    jl .exit_err

    mov rdi, r12
    mov rsi, 128                       ; Максимальная длина очереди
    call sys_listen
    lea r15, [err_listen]
    cmp rax, 0
    jl .exit_err

    LOG_INFO msg_start

.loop:
    mov rdi, r12
    xor rsi, rsi
    xor rdx, rdx
    call sys_accept
    cmp rax, 0
    jl .accept_err

    mov r13, rax                       ; дескриптор клиента в r13

    mov rdi, r13
    lea rsi, [request_buffer]
    mov rdx, 32768
    call sys_read
    cmp rax, 0
    jl .read_err

    mov rbx, rax                       ; сохраняем количество прочитанных байт

    lea rdi, [request_buffer]
    call parse_http_request

    mov r14, rax                       ; указатель на метод
    mov r15, rdx                       ; указатель на путь

    mov rdi, r14
    mov rsi, r15
    mov rdx, r13                       ; дескриптор клиента
    mov rcx, rbx                       ; количество прочитанных байт
    mov r8, rbp                        ; указатель на таблицу маршрутов
    call route_request
    cmp rax, -1
    je .not_found
    jmp .close

.not_found:
    mov rdi, r13
    call handler_not_found

.close:
    mov rdi, r13
    call sys_close
    jmp .loop

.accept_err:
    LOG_ERROR err_accept
    jmp .loop

.read_err:
    LOG_ERROR err_read
    jmp .close

.exit_err:
    LOG_ERROR r15
    mov rdi, 1
    call sys_exit
