default rel
extern memcpy
extern sha256

; ===========================================================================================
; HMAC-SHA-256 (RFC 2104) — SHA256 с секретным ключом
; Без ключа любой может посчитать SHA256. HMAC гарантирует что хеш мог создать только
; владелец ключа. Используется для подписи данных в SCRAM и PBKDF2.

; Формула: HMAC(key, msg) = SHA256( (key XOR opad) + SHA256( (key XOR ipad) + msg ) )
; ipad = 0x36 повторённый 64 раза, opad = 0x5C повторённый 64 раза

; Экспорт:
; hmac_sha256(rdi = key, rsi = key_len, rdx = msg, rcx = msg_len, r8 = output_32bytes)
; ===========================================================================================

section .bss
    hmac_ipad resb 64                  ; ключ XOR 0x363636... (внутренний)
    hmac_opad resb 64                  ; ключ XOR 0x5C5C5C... (внешний)
    hmac_temp resb 256                 ; Буфер для склейки: ipad(64) + msg(до 192)
    hmac_inner_hash resb 32            ; Результат внутреннего SHA256

section .text
global hmac_sha256

hmac_sha256:
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

    mov r12, rdi                       ; key
    mov r13, rsi                       ; key_len
    mov r14, rdx                       ; msg
    mov r15, rcx                       ; msg_len
    mov rbx, r8                        ; output

; Если ключ > 64 байт, хешируем его
    cmp r13, 64
    jbe .hmac_key_ok
    mov rdi, r12
    mov rsi, r13
    lea rdx, [hmac_inner_hash]
    call sha256
    lea r12, [hmac_inner_hash]
    mov r13, 32
.hmac_key_ok:

; Заполняем ipad = 0x36..., opad = 0x5C... (64 байта каждый)
    lea rdi, [hmac_ipad]
    lea rsi, [hmac_opad]
    xor rcx, rcx
.hmac_clear:
    mov byte [rdi + rcx], 0x36
    mov byte [rsi + rcx], 0x5c
    inc rcx
    cmp rcx, 64
    jb .hmac_clear

; XOR'им ключ поверх ipad и opad — так ключ "вмешивается" в хеш
    xor rcx, rcx
.hmac_xor_key:
    cmp rcx, r13
    je .hmac_xor_done
    mov al, byte [r12 + rcx]
    xor byte [rdi + rcx], al
    xor byte [rsi + rcx], al
    inc rcx
    jmp .hmac_xor_key
.hmac_xor_done:

; Шаг 1: inner_hash = SHA256(ipad + msg) — склеиваем в hmac_temp и хешируем
    lea rdi, [hmac_temp]
    lea rsi, [hmac_ipad]
    mov rdx, 64
    call memcpy

    lea rdi, [hmac_temp + 64]
    mov rsi, r14
    mov rdx, r15
    call memcpy

    lea rdi, [hmac_temp]
    mov rsi, 64
    add rsi, r15
    lea rdx, [hmac_inner_hash]
    call sha256

; Шаг 2: result = SHA256(opad + inner_hash) — оборачиваем ещё одним хешем
    lea rdi, [hmac_temp]
    lea rsi, [hmac_opad]
    mov rdx, 64
    call memcpy

    lea rdi, [hmac_temp + 64]
    lea rsi, [hmac_inner_hash]
    mov rdx, 32
    call memcpy

    lea rdi, [hmac_temp]
    mov rsi, 96
    mov rdx, rbx
    call sha256

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
