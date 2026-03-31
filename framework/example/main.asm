default rel

section .data

sockaddr_in:
    dw 2                               ; IPV4
    dw 0x901F                          ; Порт 8080
    dd 0                               ; 0.0.0.0
    dq 0                               ; padding

section .text
extern server_init, server_run
extern route_table

global _start
_start:
    mov rdi, rsp
    call server_init

; Запуск сервера
    lea rdi, [sockaddr_in]             ; адрес и порт
    lea rsi, [route_table]             ; таблица маршрутов
    call server_run
