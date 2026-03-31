default rel
%include "handlerMac.inc"

section .data
json_not_found:
    db '{"error":"not found"}', 0

section .text
extern HTTP_RESPONSE_NOT_FOUND, HTTP_RESPONSE_NOT_FOUND_LEN
global handler_not_found

handler_not_found:
    SEND_JSON rdi, json_not_found, HTTP_RESPONSE_NOT_FOUND, HTTP_RESPONSE_NOT_FOUND_LEN
    ret
