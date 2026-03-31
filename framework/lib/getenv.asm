default rel

%include "logger.inc"

section .data

env_get_succes_msg:
    db "Environment variable found successfully", 0
env_get_error_msg:
    db "Failed to find environment variable", 0

extern envp_ptr
section .text

global getenv

; (rdi = указатель на имя переменной окружения) => (rax = указатель на значение переменной окружения или -1 если переменная не найдена)
getenv:
    push rdi
    push rbx
    push rcx
    push r8
    push r9

    mov rbx, rdi
    mov rdi, [envp_ptr]                ; Получаем указатель на envp

    cmp rdi, 0
    je .not_found                      ; если envp_ptr = NULL
.loop:
    mov rcx, [rdi]
    cmp rcx, 0                         ; Проверяем конец массива envp_ptr
    je .not_found                      ; Если достигнут конец массива, переменная не найдена

    xor r8, r8                         ; Сбросим r8 для подсчета длины строки
.cmp_loop:
    mov r9b, byte [rbx + r8]           ; Загружаем текущий символ
    cmp r9b, 0                         ; Проверяем конец строки
    je .check_eq                       ; Если достигнут конец строки, переходим к следующей перем

    cmp r9b, byte [rcx + r8]           ; Сравниваем символы
    jne .next_env                      ; Если символы не совпадают, переходим к следующей переменной окружения

    inc r8
    jmp .cmp_loop

.check_eq:
    cmp byte [rcx + r8], '='           ; Проверяем, что после имени переменной окружения стоит символ '='
    jne .next_env                      ; Если нет, переходим к следующей переменной окружения

    jmp .found

.next_env:
    add rdi, 8                         ; Переходим к следующему указателю в envp
    jmp .loop

.not_found:
    mov rax, -1                        ; Возвращаем -1, если переменная не найдена
    LOG_ERROR env_get_error_msg
    jmp .done

.found:
    lea rax, [rcx + r8 + 1]            ; Возвращаем указатель на найденную строку
    LOG_ENV env_get_succes_msg
    jmp .done

.done:
    pop r9
    pop r8
    pop rcx
    pop rbx
    pop rdi
    ret
