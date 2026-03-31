extern CONTENT_TYPE_JSON, CONTENT_TYPE_JSON_LEN
extern send_response

; %1 - сокет, %2 - json, %3 - статус, %4 - длина статуса
%macro SEND_JSON 4
	mov rdi, %1
	lea rsi, [%2]
	lea rdx, [%3]
	mov rcx, [%4]
	lea r8, [CONTENT_TYPE_JSON]
	mov r9, [CONTENT_TYPE_JSON_LEN]
	call send_response
%endmacro
