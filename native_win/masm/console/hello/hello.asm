.MODEL flat
EXTRN   _puts:NEAR
_DATA   SEGMENT
msg     DB      'Hello, MASM World!', 0aH, 00H
_DATA   ENDS

_TEXT   SEGMENT

_main   PROC
        push    OFFSET msg
        call    _puts
        add     esp, 4
        xor     eax, eax
        ret     0
_main   ENDP
_TEXT   ENDS
END
