; в этом файле просто описыны номера системных вызовов. и сделаны обёртки
default rel

%include "logger.inc"

section .data

read_msg:
    db "Read syscall", 0
socket_msg:
    db "Creating socket", 0
bind_msg:
    db "Binding socket", 0
listen_msg:
    db "Listening on socket", 0
accept_msg:
    db "Accepting connection", 0
connect_msg:
    db "Connecting to socket", 0
close_msg:
    db "Closing file descriptor", 0
setsockopt_msg:
    db "Setting socket options", 0

section .text

global sys_exit
global sys_write
global sys_read

global sys_socket
global sys_bind
global sys_listen
global sys_accept
global sys_close
global sys_setsockopt
global sys_connect
sys_exit:
    mov rax, 60
    syscall

sys_write:
    mov rax, 1
    syscall
    ret

sys_read:
    LOG_SYSCALL read_msg
    mov rax, 0
    syscall
    ret

sys_socket:
    mov rax, 41
    LOG_SYSCALL socket_msg
    syscall
    ret

sys_bind:
    mov rax, 49
    LOG_SYSCALL bind_msg
    syscall
    ret

sys_listen:
    LOG_SYSCALL listen_msg
    mov rax, 50
    syscall
    ret

sys_accept:
    LOG_SYSCALL accept_msg
    mov rax, 43
    syscall
    ret

sys_connect:
    LOG_SYSCALL connect_msg
    mov rax, 42
    syscall
    ret

sys_close:
    LOG_SYSCALL close_msg
    mov rax, 3
    syscall
    ret

sys_setsockopt:
    LOG_SYSCALL setsockopt_msg
    mov r10, rcx
    mov rax, 54
    syscall
    ret
