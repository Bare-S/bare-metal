extern _print_log
extern strlen
extern PREFIX_INFO
extern PREFIX_ERROR
extern PREFIX_JSON
extern PREFIX_REQUEST
extern PREFIX_DB
extern PREFIX_SYSCALL
extern PREFIX_ENV 

PREFIX_INFO_LEN    equ 16
PREFIX_ERROR_LEN   equ 17
PREFIX_JSON_LEN    equ 16
PREFIX_REQUEST_LEN equ 19
PREFIX_DB_LEN      equ 14
PREFIX_SYSCALL_LEN equ 19
PREFIX_ENV_LEN     equ 20
; %1 = строка для вывода, %2 = функция логирования, %3 = fd (1=stdout, 2=stderr)
%macro LOG 3
    push rax
    push rcx
    push rdx
    push rsi
    push rdi
    push r8
    push r9
    push r10
    push r11

    mov rsi, %1
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rdi, %3
    lea rcx, [%2]
    mov r8, %2 %+ _LEN
    call _print_log

    pop r11
    pop r10
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rax
%endmacro

%macro LOG_INFO 1
    LOG %1, PREFIX_INFO, 1
%endmacro

%macro LOG_ERROR 1
    LOG %1, PREFIX_ERROR, 2
%endmacro

%macro LOG_JSON 1
    LOG %1, PREFIX_JSON, 1
%endmacro

%macro LOG_REQUEST 1
    LOG %1, PREFIX_REQUEST, 1
%endmacro

%macro LOG_DB 1
	LOG %1, PREFIX_DB, 1 
%endmacro

%ifdef SYSCALL_DEBUG
%macro LOG_SYSCALL 1
    push rax
    push rcx
    push rdx
    push rsi
    push rdi
    push r8
    push r9
    push r10
    push r11

    mov rax, 1
    mov rdi, 1
    lea rsi, [PREFIX_SYSCALL]
    mov rdx, PREFIX_SYSCALL_LEN
    syscall

    mov rdi, %1
    call strlen
    mov rdx, rax

    mov rax, 1
    mov rdi, 1
    mov rsi, %1
    syscall

    push 10
    mov rax, 1
    mov rdi, 1
    mov rsi, rsp
    mov rdx, 1
    syscall
    add rsp, 8

    pop r11
    pop r10
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rax
%endmacro
%else
%macro LOG_SYSCALL 1
%endmacro
%endif

%macro LOG_ENV 1
	LOG %1, PREFIX_ENV, 1 
%endmacro
