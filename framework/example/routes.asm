default rel

section .data

; Методы HTTP
method_get:
    db 'GET', 0


; Пути
path_health:
    db '/health', 0

; Таблица маршрутизации: метод, путь, обработчик
; Каждая запись занимает 24 байта: 8 байт на метод, 8 байт на путь, 8 байт на указатель на обработчик
global route_table
route_table:
    dq method_get, path_health, handler_health
    dq 0, 0, 0                         ; Конец таблицы маршрутизации

section .text
extern handler_health
