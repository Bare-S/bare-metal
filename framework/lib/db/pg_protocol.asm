default rel
%include "logger.inc"
extern tcp_send, tcp_recv
extern strlen, memcpy
extern scram_build_client_first, scram_parse_server_first, scram_build_client_final
; Буферы из scram.asm
extern scram_client_first_msg
extern scram_client_final_msg
extern scram_server_first

section .bss
    pg_recv_buffer resb 4096           ; буфер для приема данных от сервера
    pg_send_buffer resb 1024           ; буфер для отправки данных на сервер

section .data
pg_start_msg:
    db 0x00, 0x00, 0x00, 0x25          ; длина сообщения (37 bytes, big-endian)
    db 0x00, 0x03, 0x00, 0x00          ; версия протокола (3.0)
    db "user", 0
    db "legors", 0                     ; Имя пользователя БД
    db "database", 0
    db "legors", 0                     ; Имя БД
    db 0
    pgstart_msg_len equ $ - pg_start_msg

scram_mechanism:
    db "SCRAM-SHA-256", 0
    scram_mechanism_len equ $ - scram_mechanism - 1

pg_ok_msg:
    db "Startup message sent successfully", 0
pg_auth_ok_msg:
    db "PostgreSQL SCRAM-SHA-256 authentication successful", 0
pg_error_msg:
    db "Failed to send startup message or receive response", 0
pg_auth_error_msg:
    db "PostgreSQL SCRAM-SHA-256 authentication failed", 0
pg_auth_step_msg:
    db "Auth step completed", 0

section .text
global pg_send_startup, pg_authenticate

; ===========================================================================================
; pg_send_startup — отправляет Startup Message и получает ответ
; (rdi = socket fd) => (rax = fd при успехе, -1 при ошибке)
; ===========================================================================================
pg_send_startup:
    push rsi
    push rdx
    push rbx

    mov rbx, rdi                       ; rbx = fd

; Отправляем startup message
    mov rdi, rbx
    lea rsi, [pg_start_msg]
    mov rdx, pgstart_msg_len
    call tcp_send
    cmp rax, 0
    jl .startup_error

; Получаем ответ
    mov rdi, rbx
    lea rsi, [pg_recv_buffer]
    mov rdx, 4096
    call tcp_recv
    cmp rax, 0
    jl .startup_error

; Проверяем что ответ начинается с 'R' (Authentication Request)
    cmp byte [pg_recv_buffer], 'R'
    jne .startup_error

    LOG_DB pg_ok_msg
    mov rax, rbx                       ; возвращаем fd
    pop rbx
    pop rdx
    pop rsi
    ret

.startup_error:
    LOG_ERROR pg_error_msg
    mov rax, -1
    pop rbx
    pop rdx
    pop rsi
    ret

; ===========================================================================================
; pg_authenticate — SCRAM-SHA-256 аутентификация
; Предполагает что pg_send_startup уже вызван и ответ в pg_recv_buffer

; SCRAM flow:
; 1. Клиент → SASLInitialResponse (mechanism + client-first-message)
; 2. Сервер → AuthenticationSASLContinue (server-first-message)
; 3. Клиент → SASLResponse (client-final-message с proof)
; 4. Сервер → AuthenticationSASLFinal + AuthenticationOk

; (rdi = socket fd) => (rax = fd при успехе, -1 при ошибке)
; ===========================================================================================
pg_authenticate:
    push rsi
    push rbx
    push rcx
    push rdx
    push r12
    push r13
    push r14

    mov rbx, rdi                       ; rbx = fd

; ======================== STEP 1: SASLInitialResponse ========================

; Собираем client-first-message
    call scram_build_client_first

; Получаем длину client-first-message
    lea rdi, [scram_client_first_msg]
    call strlen
    mov r12, rax                       ; r12 = cfm_len

; Собираем SASLInitialResponse пакет в pg_send_buffer:
; 'p'(1) + len(4) + mechanism\0(14) + cfm_len(4) + cfm
    lea rdi, [pg_send_buffer]
    mov byte [rdi], 'p'                ; тип сообщения

; Длина = 4 + mechanism_len + 1(\0) + 4(cfm_len) + cfm_len
    mov eax, 4
    add eax, scram_mechanism_len
    inc eax                            ; +1 за \0 после mechanism
    add eax, 4                         ; +4 за поле длины cfm
    add eax, r12d                      ; + cfm_len
    bswap eax                          ; в big-endian
    mov dword [rdi + 1], eax

; Копируем mechanism + \0
    lea rdi, [pg_send_buffer + 5]
    lea rsi, [scram_mechanism]
    mov rdx, scram_mechanism_len
    call memcpy
    lea rdi, [pg_send_buffer]
    mov byte [rdi + 5 + scram_mechanism_len], 0

; Длина client-first-message (4 bytes big-endian)
    mov eax, r12d
    bswap eax
    mov r13, 5 + scram_mechanism_len + 1
    lea rdi, [pg_send_buffer]
    mov dword [rdi + r13], eax

; Копируем client-first-message
    add r13, 4
    lea rdi, [pg_send_buffer]
    add rdi, r13
    lea rsi, [scram_client_first_msg]
    mov rdx, r12
    call memcpy

; Вычисляем полный размер пакета для отправки
; 1('p') + 4(len) + mechanism_len + 1(\0) + 4(cfm_len) + cfm_len
    mov r14, 1
    add r14, 4
    add r14, scram_mechanism_len
    inc r14
    add r14, 4
    add r14, r12

; Отправляем
    mov rdi, rbx
    lea rsi, [pg_send_buffer]
    mov rdx, r14
    call tcp_send
    cmp rax, 0
    jl .scram_error

    LOG_DB pg_auth_step_msg

; ======================== STEP 2: Получаем server-first-message ========================

    mov rdi, rbx
    lea rsi, [pg_recv_buffer]
    mov rdx, 4096
    call tcp_recv
    cmp rax, 0
    jl .scram_error

; Проверяем тип ответа
    cmp byte [pg_recv_buffer], 'R'
    jne .scram_error

; Извлекаем server-first-message
; Формат: 'R'(1) + len(4) + auth_type(4) + payload
; auth_type = 11 для AuthenticationSASLContinue
; Длина payload = len - 4(len поле) - 4(auth_type) = len - 8
    mov eax, dword [pg_recv_buffer + 1]
    bswap eax                          ; длина (включает себя)
    sub eax, 8                         ; длина payload
    mov r14, rax

; Копируем server-first-message и добавляем \0
    lea rdi, [scram_server_first]
    lea rsi, [pg_recv_buffer + 9]
    mov rdx, r14
    call memcpy
    lea rdi, [scram_server_first]
    mov byte [rdi + r14], 0

; Парсим: извлекаем nonce, salt, iterations
    lea rdi, [scram_server_first]
    call scram_parse_server_first

    LOG_DB pg_auth_step_msg

; ======================== STEP 3: Вычисляем proof и отправляем ========================

; Собираем client-final-message (с proof)
    call scram_build_client_final

; Получаем длину client-final-message
    lea rdi, [scram_client_final_msg]
    call strlen
    mov r12, rax

; Собираем SASLResponse пакет: 'p'(1) + len(4) + data
    lea rdi, [pg_send_buffer]
    mov byte [rdi], 'p'                ; тип сообщения

    mov eax, r12d
    add eax, 4                         ; len включает себя
    bswap eax
    mov dword [rdi + 1], eax

; Копируем client-final-message
    lea rdi, [pg_send_buffer + 5]
    lea rsi, [scram_client_final_msg]
    mov rdx, r12
    call memcpy

; Полный размер = 1('p') + 4(len) + cfinal_len
    mov r14, r12
    add r14, 5

; Отправляем
    mov rdi, rbx
    lea rsi, [pg_send_buffer]
    mov rdx, r14
    call tcp_send
    cmp rax, 0
    jl .scram_error

    LOG_DB pg_auth_step_msg

; ======================== STEP 4: Проверяем AuthenticationOk ========================

    mov rdi, rbx
    lea rsi, [pg_recv_buffer]
    mov rdx, 4096
    call tcp_recv
    cmp rax, 0
    jl .scram_error

; PostgreSQL отправляет два сообщения в одном TCP-пакете:
; 1. AuthenticationSASLFinal ('R' + len + auth_type=12 + server-signature)
; 2. AuthenticationOk ('R' + len + auth_type=0)
; Нужно пропустить первое и проверить второе

; Проверяем первое сообщение
    cmp byte [pg_recv_buffer], 'R'
    jne .scram_error

; Вычисляем смещение до второго сообщения
; смещение = 1(тип) + len (из поля длины)
    mov eax, dword [pg_recv_buffer + 1]
    bswap eax                          ; длина первого сообщения (без типа)
    lea r12, [rax + 1]                 ; +1 за байт типа 'R'

; Проверяем второе сообщение — AuthenticationOk
    cmp byte [pg_recv_buffer + r12], 'R'
    jne .scram_error

; auth_type должен быть 0 (AuthenticationOk)
    cmp dword [pg_recv_buffer + r12 + 5], 0
    jne .scram_error

    LOG_DB pg_auth_ok_msg
    mov rax, rbx                       ; возвращаем fd
    pop r14
    pop r13
    pop r12
    pop rdx
    pop rcx
    pop rbx
    pop rsi
    ret

.scram_error:
    LOG_ERROR pg_auth_error_msg
    mov rax, -1
    pop r14
    pop r13
    pop r12
    pop rdx
    pop rcx
    pop rbx
    pop rsi
    ret
