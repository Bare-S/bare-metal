default rel
%include "handlerMac.inc"

extern HTTP_RESPONSE_OK, HTTP_RESPONSE_OK_LEN

section .data
health_json:
    db '{"status":"ok"}', 0

section .text
global handler_health

handler_health:
    SEND_JSON rdi, health_json, HTTP_RESPONSE_OK, HTTP_RESPONSE_OK_LEN
    ret
