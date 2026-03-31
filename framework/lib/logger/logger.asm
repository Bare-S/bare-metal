default rel

section .data

PREFIX_INFO:
    db 27, "[32m[INFO] " , 27, "[0m"
    PREFIX_INFO_LEN equ $ - PREFIX_INFO

PREFIX_ERROR:
    db 27, "[31m[ERROR] ", 27, "[0m"
    PREFIX_ERROR_LEN equ $ - PREFIX_ERROR

PREFIX_BACKEND:
    db 27, "[34m[BACKEND] ", 27, "[0m"
    PREFIX_BACKEND_LEN equ $ - PREFIX_BACKEND
PREFIX_JSON:
    db 27, "[33m[JSON] ", 27, "[0m"
    PREFIX_JSON_LEN equ $ - PREFIX_JSON
PREFIX_REQUEST:
    db 27, "[35m[REQUEST] ", 27, "[0m"
    PREFIX_REQUEST_LEN equ $ - PREFIX_REQUEST
PREFIX_DB:
    db 27, "[36m[DB] ", 27, "[0m"
    PREFIX_DB_LEN equ $ - PREFIX_DB
PREFIX_SYSCALL:
    db 27, "[31m[SYSCALL] ", 27, "[0m"
    PREFIX_SYSCALL_LEN equ $ - PREFIX_SYSCALL
PREFIX_ENV:
    db 27, "[38;5;22m[ENV] ", 27, "[0m"
    PREFIX_ENV_LEN equ $ - PREFIX_ENV

NEWLINE:
    db 10
    NEWLINE_LEN equ $ - NEWLINE

section .text
extern sys_write
global PREFIX_INFO, PREFIX_ERROR, PREFIX_JSON, PREFIX_REQUEST, PREFIX_DB, PREFIX_SYSCALL, PREFIX_ENV
; rdi = fd, rsi = сообщение, rdx = длина сообщения, rcx = префикс, r8 = длина префикса
global _print_log
_print_log:
    push rsi
    push rdx
    push rcx
    push r8

    mov rsi, PREFIX_BACKEND
    mov rdx, PREFIX_BACKEND_LEN
    call sys_write

    pop r8
    pop rcx
    mov rsi, rcx
    mov rdx, r8
    call sys_write

    pop rdx
    pop rsi
    call sys_write

    mov rsi, NEWLINE
    mov rdx, NEWLINE_LEN
    call sys_write
    ret
