default rel
extern memcpy
extern hmac_sha256

; ===========================================================================================
; PBKDF2-SHA-256 (RFC 2898) — превращает человеческий пароль в криптографический ключ

; Зачем: пароль "qwerty" — плохой ключ. PBKDF2 прогоняет его через HMAC тысячи раз,
; делая brute-force атаки медленными. 4096 итераций = каждая попытка ~1мс.

; Формула: U1 = HMAC(password, salt + 0x00000001)
; U2 = HMAC(password, U1)
; U3 = HMAC(password, U2)  ...и так iterations раз
; result = U1 XOR U2 XOR U3 XOR ... XOR U_n

; Реализация только для 1 блока (dkLen = 32 байта) — достаточно для SCRAM-SHA-256

; Экспорт:
; pbkdf2_sha256(rdi = password, rsi = pass_len, rdx = salt, rcx = salt_len,
; r8 = iterations, r9 = output_32bytes)
; ===========================================================================================

section .bss
    pbkdf2_U resb 32                   ; Текущий U_i
    pbkdf2_T resb 32                   ; Накопленный результат (XOR всех U)
    pbkdf2_salt_buf resb 256           ; salt + INT(1) для первого HMAC
    pbkdf2_temp resb 32                ; Временный буфер для нового U

section .text
global pbkdf2_sha256

pbkdf2_sha256:
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

    mov r10, rdi                       ; password
    mov r11, rsi                       ; pass_len
    mov r12, rdx                       ; salt
    mov r13, rcx                       ; salt_len
    mov r14, r8                        ; iterations
    mov r15, r9                        ; output

; Первая итерация: U1 = HMAC(password, salt + 0x00000001)
; Собираем salt + INT(1) в pbkdf2_salt_buf
    lea rdi, [pbkdf2_salt_buf]
    mov rsi, r12
    mov rdx, r13
    call memcpy

    lea rdi, [pbkdf2_salt_buf]
    add rdi, r13
    mov byte [rdi], 0
    mov byte [rdi + 1], 0
    mov byte [rdi + 2], 0
    mov byte [rdi + 3], 1

; HMAC(password, salt + INT(1))
    mov rdi, r10
    mov rsi, r11
    lea rdx, [pbkdf2_salt_buf]
    mov rcx, r13
    add rcx, 4
    lea r8, [pbkdf2_U]
    call hmac_sha256

; T = U1
    lea rdi, [pbkdf2_T]
    lea rsi, [pbkdf2_U]
    mov rdx, 32
    call memcpy

; Остальные итерации: U_i = HMAC(password, U_{i-1}), T ^= U_i
    mov rbx, 1                         ; начинаем со 2-й итерации (U1 уже посчитан)

.pbkdf2_loop:
    cmp rbx, r14
    je .pbkdf2_done

; Следующий U: хешируем предыдущий результат
    mov rdi, r10
    mov rsi, r11
    lea rdx, [pbkdf2_U]
    mov rcx, 32
    lea r8, [pbkdf2_temp]
    call hmac_sha256

; Копируем новый U
    lea rdi, [pbkdf2_U]
    lea rsi, [pbkdf2_temp]
    mov rdx, 32
    call memcpy

; T ^= U_i — накапливаем результат через XOR
    xor rcx, rcx
.pbkdf2_xor:
    mov al, byte [pbkdf2_U + rcx]
    xor byte [pbkdf2_T + rcx], al
    inc rcx
    cmp rcx, 32
    jb .pbkdf2_xor

    inc rbx
    jmp .pbkdf2_loop

; Копируем итоговый T в output
.pbkdf2_done:
    lea rdi, [r15]
    lea rsi, [pbkdf2_T]
    mov rdx, 32
    call memcpy

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
