default rel

section .text
; (rdi: указатель на строку HTTP запроса) => (rax: указатель на метод, rdx: указатель на путь)
global parse_http_request
global find_body
parse_http_request:
    xor rax, rax                       ; обнуление регистра счёта

.parse_loop:
    cmp byte [rdi + rax], 32           ; Сравнение текущего байта с пробелом | 32 - ASCII код пробела
    je .parse_done                     ; байт равен пробелу, конец метода

    inc rax                            ; Увеличение счётчика
    jmp .parse_loop                    ; Переход к следующему байту

.parse_done:
    mov byte [rdi + rax], 0            ; Заменяем пробел на нулевой байт, чтобы завершить строку
    inc rax                            ; Переход к следующему байту после метода
    lea rdx, [rdi + rax]               ; Сохранение указателя на начало пути (первого байта после метода) в rdx

.find_path:
    cmp byte [rdi + rax], 32           ; Сравнение следующего байта с пробелом
    je .path_done                      ; байт равен пробелу, конец пути

    inc rax                            ; Увеличение счётчика
    jmp .find_path                     ; Переход к следующему байту

.path_done:
    mov byte [rdi + rax], 0            ; Заменяем пробел на нулевой байт, чтобы завершить строку пути
    mov rax, rdi                       ; Возвращаем указатель на начало строки (метода)
; теперь rax указывает на начало метода, а rdx указывает на первый байт пути
    ret

; (rdi: указатель на строку http, rsi: длина запроса) => (rax: указатель на тело запроса)
find_body:
    push r8
    push r9
    xor r8, r8                         ; обнуление регистра для итерации по строке
    mov r9, rdi                        ; Сохранение указателя на начало строки в r9 для дальнейшего использования

    mov rcx, rsi
    sub rcx, 3
.loop:
    cmp r8, rcx                        ; Сравнение текущего индекса с длиной строки
    jge .not_found                     ; Если достигнут конец строки, тело запроса не найдено

    cmp byte [r9 + r8], 13             ; Сравнение текущего байта с символом новой строки (CR, Carriage Return)
    je .check_next

    inc r8
    jmp .loop

.check_next:

    cmp byte [r9 + r8 + 1], 10
    je .second_check

    inc r8
    jmp .loop

.second_check:

    cmp byte [r9 + r8 + 2], 13
    je .third_check

    inc r8
    jmp .loop

.third_check:

    cmp byte [r9 + r8 + 3], 10
    je .body_found

    inc r8
    jmp .loop

.body_found:
    lea rax, [r9 + r8 + 4]             ; Установка rax на начало тела запроса (после двух последовательных новых строк)
    pop r9
    pop r8
    ret

.not_found:
    pop r9
    pop r8
    mov rax, -1
    ret

