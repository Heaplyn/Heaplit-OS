; rings/ring_0/variable.asm
; Typed Dynamic Variable System for Heaplit OS (16-bit Real Mode)
[bits 16]                               ; Set assembler target mode to 16-bit Real Mode

; -----------------------------
; Variable Type Identifiers (Type Tags)
; -----------------------------
type_null   equ 0                       ; Execute hardware step
type_bool   equ 1                       ; Execute hardware step
type_i4     equ 2                       ; Execute hardware step
type_i8     equ 3                       ; Execute hardware step
type_i16    equ 4                       ; Execute hardware step
type_i32    equ 5                       ; Execute hardware step
type_i64    equ 6                       ; Execute hardware step
type_int    equ 6                       ;Default integer alias
type_double equ 7                       ; Execute hardware step
type_string equ 8                       ; Execute hardware step

; -----------------------------
; Variable Struct Definition (6 bytes aligned)
; -----------------------------
struc variable                          ; Execute hardware step
    .type     resb 1                    ;1 byte: Holds the type_* constant
    .value    resw 1                    ;2 bytes: Holds integer / bool / data
    .pointer  resw 1                    ;2 bytes: Optional pointer or string buffer offset
    .padding  resb 1                    ;1 byte padding for 16-bit alignment
endstruc                                ; Execute hardware step

sizeof_variable equ variable_size       ; Execute hardware step

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
    push di                             ;Push DI register onto memory stack
    mov byte [di + variable.type], al   ; Move value into target register/memory
    mov byte [di + variable.padding], 0 ; Move value into target register/memory
    mov word [di + variable.value], dx  ; Move value into target register/memory
    mov word [di + variable.pointer], 0 ; Move value into target register/memory
    pop di                              ;Pop top stack value into DI register
    ret                                 ;Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; create_string_variable: Initializes a type_string variable with string pointer.
; Inputs:
;   DI = Pointer to destination variable struct buffer
;   SI = Pointer to null-terminated string buffer
; Preserved:
;   DI, SI
; -----------------------------------------------------------------------------
create_string_variable:
    push di                             ;Push DI register onto memory stack
    mov byte [di + variable.type], type_string ; Move value into target register/memory
    mov byte [di + variable.padding], 0 ; Move value into target register/memory
    mov word [di + variable.value], 0   ; Move value into target register/memory
    mov word [di + variable.pointer], si ; Move value into target register/memory
    pop di                              ;Pop top stack value into DI register
    ret                                 ;Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; get_variable_value: Reads value field from variable at DI.
; Returns: AX = Value
; -----------------------------------------------------------------------------
get_variable_value:
    mov ax, [di + variable.value]       ; Move value into target register/memory
    ret                                 ;Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; set_variable_value: Writes value field into variable at DI.
; Inputs: AX = Value
; -----------------------------------------------------------------------------
set_variable_value:
    mov [di + variable.value], ax       ; Move value into target register/memory
    ret                                 ;Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; get_variable_type: Reads type field from variable at DI.
; Returns: AL = Type ID
; -----------------------------------------------------------------------------
get_variable_type:
    mov al, byte [di + variable.type]   ; Move value into target register/memory
    ret                                 ;Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; copy_variable: Deep copies a variable struct from SI to DI.
; Inputs: DI = Destination, SI = Source
; -----------------------------------------------------------------------------
copy_variable:
    push di                             ;Push DI register onto memory stack
    push si                             ;Push SI register onto memory stack
    push cx                             ;Push CX register onto memory stack
    mov cx, sizeof_variable             ; Set cx = sizeof_variable
    rep movsb                           ;Repeat MOVSB to copy string bytes from RSI to RDI
    pop cx                              ;Pop top stack value into CX register
    pop si                              ;Pop top stack value into SI register
    pop di                              ;Pop top stack value into DI register
    ret                                 ;Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; compare_variables: Compares values of variables at DI and SI.
; Returns: Flags set according to cmp AX, BX
; -----------------------------------------------------------------------------
compare_variables:
    push ax                             ;Push AX register onto memory stack
    push bx                             ;Push BX register onto memory stack
    mov ax, [di + variable.value]       ; Move value into target register/memory
    mov bx, [si + variable.value]       ; Move value into target register/memory
    cmp ax, bx                          ; Execute hardware step
    pop bx                              ;Pop top stack value into BX register
    pop ax                              ;Pop top stack value into AX register
    ret                                 ;Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; add_variables: Adds value of variable at SI to variable at DI.
; Inputs: DI = Destination variable, SI = Source variable
; -----------------------------------------------------------------------------
add_variables:
    push ax                             ;Push AX register onto memory stack
    mov ax, [si + variable.value]       ; Move value into target register/memory
    add [di + variable.value], ax       ; Execute hardware step
    pop ax                              ;Pop top stack value into AX register
    ret                                 ;Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; sub_variables: Subtracts value of variable at SI from variable at DI.
; Inputs: DI = Destination variable, SI = Source variable
; -----------------------------------------------------------------------------
sub_variables:
    push ax                             ;Push AX register onto memory stack
    mov ax, [si + variable.value]       ; Move value into target register/memory
    sub [di + variable.value], ax       ; Execute hardware step
    pop ax                              ;Pop top stack value into AX register
    ret                                 ;Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; mul_variables: Multiplies variable at DI by variable at SI.
; Inputs: DI = Destination variable, SI = Source variable
; -----------------------------------------------------------------------------
mul_variables:
    push ax                             ;Push AX register onto memory stack
    push bx                             ;Push BX register onto memory stack
    push dx                             ;Push DX register onto memory stack
    mov ax, [di + variable.value]       ; Move value into target register/memory
    mov bx, [si + variable.value]       ; Move value into target register/memory
    mul bx                              ;AX = AX * BX
    mov [di + variable.value], ax       ; Move value into target register/memory
    pop dx                              ;Pop top stack value into DX register
    pop bx                              ;Pop top stack value into BX register
    pop ax                              ;Pop top stack value into AX register
    ret                                 ;Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; div_variables: Divides variable at DI by variable at SI.
; Inputs: DI = Destination variable, SI = Source variable
; -----------------------------------------------------------------------------
div_variables:
    push ax                             ;Push AX register onto memory stack
    push bx                             ;Push BX register onto memory stack
    push dx                             ;Push DX register onto memory stack
    mov bx, [si + variable.value]       ; Move value into target register/memory
    test bx, bx                         ; Test base register for zero
    jz .div_zero                        ; Branch to '.div_zero' if Zero Flag is set (ZF=1)
    mov ax, [di + variable.value]       ; Move value into target register/memory
    xor dx, dx                          ;Zero out DX register
    div bx                              ;AX = quotient, DX = remainder
    mov [di + variable.value], ax       ; Move value into target register/memory
.div_zero:
    pop dx                              ;Pop top stack value into DX register
    pop bx                              ;Pop top stack value into BX register
    pop ax                              ;Pop top stack value into AX register
    ret                                 ;Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; print_variable: Formatted display of variable according to its .type.
; Inputs: DI = Pointer to variable struct
; -----------------------------------------------------------------------------
print_variable:
    pusha                               ; Push all 16-bit general purpose registers (AX, CX, DX, BX, SP, BP, SI, DI) onto stack
    mov al, byte [di + variable.type]   ; Move value into target register/memory

    cmp al, type_null                   ; Execute hardware step
    je .print_null                      ; Branch to '.print_null' if Zero Flag is set (ZF=1)
    cmp al, type_bool                   ; Execute hardware step
    je .print_bool                      ; Branch to '.print_bool' if Zero Flag is set (ZF=1)
    cmp al, type_string                 ; Execute hardware step
    je .print_string                    ; Branch to '.print_string' if Zero Flag is set (ZF=1)

    ; Default: Numeric integer output
    mov ax, [di + variable.value]       ; Move value into target register/memory
    mov di, .num_buf                    ; Move value into target register/memory
    call int_to_string                  ; Call subroutine 'int_to_string'
    mov si, .num_buf                    ; Move value into target register/memory
    call print_string_16                ; Call subroutine 'print_string_16'
    jmp .done                           ;Unconditional jump to target label .done

.print_null:
    mov si, .str_null                   ; Move value into target register/memory
    call print_string_16                ; Call subroutine 'print_string_16'
    jmp .done                           ;Unconditional jump to target label .done

.print_bool:
    mov ax, [di + variable.value]       ; Move value into target register/memory
    test ax, ax                         ; Test accumulator register for zero / error status
    jz .bool_false                      ; Branch to '.bool_false' if Zero Flag is set (ZF=1)
    mov si, .str_true                   ; Move value into target register/memory
    call print_string_16                ; Call subroutine 'print_string_16'
    jmp .done                           ;Unconditional jump to target label .done
.bool_false:
    mov si, .str_false                  ; Move value into target register/memory
    call print_string_16                ; Call subroutine 'print_string_16'
    jmp .done                           ;Unconditional jump to target label .done

.print_string:
    mov si, [di + variable.pointer]     ; Move value into target register/memory
    call print_string_16                ; Call subroutine 'print_string_16'
    jmp .done                           ;Unconditional jump to target label .done

.done:
    popa                                ; Restore all 16-bit general purpose registers from stack
    ret                                 ;Return control to caller instruction pointer

.str_null:   db '<null>', 0             ; Execute hardware step
.str_true:   db 'true', 0               ; Execute hardware step
.str_false:  db 'false', 0              ; Execute hardware step
.num_buf:    times 8 db 0               ; Execute hardware step
