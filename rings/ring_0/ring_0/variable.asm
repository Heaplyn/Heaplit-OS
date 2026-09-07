; rings/ring_0/ring_0/variable.asm
; Typed Dynamic Variable System for Heaplit OS (16-bit Real Mode)
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
type_int    equ 6   ; Default integer alias
type_double equ 7
type_string equ 8

; -----------------------------
; Variable Struct Definition (6 bytes aligned)
; -----------------------------
struc variable
    .type     resb 1    ; 1 byte: Holds the type_* constant
    .value    resw 1    ; 2 bytes: Holds integer / bool / data
    .pointer  resw 1    ; 2 bytes: Optional pointer or string buffer offset
    .padding  resb 1    ; 1 byte padding for 16-bit alignment
endstruc

sizeof_variable equ variable_size

; -----------------------------------------------------------------------------
; create_variable: Initializes a typed variable struct in memory.
; Inputs:
;   DI = Pointer to destination variable struct buffer
;   AL = Type ID (type_*)
;   DX = Initial Value (16-bit integer, boolean 0/1, or pointer offset)
; Preserved:
;   DI, BX, CX, DX
; -----------------------------------------------------------------------------
create_variable:
    push di
    mov byte [di + variable.type], al
    mov byte [di + variable.padding], 0
    mov word [di + variable.value], dx
    mov word [di + variable.pointer], 0
    pop di
    ret

; -----------------------------------------------------------------------------
; create_string_variable: Initializes a type_string variable with string pointer.
; Inputs:
;   DI = Pointer to destination variable struct buffer
;   SI = Pointer to null-terminated string buffer
; Preserved:
;   DI, SI
; -----------------------------------------------------------------------------
create_string_variable:
    push di
    mov byte [di + variable.type], type_string
    mov byte [di + variable.padding], 0
    mov word [di + variable.value], 0
    mov word [di + variable.pointer], si
    pop di
    ret

; -----------------------------------------------------------------------------
; get_variable_value: Reads value field from variable at DI.
; Returns: AX = Value
; -----------------------------------------------------------------------------
get_variable_value:
    mov ax, [di + variable.value]
    ret

; -----------------------------------------------------------------------------
; set_variable_value: Writes value field into variable at DI.
; Inputs: AX = Value
; -----------------------------------------------------------------------------
set_variable_value:
    mov [di + variable.value], ax
    ret

; -----------------------------------------------------------------------------
; get_variable_type: Reads type field from variable at DI.
; Returns: AL = Type ID
; -----------------------------------------------------------------------------
get_variable_type:
    mov al, byte [di + variable.type]
    ret

; -----------------------------------------------------------------------------
; copy_variable: Deep copies a variable struct from SI to DI.
; Inputs: DI = Destination, SI = Source
; -----------------------------------------------------------------------------
copy_variable:
    push di
    push si
    push cx
    mov cx, sizeof_variable
    rep movsb
    pop cx
    pop si
    pop di
    ret

; -----------------------------------------------------------------------------
; compare_variables: Compares values of variables at DI and SI.
; Returns: Flags set according to cmp AX, BX
; -----------------------------------------------------------------------------
compare_variables:
    push ax
    push bx
    mov ax, [di + variable.value]
    mov bx, [si + variable.value]
    cmp ax, bx
    pop bx
    pop ax
    ret

; -----------------------------------------------------------------------------
; add_variables: Adds value of variable at SI to variable at DI.
; Inputs: DI = Destination variable, SI = Source variable
; -----------------------------------------------------------------------------
add_variables:
    push ax
    mov ax, [si + variable.value]
    add [di + variable.value], ax
    pop ax
    ret

; -----------------------------------------------------------------------------
; sub_variables: Subtracts value of variable at SI from variable at DI.
; Inputs: DI = Destination variable, SI = Source variable
; -----------------------------------------------------------------------------
sub_variables:
    push ax
    mov ax, [si + variable.value]
    sub [di + variable.value], ax
    pop ax
    ret

; -----------------------------------------------------------------------------
; mul_variables: Multiplies variable at DI by variable at SI.
; Inputs: DI = Destination variable, SI = Source variable
; -----------------------------------------------------------------------------
mul_variables:
    push ax
    push bx
    push dx
    mov ax, [di + variable.value]
    mov bx, [si + variable.value]
    mul bx                      ; AX = AX * BX
    mov [di + variable.value], ax
    pop dx
    pop bx
    pop ax
    ret

; -----------------------------------------------------------------------------
; div_variables: Divides variable at DI by variable at SI.
; Inputs: DI = Destination variable, SI = Source variable
; -----------------------------------------------------------------------------
div_variables:
    push ax
    push bx
    push dx
    mov bx, [si + variable.value]
    test bx, bx
    jz .div_zero
    mov ax, [di + variable.value]
    xor dx, dx
    div bx                      ; AX = quotient, DX = remainder
    mov [di + variable.value], ax
.div_zero:
    pop dx
    pop bx
    pop ax
    ret

; -----------------------------------------------------------------------------
; print_variable: Formatted display of variable according to its .type.
; Inputs: DI = Pointer to variable struct
; -----------------------------------------------------------------------------
print_variable:
    pusha
    mov al, byte [di + variable.type]

    cmp al, type_null
    je .print_null
    cmp al, type_bool
    je .print_bool
    cmp al, type_string
    je .print_string

    ; Default: Numeric integer output
    mov ax, [di + variable.value]
    mov di, .num_buf
    call int_to_string
    mov si, .num_buf
    call print_string_16
    jmp .done

.print_null:
    mov si, .str_null
    call print_string_16
    jmp .done

.print_bool:
    mov ax, [di + variable.value]
    test ax, ax
    jz .bool_false
    mov si, .str_true
    call print_string_16
    jmp .done
.bool_false:
    mov si, .str_false
    call print_string_16
    jmp .done

.print_string:
    mov si, [di + variable.pointer]
    call print_string_16
    jmp .done

.done:
    popa
    ret

.str_null:   db '<null>', 0
.str_true:   db 'true', 0
.str_false:  db 'false', 0
.num_buf:    times 8 db 0