default rel

section .text
global strlen
global strcmp
global itoa
global strcpy
global strcat
global strncmp
global memcpy
; (rdi: pointer to string) => (rax: string length)
strlen:
    xor rax, rax                       ; Zero out the counter register
.strcount_loop:
    cmp byte [rdi + rax], 0            ; Compare current byte with zero
    je .strcount_done                  ; Byte is zero, end of string reached
    inc rax                            ; Increment counter
    jmp .strcount_loop                 ; Move to the next byte
.strcount_done:
    ret

; (rdi: указатель на первую строку, rsi: указатель на вторую строку) => (rax: 0 если строки равны, 1 если строки не равны)
strcmp:
    push rcx                           ; Сохранение cl на стеке
    push rdx                           ; Сохранение dl на стеке

    xor rax, rax                       ; обнуление регистар счётв
.strcmp_loop:
    mov cl, byte [rdi + rax]           ; загрузка текущего байта первой строки в cl
    mov dl, byte [rsi + rax]           ; загрузка текущего байта второй строки в dl
    cmp cl, dl
    jne .strcmp_not_equal              ; байты не равны, строки не совпадают
    cmp cl, 0                          ; Проверка на конец строки
    je .strcmp_equal                   ; обе строки закончились, они равны
    inc rax                            ; Увеличение счётчика
    jmp .strcmp_loop                   ; Переход к следующему байту
.strcmp_not_equal:
    mov rax, 1                         ; строки не равны, возвращаем 1
    jmp .strcmp_end

.strcmp_equal:
    mov rax, 0                         ; строки равны, возвращаем 0
    jmp .strcmp_end

.strcmp_end:
    pop rdx
    pop rcx
    ret

; (rdi: число, rsi: буффер куда писать) => (rax: длина строки)
itoa:
    push r14                           ; Сохранение r14 на стеке
    push r8                            ; Сохранение r8 на стеке
    push rdx                           ; Сохранение rdx на стеке
    push rcx                           ; Сохранение rcx на стеке

    xor r14, r14
    mov rax, rdi
    mov r8, 10                         ; Делитель для получения последней цифры
.loop:                                 ; Цикл для конвертации числа в строку

    xor rdx, rdx                       ; Обнуление rdx для использования в div
    div r8                             ; Получение последней цифры числа
    add rdx, 48                        ; Преобразование цифры в её ASCII код
    push rdx                           ; Сохранение ASCII кода на стеке
    inc r14                            ; Увеличение счётчика количества цифр
    cmp rax, 0                         ; есть ли ещё цифры
    jnz .loop

.done:
    xor rcx, rcx                       ; Сброс смещения для записи в строку
.cocant_loop:

    cmp rcx, r14                       ; Проверка на количество цифр, если равно нулю, то нужно записать '0' в строку
    je .cocant_done                    ; Если количество цифр равно нулю, то переходим к завершению

    pop rdx                            ; Получение ASCII кода цифры из стека
    mov byte [rsi + rcx], dl           ; Запись ASCII кода в строку
    inc rcx                            ; Увеличение смещения для следующей цифры
    jmp .cocant_loop

.cocant_done:
    mov byte [rsi + rcx], 0            ; Запись нулевого байта в конец строки
    mov rax, r14

    pop rcx
    pop rdx
    pop r8
    pop r14
    ret

; (rdi: указатель куда копировать строку, rsi: указатель на строку для копирования) => void
; функция для копирование в буфер строки
strcpy:
    push rax                           ; Сохранение rax на стеке
    push rcx                           ; Сохранение rcx на стеке
    push rdx                           ; Сохранение rdx на стеке
    push rsi                           ; Сохранение rsi на стеке
    push rdi                           ; Сохранение rdi на стеке
    push r8                            ; Сохранение r8 на стеке
    push r9                            ; Сохранение r9 на стеке
    push r10                           ; Сохранение r10 на стеке
    push r11                           ; Сохранение r11 на стеке

    mov rdi, rsi
    call strlen

    mov rdi, [rsp + 32]                ; восстанавливаем оригинальный rdi (destination) из стека

    mov rcx, rax                       ; rep movsb берёт количество байт из rcx
    rep movsb                          ; копируем rcx байт из [rsi] в [rdi]

    pop r11                            ; Восстанавливаем r11
    pop r10                            ; Восстанавливаем r10
    pop r9                             ; Восстанавливаем r9
    pop r8                             ; Восстанавливаем r8
    pop rdi                            ; Восстанавливаем rdi
    pop rsi                            ; Восстанавливаем rsi
    pop rdx                            ; Восстанавливаем rdx
    pop rcx                            ; Восстанавливаем rcx
    pop rax                            ; Восстанавливаем rax
    ret

; (rdi: указатель на первую строку, rsi: указатель на вторую строку) => void
strcat:
    push r14
    xor r14, r14                       ; Сброс смещения для первой строки

.loop:
    cmp byte [rdi + r14], 0            ; ищем конец строки
    je .end

    inc r14                            ; Увеличение смещения для первой строки
    jmp .loop                          ; Переход к следующему байту

.end:
.sec_loop:
    mov cl, byte [rsi]                 ; загрузка текущего байта из второй строки в cl
    cmp cl, 0                          ; Проверка на конец строки
    je .done                           ; Если достигнут конец строки, завершение

    mov byte [rdi + r14], cl           ; Запись байта в первую строку

    inc r14                            ; Увеличение смещения для первой строки
    inc rsi                            ; Переход к следующему байту во второй строке

    jmp .sec_loop                      ; Переход к следующему байту

.done:
    mov byte [rdi + r14], 0            ; Запись нулевого байта в конец первой строки
    pop r14
    ret
; (rdi: указатель на первую строку, rsi: указатель на вторую строку, rdx: сколько байт строка1) => (rax: 0 если строки равны, 1 если строки не равны)
strncmp:
    push rdi
    push rsi
    push rdx

    push rcx
    push r8
    push r9

    push r10
    push r11

    mov r10, rdi
    mov r11, rsi

    xor rcx, rcx

    mov rdi, r11
    call strlen

    cmp rax, rdx
    jb .strncmp_not_equal

.strncmp_loop:
    cmp rcx, rdx
    je .strncmp_equal

    mov r8b, byte [r10 + rcx]          ; загрузка текущего байта первой строки в r8
    mov r9b, byte [r11 + rcx]          ; загрузка текущего байта второй строки в r9

    cmp r8b, r9b
    jne .strncmp_not_equal

    inc rcx
    jmp .strncmp_loop

.strncmp_not_equal:
    mov rax, 1
    jmp .strncmp_end

.strncmp_equal:
    mov rax, 0
    jmp .strncmp_end

.strncmp_end:
    pop r11
    pop r10

    pop r9
    pop r8
    pop rcx

    pop rdx
    pop rsi
    pop rdi
    ret

; (rdi: указатель куда копировать строку, rsi: указатель на строку для копирования, rdx: сколько байт) => void
memcpy:
    push rax                           ; Сохранение rax на стеке
    push rcx                           ; Сохранение rcx на стеке
    push rdx                           ; Сохранение rdx на стеке
    push rsi                           ; Сохранение rsi на стеке
    push rdi                           ; Сохранение rdi на стеке
    push r8                            ; Сохранение r8 на стеке
    push r9                            ; Сохранение r9 на стеке
    push r10                           ; Сохранение r10 на стеке
    push r11                           ; Сохранение r11 на стеке

    mov rcx, rdx
    rep movsb                          ; копируем rcx байт из [rsi] в [rdi]

    pop r11                            ; Восстанавливаем r11
    pop r10                            ; Восстанавливаем r10
    pop r9                             ; Восстанавливаем r9
    pop r8                             ; Восстанавливаем r8
    pop rdi                            ; Восстанавливаем rdi
    pop rsi                            ; Восстанавливаем rsi
    pop rdx                            ; Восстанавливаем rdx
    pop rcx                            ; Восстанавливаем rcx
    pop rax                            ; Восстанавливаем rax
    ret
