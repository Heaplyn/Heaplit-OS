; rings/ring_0/variable.asm
; Typed Dynamic Variable System for Heaplit OS (16-bit Real Mode)
[bits 16]                               ; Execute instruction

; -----------------------------
; Variable Type Identifiers (Type Tags)
; -----------------------------
type_null   equ 0                       ; Execute instruction
type_bool   equ 1                       ; Execute instruction
type_i4     equ 2                       ; Execute instruction
type_i8     equ 3                       ; Execute instruction
type_i16    equ 4                       ; Execute instruction
type_i32    equ 5                       ; Execute instruction
type_i64    equ 6                       ; Execute instruction
type_int    equ 6                       ; Default integer alias
type_double equ 7                       ; Execute instruction
type_string equ 8                       ; Execute instruction

; -----------------------------
; Variable Struct Definition (6 bytes aligned)
; -----------------------------
struc variable                          ; Execute instruction
    .type     resb 1                    ; 1 byte: Holds the type_* constant
    .value    resw 1                    ; 2 bytes: Holds integer / bool / data
    .pointer  resw 1                    ; 2 bytes: Optional pointer or string buffer offset
    .padding  resb 1                    ; 1 byte padding for 16-bit alignment
endstruc                                ; Execute instruction

sizeof_variable equ variable_size       ; Execute instruction

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
    push di                             ; Push DI register onto memory stack
    mov byte [di + variable.type], al   ; Execute instruction
    mov byte [di + variable.padding], 0 ; Execute instruction
    mov word [di + variable.value], dx  ; Execute instruction
    mov word [di + variable.pointer], 0 ; Execute instruction
    pop di                              ; Pop top stack value into DI register
    ret                                 ; Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; create_string_variable: Initializes a type_string variable with string pointer.
; Inputs:
;   DI = Pointer to destination variable struct buffer
;   SI = Pointer to null-terminated string buffer
; Preserved:
;   DI, SI
; -----------------------------------------------------------------------------
create_string_variable:
    push di                             ; Push DI register onto memory stack
    mov byte [di + variable.type], type_string ; Execute instruction
    mov byte [di + variable.padding], 0 ; Execute instruction
    mov word [di + variable.value], 0   ; Execute instruction
    mov word [di + variable.pointer], si ; Execute instruction
    pop di                              ; Pop top stack value into DI register
    ret                                 ; Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; get_variable_value: Reads value field from variable at DI.
; Returns: AX = Value
; -----------------------------------------------------------------------------
get_variable_value:
    mov ax, [di + variable.value]       ; Execute instruction
    ret                                 ; Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; set_variable_value: Writes value field into variable at DI.
; Inputs: AX = Value
; -----------------------------------------------------------------------------
set_variable_value:
    mov [di + variable.value], ax       ; Execute instruction
    ret                                 ; Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; get_variable_type: Reads type field from variable at DI.
; Returns: AL = Type ID
; -----------------------------------------------------------------------------
get_variable_type:
    mov al, byte [di + variable.type]   ; Execute instruction
    ret                                 ; Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; copy_variable: Deep copies a variable struct from SI to DI.
; Inputs: DI = Destination, SI = Source
; -----------------------------------------------------------------------------
copy_variable:
    push di                             ; Push DI register onto memory stack
    push si                             ; Push SI register onto memory stack
    push cx                             ; Push CX register onto memory stack
    mov cx, sizeof_variable             ; Copy value from sizeof_variable to cx
    rep movsb                           ; Repeat MOVSB to copy string bytes from RSI to RDI
    pop cx                              ; Pop top stack value into CX register
    pop si                              ; Pop top stack value into SI register
    pop di                              ; Pop top stack value into DI register
    ret                                 ; Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; compare_variables: Compares values of variables at DI and SI.
; Returns: Flags set according to cmp AX, BX
; -----------------------------------------------------------------------------
compare_variables:
    push ax                             ; Push AX register onto memory stack
    push bx                             ; Push BX register onto memory stack
    mov ax, [di + variable.value]       ; Execute instruction
    mov bx, [si + variable.value]       ; Execute instruction
    cmp ax, bx                          ; Compare ax with bx and update CPU EFLAGS
    pop bx                              ; Pop top stack value into BX register
    pop ax                              ; Pop top stack value into AX register
    ret                                 ; Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; add_variables: Adds value of variable at SI to variable at DI.
; Inputs: DI = Destination variable, SI = Source variable
; -----------------------------------------------------------------------------
add_variables:
    push ax                             ; Push AX register onto memory stack
    mov ax, [si + variable.value]       ; Execute instruction
    add [di + variable.value], ax       ; Execute instruction
    pop ax                              ; Pop top stack value into AX register
    ret                                 ; Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; sub_variables: Subtracts value of variable at SI from variable at DI.
; Inputs: DI = Destination variable, SI = Source variable
; -----------------------------------------------------------------------------
sub_variables:
    push ax                             ; Push AX register onto memory stack
    mov ax, [si + variable.value]       ; Execute instruction
    sub [di + variable.value], ax       ; Execute instruction
    pop ax                              ; Pop top stack value into AX register
    ret                                 ; Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; mul_variables: Multiplies variable at DI by variable at SI.
; Inputs: DI = Destination variable, SI = Source variable
; -----------------------------------------------------------------------------
mul_variables:
    push ax                             ; Push AX register onto memory stack
    push bx                             ; Push BX register onto memory stack
    push dx                             ; Push DX register onto memory stack
    mov ax, [di + variable.value]       ; Execute instruction
    mov bx, [si + variable.value]       ; Execute instruction
    mul bx                              ; AX = AX * BX
    mov [di + variable.value], ax       ; Execute instruction
    pop dx                              ; Pop top stack value into DX register
    pop bx                              ; Pop top stack value into BX register
    pop ax                              ; Pop top stack value into AX register
    ret                                 ; Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; div_variables: Divides variable at DI by variable at SI.
; Inputs: DI = Destination variable, SI = Source variable
; -----------------------------------------------------------------------------
div_variables:
    push ax                             ; Push AX register onto memory stack
    push bx                             ; Push BX register onto memory stack
    push dx                             ; Push DX register onto memory stack
    mov bx, [si + variable.value]       ; Execute instruction
    test bx, bx                         ; Execute instruction
    jz .div_zero                        ; Jump to .div_zero if condition 'z' is met
    mov ax, [di + variable.value]       ; Execute instruction
    xor dx, dx                          ; Zero out DX register
    div bx                              ; AX = quotient, DX = remainder
    mov [di + variable.value], ax       ; Execute instruction
.div_zero:
    pop dx                              ; Pop top stack value into DX register
    pop bx                              ; Pop top stack value into BX register
    pop ax                              ; Pop top stack value into AX register
    ret                                 ; Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; print_variable: Formatted display of variable according to its .type.
; Inputs: DI = Pointer to variable struct
; -----------------------------------------------------------------------------
print_variable:
    pusha                               ; Execute instruction
    mov al, byte [di + variable.type]   ; Execute instruction

    cmp al, type_null                   ; Compare al with type_null and update CPU EFLAGS
    je .print_null                      ; Jump to .print_null if condition 'e' is met
    cmp al, type_bool                   ; Compare al with type_bool and update CPU EFLAGS
    je .print_bool                      ; Jump to .print_bool if condition 'e' is met
    cmp al, type_string                 ; Compare al with type_string and update CPU EFLAGS
    je .print_string                    ; Jump to .print_string if condition 'e' is met

    ; Default: Numeric integer output
    mov ax, [di + variable.value]       ; Execute instruction
    mov di, .num_buf                    ; Execute instruction
    call int_to_string                  ; Execute instruction
    mov si, .num_buf                    ; Execute instruction
    call print_string_16                ; Execute instruction
    jmp .done                           ; Unconditional jump to target label .done

.print_null:
    mov si, .str_null                   ; Execute instruction
    call print_string_16                ; Execute instruction
    jmp .done                           ; Unconditional jump to target label .done

.print_bool:
    mov ax, [di + variable.value]       ; Execute instruction
    test ax, ax                         ; Execute instruction
    jz .bool_false                      ; Jump to .bool_false if condition 'z' is met
    mov si, .str_true                   ; Execute instruction
    call print_string_16                ; Execute instruction
    jmp .done                           ; Unconditional jump to target label .done
.bool_false:
    mov si, .str_false                  ; Execute instruction
    call print_string_16                ; Execute instruction
    jmp .done                           ; Unconditional jump to target label .done

.print_string:
    mov si, [di + variable.pointer]     ; Execute instruction
    call print_string_16                ; Execute instruction
    jmp .done                           ; Unconditional jump to target label .done

.done:
    popa                                ; Execute instruction
    ret                                 ; Return control to caller instruction pointer

.str_null:   db '<null>', 0             ; Execute instruction
.str_true:   db 'true', 0               ; Execute instruction
.str_false:  db 'false', 0              ; Execute instruction
.num_buf:    times 8 db 0               ; Execute instruction
