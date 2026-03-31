default rel
%include "logger.inc"

section .bss
    logger_buf resb 256                ; Буфер для логирования информации о маршрутах

section .data

space:
    db " ", 0

section .text
extern strcmp, strcat
global route_request               ; (rdi: указатель на метод, rsi: указатель на путь, rdx: дескриптор клиента, rcx: длина запроса, r8: указатель на таблицу маршрутов) => (rax: 0 если маршрут найден и обработчик вызван, -1 если маршрут не найден)

route_request:
; Сохранение аргументов в регистрах для дальнейшего использования
    push r13
    push r14
    push r15
    push rbx
    push r12
; callee-saved регистры: rbx, r13-r15

    mov r14, rdi                       ; Cохранение указателя на метод в r14
    mov r15, rsi                       ; Сохранение указателя на путь в r15
    mov r13, rdx
    mov r12, rcx                       ; Сохранение длины запроса в r12

    mov rbx, r8                        ; Указатель на таблицу маршрутизации из аргумента

.check:
    mov r9, [rbx]                      ; Загрузка метода из таблицы
    cmp r9, 0                          ; Проверка на конец таблицы маршрутизации
    je .method_not_found               ; Если достигнут конец таблицы, маршрут не найден

    mov rdi, r14                       ; Установка аргумента для strcmp (метод)
    mov rsi, r9                        ; Установка аргумента для strcmp (метод из таблицы)
    call strcmp                        ; Сравнение метода
    cmp rax, 0                         ; Проверка результата сравнения
    je .method_found                   ; Если методы совпали, проверяем путь

    add rbx, 24                        ; Переход к следующей записи в таблице
    jmp .check                         ; Переход к следующей записи в таблице

.method_not_found:
    call _log_err                      ; Логирование ошибки о не найденном маршруте

    mov rax, -1                        ; Возвращаем -1, если маршрут не найден
    jmp .done

.method_found:
    mov rdi , r15                      ; Установка аргумента для strcmp (путь)
    mov rsi, [rbx + 8]                 ; Установка аргумента для
    call strcmp                        ; Сравнение пути
    cmp rax, 0                         ; Проверка результата сравнения
    je .route_found                    ; Если путь совпал, вызываем обработчик

    add rbx, 24                        ; Переход к следующей записи в таблице
    jmp .check

.route_found:

; логирование маршрута
    call _log_route

    mov rdi, r13                       ; Установка аргумента для обработчика (дескриптор клиента)
    mov rsi, r12                       ; Установка аргумента для обработчика (длина запроса)
    mov rax, [rbx + 16]                ; Загрузка указателя на обработчик

    call rax                           ; Вызов обработчика
    jmp .done

.done:
    pop r12
    pop rbx
    pop r15
    pop r14
    pop r13
; возвращаем значния
    ret

; Собирает строку "METHOD /path" в logger_buf
_build_log_msg:
    lea rdi, [logger_buf]
    mov byte [rdi], 0                  ; Обнуляем буфер

    lea rdi, [logger_buf]
    mov rsi, r14                       ; Метод
    call strcat

    lea rdi, [logger_buf]
    mov rsi, space                     ; Пробел
    call strcat

    lea rdi, [logger_buf]
    mov rsi, r15                       ; Путь
    call strcat
    ret

_log_route:
    call _build_log_msg
    LOG_REQUEST logger_buf
    ret

_log_err:
    call _build_log_msg
    LOG_ERROR logger_buf
    ret
