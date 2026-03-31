default rel

; ===========================================================================================
; Base64 Encode / Decode (RFC 4648)

; Экспорт:
; base64_encode(rdi = input, rsi = len, rdx = output) => rax = output_len
; base64_decode(rdi = input, rsi = len, rdx = output) => rax = output_len
; ===========================================================================================

section .data

; Таблица символов для кодирования: индекс 0-63 → символ
b64_table:
    db "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

; Обратная таблица для декодирования: ASCII код символа → индекс 0-63 (0xFF = невалидный)
b64_decode_table:
    times 43 db 0xFF
    db 62                              ; '+'
    db 0xFF, 0xFF, 0xFF
    db 63                              ; '/'
    db 52, 53, 54, 55, 56, 57, 58, 59, 60, 61
    times 7 db 0xFF
    db 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25
    times 6 db 0xFF
    db 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51
    times 133 db 0xFF

section .text
global base64_encode
global base64_decode

; ===========================================================================================
; base64_encode — кодирует бинарные данные в текстовую строку Base64
; Принцип: берём 3 байта (24 бита), разбиваем на 4 группы по 6 бит,
; каждую группу превращаем в символ из b64_table
; Если на входе не кратно 3 — дополняем символами '='
; (rdi = input, rsi = len, rdx = output) => rax = output_len
; ===========================================================================================
base64_encode:
    push rbx
    push rcx
    push rdx
    push r8
    push r9
    push r10

    mov r8, rdi                        ; input
    mov r9, rsi                        ; len
    mov r10, rdx                       ; output
    xor rbx, rbx                       ; индекс чтения (вход)
    xor rcx, rcx                       ; индекс записи (выход)

.b64e_loop:
    cmp rbx, r9
    jae .b64e_done

; Собираем 3 байта в один 24-битный блок (eax)
    movzx eax, byte [r8 + rbx]
    shl eax, 16                        ; первый байт → биты 16-23
    inc rbx
    cmp rbx, r9
    jae .b64e_2byte                    ; только 1 байт — дополняем ==

    movzx edx, byte [r8 + rbx]
    shl edx, 8                         ; второй байт → биты 8-15
    or eax, edx
    inc rbx
    cmp rbx, r9
    jae .b64e_1byte                    ; только 2 байта — дополняем =

    movzx edx, byte [r8 + rbx]         ; третий байт → биты 0-7
    or eax, edx
    inc rbx

; Разбиваем 24 бита на 4 группы по 6 бит → 4 символа из таблицы
    lea rdi, [b64_table]
    mov edx, eax
    shr edx, 18
    and edx, 0x3F
    mov dl, byte [rdi + rdx]
    mov byte [r10 + rcx], dl
    inc rcx

    mov edx, eax
    shr edx, 12
    and edx, 0x3F
    mov dl, byte [rdi + rdx]
    mov byte [r10 + rcx], dl
    inc rcx

    mov edx, eax
    shr edx, 6
    and edx, 0x3F
    mov dl, byte [rdi + rdx]
    mov byte [r10 + rcx], dl
    inc rcx

    mov edx, eax
    and edx, 0x3F
    mov dl, byte [rdi + rdx]
    mov byte [r10 + rcx], dl
    inc rcx

    jmp .b64e_loop

; Остался 1 байт — выводим 2 символа + "=="
.b64e_2byte:
    lea rdi, [b64_table]
    mov edx, eax
    shr edx, 18
    and edx, 0x3F
    mov dl, byte [rdi + rdx]
    mov byte [r10 + rcx], dl
    inc rcx

    mov edx, eax
    shr edx, 12
    and edx, 0x3F
    mov dl, byte [rdi + rdx]
    mov byte [r10 + rcx], dl
    inc rcx

    mov byte [r10 + rcx], '='
    inc rcx
    mov byte [r10 + rcx], '='
    inc rcx
    jmp .b64e_done

; Осталось 2 байта — выводим 3 символа + "="
.b64e_1byte:
    lea rdi, [b64_table]
    mov edx, eax
    shr edx, 18
    and edx, 0x3F
    mov dl, byte [rdi + rdx]
    mov byte [r10 + rcx], dl
    inc rcx

    mov edx, eax
    shr edx, 12
    and edx, 0x3F
    mov dl, byte [rdi + rdx]
    mov byte [r10 + rcx], dl
    inc rcx

    mov edx, eax
    shr edx, 6
    and edx, 0x3F
    mov dl, byte [rdi + rdx]
    mov byte [r10 + rcx], dl
    inc rcx

    mov byte [r10 + rcx], '='
    inc rcx

.b64e_done:
    mov byte [r10 + rcx], 0
    mov rax, rcx

    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rbx
    ret

; ===========================================================================================
; base64_decode — декодирует Base64 строку обратно в бинарные данные
; Обратный процесс: 4 символа → 3 байта. Символы '=' означают отсутствие байтов на конце
; (rdi = input, rsi = len, rdx = output) => rax = output_len
; ===========================================================================================
base64_decode:
    push rbx
    push rcx
    push rdx
    push r8
    push r9
    push r10
    push r11

    mov r8, rdi                        ; input
    mov r9, rsi                        ; len
    mov r10, rdx                       ; output
    xor rbx, rbx                       ; индекс чтения
    xor rcx, rcx                       ; индекс записи

.b64d_loop:
    cmp rbx, r9
    jae .b64d_done

; Берём 4 символа, через обратную таблицу получаем 4 значения по 6 бит, собираем в 24-битный блок
    lea r11, [b64_decode_table]

    movzx eax, byte [r8 + rbx]         ; первый символ → биты 18-23
    movzx eax, byte [r11 + rax]
    shl eax, 18
    inc rbx

    movzx edx, byte [r8 + rbx]         ; второй символ → биты 12-17
    movzx edx, byte [r11 + rdx]
    shl edx, 12
    or eax, edx
    inc rbx

    cmp byte [r8 + rbx], '='           ; "==" → был только 1 исходный байт
    je .b64d_2pad

    movzx edx, byte [r8 + rbx]         ; третий символ → биты 6-11
    movzx edx, byte [r11 + rdx]
    shl edx, 6
    or eax, edx
    inc rbx

    cmp byte [r8 + rbx], '='           ; "=" → было 2 исходных байта
    je .b64d_1pad

    movzx edx, byte [r8 + rbx]         ; четвёртый символ → биты 0-5
    movzx edx, byte [r11 + rdx]
    or eax, edx
    inc rbx

; Разбираем 24 бита обратно в 3 байта
    mov edx, eax
    shr edx, 16
    mov byte [r10 + rcx], dl           ; первый байт (биты 16-23)
    inc rcx
    mov edx, eax
    shr edx, 8
    mov byte [r10 + rcx], dl           ; второй байт (биты 8-15)
    inc rcx
    mov byte [r10 + rcx], al           ; третий байт (биты 0-7)
    inc rcx
    jmp .b64d_loop

; Padding "=" → было 2 исходных байта, достаём только 2
.b64d_1pad:
    inc rbx
    mov edx, eax
    shr edx, 16
    mov byte [r10 + rcx], dl
    inc rcx
    mov edx, eax
    shr edx, 8
    mov byte [r10 + rcx], dl
    inc rcx
    jmp .b64d_done

; Padding "==" → был только 1 исходный байт, достаём только 1
.b64d_2pad:
    add rbx, 2
    mov edx, eax
    shr edx, 16
    mov byte [r10 + rcx], dl
    inc rcx

.b64d_done:
    mov rax, rcx

    pop r11
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rbx
    ret
