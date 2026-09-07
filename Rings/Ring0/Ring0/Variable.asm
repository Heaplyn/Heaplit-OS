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
struc Variable
    .Type  resb 1    ; 1 byte: Holds the TYPE_* constant
    .Value  resw 1    ; 2 bytes: Holds integer / bool / pointer data
    .Pointer resw 1    ; 2 bytes: Optional extra pointer or buffer offset
    .Padding      resb 1    ; 1 byte padding for 16-bit alignment
endstruc



; -----------------------------------------------------------------------------
; CreateVariable: Initializes a typed variable struct in memory.
; Arguments:
;    - DI: Pointer to destination VARIABLE struct buffer
;    - AL: Type ID (type_*)
;    - DX: Initial Value (16-bit integer, boolean 0/1, or pointer offset)
; -----------------------------------------------------------------------------
; Usage: CreateVariable
; -----------------------------------------------------------------------------
CreateVariable:
    push di

    ; 1. Set the Type Tag
    mov byte [di + Variable.Type], al
    mov byte [di + Variable.Padding], 0

    ; 2. Assign the Value
    mov word [di + Variable.Value], dx
    mov word [di + Variable.Pointer], 0

    pop di
    ret



AddVariables:
    push di

    ; Load the first variable's value
    mov ax, [di + Variable.Value]
    ; AX now contains the first variable's value
    ; Load the second variable's value (assume it's at DI + Variable.Size)
    add di, sizeof.Variable
    add ax, [di + Variable.Value]

    ; Store the result back in the first variable
    sub di, sizeof.Variable
    mov [di + Variable.Value], ax

    pop di
    ret