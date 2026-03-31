default rel
extern memcpy

; ===========================================================================================
; SHA-256 реализация (RFC 6234)

; Экспорт:
; sha256(rdi = input, rsi = len, rdx = output_32bytes)
; ===========================================================================================

section .data

; 64 константы раундов — дробные части кубических корней первых 64 простых чисел
sha256_K:
    dd 0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5
    dd 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5
    dd 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3
    dd 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174
    dd 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc
    dd 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da
    dd 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7
    dd 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967
    dd 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13
    dd 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85
    dd 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3
    dd 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070
    dd 0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5
    dd 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3
    dd 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208
    dd 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2

section .bss
    sha256_buffer resb 256             ; Буфер для padding
    sha256_state resd 8                ; Состояние (8 x 4 байта)
    sha256_W resd 64                   ; Расписание сообщений (64 x 4 байта)

section .text
global sha256

; ===========================================================================================
; sha256_pad — подготовка данных для хеширования
; SHA-256 работает блоками по 64 байта, поэтому входные данные нужно дополнить:
; 1. Скопировать данные в буфер
; 2. Добавить байт 0x80 (маркер конца данных)
; 3. Дополнить нулями до кратного 64 (минус 8 байт на длину)
; 4. В последние 8 байт записать длину исходных данных в битах (big-endian)
; (rdi = input, rsi = len) => данные в sha256_buffer, rax = кол-во 64-байтных блоков
; ===========================================================================================
sha256_pad:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    mov rbx, rsi

; 1. Обнуляем буфер
    push rdi
    push rsi
    lea rdi, [sha256_buffer]
    xor rcx, rcx
.sha_clear:
    mov byte [rdi + rcx], 0
    inc rcx
    cmp rcx, 256
    jb .sha_clear
    pop rsi
    pop rdi

; 2. Копируем данные
    push rdi
    lea rdi, [sha256_buffer]
    mov rsi, [rsp]
    add rsp, 8
    mov rdx, rbx
    call memcpy

; 3. Добавляем 0x80
    lea rdi, [sha256_buffer]
    mov byte [rdi + rbx], 0x80

; 4. Вычисляем количество блоков и позицию длины
    mov rax, rbx
    inc rax
    add rax, 8
    add rax, 63
    shr rax, 6
    push rax

    shl rax, 6
    sub rax, 8

; 5. Длина в битах (big-endian)
    lea rdi, [sha256_buffer]
    mov rcx, rbx
    shl rcx, 3
    bswap rcx
    mov qword [rdi + rax], rcx

    pop rax

    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ===========================================================================================
; sha256_transform — основная вычислительная функция SHA-256
; Берёт один 64-байтный блок и "перемалывает" 8 переменных состояния (a-h)
; через 64 раунда битовых операций (rotate, XOR, AND, NOT)
; Регистры r8-r15 = переменные состояния a,b,c,d,e,f,g,h
; (rdi = указатель на 64-байтный блок) => обновляет sha256_state
; ===========================================================================================
sha256_transform:
    push rbx
    push rcx
    push rdx
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    push rbp
    push rdi

; W[0..15] — копируем 16 слов из входного блока (big-endian → little-endian)
    lea rbp, [sha256_W]
    xor rcx, rcx
.sha_prep_w:
    mov eax, dword [rdi + rcx * 4]
    bswap eax
    mov dword [rbp + rcx * 4], eax
    inc rcx
    cmp rcx, 16
    jb .sha_prep_w

; W[16..63] — расширяем: каждое новое слово вычисляется из предыдущих через rotate/shift/XOR
    mov rcx, 16
.sha_extend_w:
    cmp rcx, 64
    je .sha_extend_done

    mov eax, dword [rbp + rcx * 4 - 8]
    mov r8d, eax
    mov r9d, eax
    mov r10d, eax
    ror r8d, 17
    ror r9d, 19
    shr r10d, 10
    xor r8d, r9d
    xor r8d, r10d

    mov eax, dword [rbp + rcx * 4 - 60]
    mov r9d, eax
    mov r10d, eax
    mov r11d, eax
    ror r9d, 7
    ror r10d, 18
    shr r11d, 3
    xor r9d, r10d
    xor r9d, r11d

    add r8d, dword [rbp + rcx * 4 - 28]
    add r8d, r9d
    add r8d, dword [rbp + rcx * 4 - 64]
    mov dword [rbp + rcx * 4], r8d

    inc rcx
    jmp .sha_extend_w
.sha_extend_done:

; Загружаем состояние a-h в регистры r8-r15 и сохраняем копию на стеке
    lea rdi, [sha256_state]
    mov r8d, dword [rdi]
    mov r9d, dword [rdi + 4]
    mov r10d, dword [rdi + 8]
    mov r11d, dword [rdi + 12]
    mov r12d, dword [rdi + 16]
    mov r13d, dword [rdi + 20]
    mov r14d, dword [rdi + 24]
    mov r15d, dword [rdi + 28]

    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    xor rcx, rcx                       ; счётчик раундов 0..63

; -------------------------------------------------------------------------------------------------------------------------------
; 64 раунда перемешивания. Каждый раунд:
; temp1 = h + Sigma1(e) + Ch(e,f,g) + K[i] + W[i]
; temp2 = Sigma0(a) + Maj(a,b,c)
; Сдвигаем a-h вниз, a = temp1 + temp2, e += temp1
; -------------------------------------------------------------------------------------------------------------------------------
.sha_round:
    cmp rcx, 64
    je .sha_round_done

; Sigma1(e)
    mov eax, r12d
    mov ebx, r12d
    mov edx, r12d
    ror eax, 6
    ror ebx, 11
    ror edx, 25
    xor eax, ebx
    xor eax, edx

; Ch(e,f,g)
    mov ebx, r12d
    and ebx, r13d
    mov edx, r12d
    not edx
    and edx, r14d
    xor ebx, edx

; temp1 = h + Sigma1 + Ch + K[i] + W[i]
    add eax, r15d
    add eax, ebx
    lea rdi, [sha256_K]
    add eax, dword [rdi + rcx * 4]
    add eax, dword [rbp + rcx * 4]
    mov ebx, eax                       ; ebx = temp1

; Sigma0(a)
    mov eax, r8d
    mov edx, r8d
    push rcx
    mov ecx, r8d
    ror eax, 2
    ror edx, 13
    ror ecx, 22
    xor eax, edx
    xor eax, ecx
    pop rcx

; Maj(a,b,c)
    mov edx, r8d
    and edx, r9d
    push rdx
    mov edx, r8d
    and edx, r10d
    push rdx
    mov edx, r9d
    and edx, r10d
    pop rdi
    xor edx, edi
    pop rdi
    xor edx, edi

; temp2
    add eax, edx

; Обновляем a..h
    mov r15d, r14d
    mov r14d, r13d
    mov r13d, r12d
    mov r12d, r11d
    add r12d, ebx
    mov r11d, r10d
    mov r10d, r9d
    mov r9d, r8d
    mov r8d, ebx
    add r8d, eax

    inc rcx
    jmp .sha_round

; Прибавляем результат раундов к сохранённой копии состояния (со стека)
.sha_round_done:
    pop rax
    add r15d, eax
    pop rax
    add r14d, eax
    pop rax
    add r13d, eax
    pop rax
    add r12d, eax
    pop rax
    add r11d, eax
    pop rax
    add r10d, eax
    pop rax
    add r9d, eax
    pop rax
    add r8d, eax

    lea rdi, [sha256_state]
    mov dword [rdi], r8d
    mov dword [rdi + 4], r9d
    mov dword [rdi + 8], r10d
    mov dword [rdi + 12], r11d
    mov dword [rdi + 16], r12d
    mov dword [rdi + 20], r13d
    mov dword [rdi + 24], r14d
    mov dword [rdi + 28], r15d

    pop rdi
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rbx
    ret

; ===========================================================================================
; sha256 — главная функция: любые данные → 32 байта хеша
; 1. Инициализирует состояние магическими числами из стандарта
; 2. Дополняет данные через sha256_pad
; 3. Прогоняет каждый 64-байтный блок через sha256_transform
; 4. Конвертирует результат в big-endian и копирует в output
; (rdi = input, rsi = len, rdx = output_32bytes)
; ===========================================================================================
sha256:
    push rbx
    push rcx
    push rdx
    push r12
    push r13

    mov r12, rdx                       ; сохраняем output

; Инициализируем состояние — дробные части квадратных корней первых 8 простых чисел
    lea rax, [sha256_state]
    mov dword [rax], 0x6a09e667
    mov dword [rax + 4], 0xbb67ae85
    mov dword [rax + 8], 0x3c6ef372
    mov dword [rax + 12], 0xa54ff53a
    mov dword [rax + 16], 0x510e527f
    mov dword [rax + 20], 0x9b05688c
    mov dword [rax + 24], 0x1f83d9ab
    mov dword [rax + 28], 0x5be0cd19

    call sha256_pad                    ; дополняем данные, rax = кол-во блоков
    mov r13, rax

; Прогоняем каждый 64-байтный блок через transform
    xor rbx, rbx
.sha_block_loop:
    cmp rbx, r13
    je .sha_finalize
    lea rdi, [sha256_buffer]
    mov rax, rbx
    shl rax, 6
    add rdi, rax
    call sha256_transform
    inc rbx
    jmp .sha_block_loop

; Копируем 8 слов состояния в output, конвертируя в big-endian
.sha_finalize:
    lea rsi, [sha256_state]
    mov rdi, r12
    xor rcx, rcx
.sha_copy:
    mov eax, dword [rsi + rcx * 4]
    bswap eax
    mov dword [rdi + rcx * 4], eax
    inc rcx
    cmp rcx, 8
    jb .sha_copy

    pop r13
    pop r12
    pop rdx
    pop rcx
    pop rbx
    ret
