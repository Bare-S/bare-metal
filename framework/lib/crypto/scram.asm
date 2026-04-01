default rel
extern strlen, strcat, memcpy
extern sha256, hmac_sha256, pbkdf2_sha256
extern base64_encode, base64_decode
extern getenv

%include "logger.inc"

; ===========================================================================================
; SCRAM-SHA-256 протокол (RFC 5802)

; Экспорт:
; scram_build_client_first(нет аргументов) => scram_client_first_msg заполнен
; scram_parse_server_first(rdi = строка ответа сервера)
; scram_build_client_final() => scram_client_final_msg заполнен
; ===========================================================================================

section .data

scram_client_key_str:
    db "Client Key"                    ; 10 байт, без \0
    scram_client_key_str_len equ 10

db_env_pass:
    db "DB_PASSWORD", 0

scram_cfmb_prefix:
    db "n=", 0x2C, "r=", 0             ; "n=,r="
scram_cfm_prefix:
    db "n", 0x2C, 0x2C, 0              ; "n,,"
scram_cfwp_prefix:
    db "c=biws", 0x2C, "r=", 0         ; "c=biws,r="
scram_proof_prefix:
    db 0x2C, "p=", 0                   ; ",p="
scram_comma:
    db 0x2C, 0                         ; ","
scram_urandom_path:
    db "/dev/urandom", 0

scram_step_msg:
    db "SCRAM step completed", 0

section .bss
global scram_client_nonce
global scram_client_first_bare
global scram_client_first_msg
global scram_client_final_msg
global scram_server_first
global scram_server_nonce
global scram_server_salt_b64
global scram_server_salt
global scram_server_salt_len
global scram_server_iterations
global scram_server_iter_num

    scram_nonce_raw resb 18            ; Сырые байты для nonce
    scram_client_nonce resb 32         ; Base64 nonce клиента
    scram_client_first_bare resb 256   ; "n=,r=<nonce>"
    scram_client_first_msg resb 300    ; "n,,n=,r=<nonce>"
    scram_client_final_msg resb 512    ; Финальное сообщение

    scram_server_first resb 1024       ; Ответ сервера (копия)
    scram_server_nonce resb 256        ; Полный nonce
    scram_server_salt_b64 resb 256     ; Соль (base64)
    scram_server_salt resb 256         ; Соль (decoded)
    scram_server_salt_len resq 1       ; Длина decoded salt
    scram_server_iterations resb 16    ; Iterations (строка)
    scram_server_iter_num resq 1       ; Iterations (число)

    scram_salted_password resb 32
    scram_client_key resb 32
    scram_stored_key resb 32
    scram_client_sig resb 32
    scram_client_proof resb 32
    scram_client_proof_b64 resb 48

    scram_auth_msg resb 1024           ; AuthMessage
    scram_cfwp resb 256                ; client-final-without-proof
    scram_temp resb 256

section .text
global scram_build_client_first
global scram_parse_server_first
global scram_build_client_final

; ===========================================================================================
; generate_nonce — генерация случайного nonce из /dev/urandom
; (rdi = output, rsi = num_bytes)
; ===========================================================================================
generate_nonce:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8

    mov r8, rdi                        ; r8 = output buffer
    mov rbx, rsi                       ; rbx = num_bytes (syscall затирает rcx, поэтому используем rbx)

; open("/dev/urandom", O_RDONLY)
    mov rax, 2
    lea rdi, [scram_urandom_path]
    xor rsi, rsi
    xor rdx, rdx
    syscall                            ; syscall затирает rcx и r11 — rbx не затрагивается
    cmp rax, 0
    jl .nonce_fallback

    mov rdi, rax
    push rdi
    mov rsi, r8                        ; buffer
    mov rdx, rbx                       ; num_bytes из rbx (НЕ из затёртого rcx)
    mov rax, 0
    syscall
    pop rdi

    push rax
    mov rax, 3
    syscall
    pop rax
    jmp .nonce_done

.nonce_fallback:
    xor rcx, rcx
.nonce_fb_loop:
    cmp rcx, rbx                       ; rbx хранит num_bytes (НЕ rsi, который был обнулён для open)
    jae .nonce_done
    rdtsc
    xor al, dl
    mov byte [r8 + rcx], al
    inc rcx
    jmp .nonce_fb_loop

.nonce_done:
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ===========================================================================================
; scram_atoi — строка → число
; (rdi = строка) => rax = число
; ===========================================================================================
scram_atoi:
    xor rax, rax
.scram_atoi_loop:
    movzx rcx, byte [rdi]
    cmp cl, '0'
    jb .scram_atoi_done
    cmp cl, '9'
    ja .scram_atoi_done
    imul rax, 10
    sub cl, '0'
    add rax, rcx
    inc rdi
    jmp .scram_atoi_loop
.scram_atoi_done:
    ret

; ===========================================================================================
; scram_build_client_first — собирает client-first-message
; Заполняет: scram_client_nonce, scram_client_first_bare, scram_client_first_msg
; ===========================================================================================
scram_build_client_first:
    push rdi
    push rsi
    push rdx

; Генерируем nonce (18 random bytes → 24 chars base64)
    lea rdi, [scram_nonce_raw]
    mov rsi, 18
    call generate_nonce

    lea rdi, [scram_nonce_raw]
    mov rsi, 18
    lea rdx, [scram_client_nonce]
    call base64_encode

; client-first-message-bare = "n=,r=<nonce>"
    lea rdi, [scram_client_first_bare]
    mov byte [rdi], 0
    lea rsi, [scram_cfmb_prefix]
    call strcat
    lea rdi, [scram_client_first_bare]
    lea rsi, [scram_client_nonce]
    call strcat

; client-first-message = "n,," + bare
    lea rdi, [scram_client_first_msg]
    mov byte [rdi], 0
    lea rsi, [scram_cfm_prefix]
    call strcat
    lea rdi, [scram_client_first_msg]
    lea rsi, [scram_client_first_bare]
    call strcat

    LOG_DB scram_step_msg

    pop rdx
    pop rsi
    pop rdi
    ret

; ===========================================================================================
; scram_parse_server_first — парсит "r=<nonce>,s=<salt>,i=<iter>"
; (rdi = указатель на строку ответа сервера)
; Заполняет: scram_server_nonce, scram_server_salt_b64, scram_server_iterations
; scram_server_salt (decoded), scram_server_salt_len, scram_server_iter_num
; ===========================================================================================
scram_parse_server_first:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    mov rbx, rdi

; Парсим "r=..."
    cmp byte [rbx], 'r'
    jne .parse_sf_done
    add rbx, 2

    lea rdi, [scram_server_nonce]
    xor rcx, rcx
.parse_sf_nonce:
    cmp byte [rbx + rcx], ', '
    je .parse_sf_nonce_done
    cmp byte [rbx + rcx], 0
    je .parse_sf_nonce_done
    mov al, byte [rbx + rcx]
    mov byte [rdi + rcx], al
    inc rcx
    jmp .parse_sf_nonce
.parse_sf_nonce_done:
    mov byte [rdi + rcx], 0
    add rbx, rcx
    inc rbx

; Парсим "s=..."
    cmp byte [rbx], 's'
    jne .parse_sf_done
    add rbx, 2

    lea rdi, [scram_server_salt_b64]
    xor rcx, rcx
.parse_sf_salt:
    cmp byte [rbx + rcx], ', '
    je .parse_sf_salt_done
    cmp byte [rbx + rcx], 0
    je .parse_sf_salt_done
    mov al, byte [rbx + rcx]
    mov byte [rdi + rcx], al
    inc rcx
    jmp .parse_sf_salt
.parse_sf_salt_done:
    mov byte [rdi + rcx], 0
    add rbx, rcx
    inc rbx

; Парсим "i=..."
    cmp byte [rbx], 'i'
    jne .parse_sf_done
    add rbx, 2

    lea rdi, [scram_server_iterations]
    xor rcx, rcx
.parse_sf_iter:
    cmp byte [rbx + rcx], 0
    je .parse_sf_iter_done
    cmp byte [rbx + rcx], ', '
    je .parse_sf_iter_done
    cmp byte [rbx + rcx], 13
    je .parse_sf_iter_done
    cmp byte [rbx + rcx], 10
    je .parse_sf_iter_done
    mov al, byte [rbx + rcx]
    mov byte [rdi + rcx], al
    inc rcx
    jmp .parse_sf_iter
.parse_sf_iter_done:
    mov byte [rdi + rcx], 0

; Декодируем salt
    lea rdi, [scram_server_salt_b64]
    call strlen
    mov rsi, rax
    lea rdi, [scram_server_salt_b64]
    lea rdx, [scram_server_salt]
    call base64_decode
    mov [scram_server_salt_len], rax

; Конвертируем iterations в число
    lea rdi, [scram_server_iterations]
    call scram_atoi
    mov [scram_server_iter_num], rax

.parse_sf_done:
    LOG_DB scram_step_msg

    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ===========================================================================================
; scram_build_client_final — вычисляет proof и собирает client-final-message
; Предполагает что scram_parse_server_first уже вызван
; Заполняет: scram_client_final_msg
; ===========================================================================================
scram_build_client_final:
    push rdi
    push rsi
    push rdx
    push rcx
    push r8
    push r9
    push rbx

    lea rdi, [db_env_pass]
    call getenv
    mov rbx, rax                       ; rbx = password

; 2. SaltedPassword = PBKDF2(password, salt, iterations)
    mov rdi, rbx
    push rbx
    call strlen
    mov rsi, rax
    pop rbx
    mov rdi, rbx
    lea rdx, [scram_server_salt]
    mov rcx, [scram_server_salt_len]
    mov r8, [scram_server_iter_num]
    lea r9, [scram_salted_password]
    call pbkdf2_sha256

; 3. ClientKey = HMAC(SaltedPassword, "Client Key")
    lea rdi, [scram_salted_password]
    mov rsi, 32
    lea rdx, [scram_client_key_str]
    mov rcx, scram_client_key_str_len
    lea r8, [scram_client_key]
    call hmac_sha256

; 4. StoredKey = SHA256(ClientKey)
    lea rdi, [scram_client_key]
    mov rsi, 32
    lea rdx, [scram_stored_key]
    call sha256

; 5. Собираем client-final-without-proof = "c=biws,r=<server_nonce>"
    lea rdi, [scram_cfwp]
    mov byte [rdi], 0
    lea rsi, [scram_cfwp_prefix]
    call strcat
    lea rdi, [scram_cfwp]
    lea rsi, [scram_server_nonce]
    call strcat

; 6. AuthMessage = client-first-bare + "," + server-first + "," + cfwp
    lea rdi, [scram_auth_msg]
    mov byte [rdi], 0
    lea rsi, [scram_client_first_bare]
    call strcat
    lea rdi, [scram_auth_msg]
    lea rsi, [scram_comma]
    call strcat
    lea rdi, [scram_auth_msg]
    lea rsi, [scram_server_first]
    call strcat
    lea rdi, [scram_auth_msg]
    lea rsi, [scram_comma]
    call strcat
    lea rdi, [scram_auth_msg]
    lea rsi, [scram_cfwp]
    call strcat

; 7. ClientSignature = HMAC(StoredKey, AuthMessage)
    lea rdi, [scram_auth_msg]
    call strlen
    mov rcx, rax
    lea rdi, [scram_stored_key]
    mov rsi, 32
    lea rdx, [scram_auth_msg]
    lea r8, [scram_client_sig]
    call hmac_sha256

; 8. ClientProof = ClientKey XOR ClientSignature
    xor rcx, rcx
.xor_proof:
    mov al, byte [scram_client_key + rcx]
    xor al, byte [scram_client_sig + rcx]
    mov byte [scram_client_proof + rcx], al
    inc rcx
    cmp rcx, 32
    jb .xor_proof

; 9. Base64(ClientProof)
    lea rdi, [scram_client_proof]
    mov rsi, 32
    lea rdx, [scram_client_proof_b64]
    call base64_encode

; 10. client-final = cfwp + ",p=" + base64(proof)
    lea rdi, [scram_client_final_msg]
    mov byte [rdi], 0
    lea rsi, [scram_cfwp]
    call strcat
    lea rdi, [scram_client_final_msg]
    lea rsi, [scram_proof_prefix]
    call strcat
    lea rdi, [scram_client_final_msg]
    lea rsi, [scram_client_proof_b64]
    call strcat

    LOG_DB scram_step_msg

    pop rbx
    pop r9
    pop r8
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    ret
