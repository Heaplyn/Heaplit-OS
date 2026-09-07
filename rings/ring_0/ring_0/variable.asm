;Heaplyn, 8/16/26
;Variable Creator
[bits 16]

; -----------------------------
; Variable Type Identifiers (Type Tags)
; -----------------------------
type_null   equ 0
type_bool   equ 1
type_i4     equ 2
type_i8     equ 3
type_i16    equ 4
type_i32    equ 5
type_i64    equ 6
type_int    equ 6   ; 64-bit word in real mode
type_double equ 7
type_string equ 8

; -----------------------------
; Variable Struct Definition
; -----------------------------
struc variable
    .type     resb 1    ; 1 byte: Holds the type_* constant
    .value    resw 1    ; 2 bytes: Holds integer / bool / pointer data
    .pointer  resw 1    ; 2 bytes: Optional extra pointer or buffer offset
    .padding  resb 1    ; 1 byte padding for 16-bit alignment
endstruc

sizeof_variable equ variable_size

; -----------------------------------------------------------------------------
; create_variable: Initializes a typed variable struct in memory.
; Arguments:
;    - DI: Pointer to destination variable struct buffer
;    - AL: Type ID (type_*)
;    - DX: Initial Value (16-bit integer, boolean 0/1, or pointer offset)
; -----------------------------------------------------------------------------
; Usage: create_variable
; -----------------------------------------------------------------------------
create_variable:
    push di

    ; 1. Set the Type Tag
    mov byte [di + variable.type], al
    mov byte [di + variable.padding], 0

    ; 2. Assign the Value
    mov word [di + variable.value], dx
    mov word [di + variable.pointer], 0

    pop di
    ret

add_variables:
    push di

    ; Load the first variable's value
    mov ax, [di + variable.value]
    ; AX now contains the first variable's value
    ; Load the second variable's value (assume it's at DI + sizeof_variable)
    add di, sizeof_variable
    add ax, [di + variable.value]

    ; Store the result back in the first variable
    sub di, sizeof_variable
    mov [di + variable.value], ax

    pop di
    ret