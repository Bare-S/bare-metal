default rel

%include "logger.inc"

extern strncmp

section .data
    ENTRY_COUNT_SIZE equ 2             ; размер счётчика записей
    TYPE_SIZE equ 1                    ; размер поля типа
    KEY_LEN_SIZE equ 2                 ; размер поля длины ключа
    VAL_LEN_SIZE equ 2                 ; размер поля длины значения
    ENTRY_HEADER_SIZE equ 5            ; TYPE_SIZE + KEY_LEN_SIZE + VAL_LEN_SIZE (без самих данных ключа)

start_json_getter:
    db "Starting JSON getter", 0
key_not_found_msg:
    db "Key not found in JSON", 0
key_found_msg:
    db "Key found in JSON", 0

section .text
global json_get

; (rdi: указатель на JSON строку, rsi: ключ) => (rax: указатель на значение или -1 если ключ не найден, rdx: длина значения, rcx: тип)
json_get:
    LOG_JSON start_json_getter
    push rdi
    push rsi

    push rbx
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push rcx
    push rdx

    movzx rbx, word [rdi]              ; первые 2 байта, количество записей
    lea rcx, [rdi + ENTRY_COUNT_SIZE]  ; указатель на первую запись

    mov r13, rsi
.loop:
    cmp rbx, 0
    je .not_found                      ; если записей нет, выходим

    movzx r12, byte [rcx]              ; тип значния
    movzx r8, word [rcx + TYPE_SIZE]   ; длина ключа
    lea r9, [rcx + KEY_LEN_SIZE + TYPE_SIZE] ; указатель на ключ
    lea rax, [rcx + r8]
    movzx r10, word [rax + TYPE_SIZE + KEY_LEN_SIZE] ; длина значения
    lea r11, [rcx + ENTRY_HEADER_SIZE + r8] ; указатель на значение

; сравнение

    mov rdi, r9                        ; ключ из JSON
    mov rsi, r13                       ; ключ для поиска
    mov rdx, r8                        ; длина ключа
    call strncmp                       ; получаем длину ключа для сравнения

    cmp rax, 0                         ; если совпали
    je .found

    add rcx, ENTRY_HEADER_SIZE         ; переходим к следующей записи
    add rcx, r8                        ; пропускаем ключ
    add rcx, r10                       ; пропускаем значение
    dec rbx
    jmp .loop

.found:
    pop rdx
    pop rcx

    mov rax, r11                       ; указатель на значение
    mov rdx, r10                       ; длина значения
    mov rcx, r12                       ; тип значения

    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbx

    pop rsi
    pop rdi
    LOG_JSON key_found_msg
    ret

.not_found:
    pop rdx
    pop rcx

    mov rax, -1                        ; ключ не найден

    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbx

    pop rsi
    pop rdi
    LOG_JSON key_not_found_msg
    ret
