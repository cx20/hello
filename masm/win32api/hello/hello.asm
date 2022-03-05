        TITLE   hello.c
        .686P
        .XMM
        include listing.inc
        .model  flat
 
INCLUDELIB LIBCMT
INCLUDELIB OLDNAMES
 
_DATA   SEGMENT
$SG77810 DB     'Hello, World!', 00H
        ORG $+2
$SG77811 DB     'Hello, Win32 API(MASM) World!', 00H
_DATA   ENDS
PUBLIC  _main
EXTRN   __imp__MessageBoxA@16:PROC
; Function compile flags: /Odtp
_TEXT   SEGMENT
_argc$ = 8                                              ; size = 4
_argv$ = 12                                             ; size = 4
_main   PROC
; File hello.c
; Line 4
        push    ebp
        mov     ebp, esp
; Line 5
        push    0
        push    OFFSET $SG77810
        push    OFFSET $SG77811
        push    0
        call    DWORD PTR __imp__MessageBoxA@16
; Line 6
        xor     eax, eax
; Line 7
        pop     ebp
        ret     0
_main   ENDP
_TEXT   ENDS
END
