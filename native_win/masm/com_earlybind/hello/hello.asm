	TITLE	hello.c
	.686P
	.XMM
	include listing.inc
	.model	flat
 
INCLUDELIB LIBCMT
INCLUDELIB OLDNAMES
 
_DATA	SEGMENT
$SG113507 DB	'H', 00H, 'e', 00H, 'l', 00H, 'l', 00H, 'o', 00H, ',', 00H
	DB	' ', 00H, 'C', 00H, 'O', 00H, 'M', 00H, '(', 00H, 'M', 00H, 'A'
	DB	00H, 'S', 00H, 'M', 00H, ')', 00H, ' ', 00H, 'W', 00H, 'o', 00H
	DB	'r', 00H, 'l', 00H, 'd', 00H, '!', 00H, 00H, 00H
_DATA	ENDS
PUBLIC	_main
EXTRN	__imp__CoUninitialize@0:PROC
EXTRN	__imp__CoCreateInstance@20:PROC
EXTRN	_CLSID_Shell:BYTE
EXTRN	_IID_IShellDispatch:BYTE
EXTRN	__imp__CoInitialize@4:PROC
; Function compile flags: /Odtp
_TEXT	SEGMENT
_pFolder$ = -36						; size = 4
_vRootFolder$ = -32					; size = 16
_folder$ = -12						; size = 4
_pShell$ = -4						; size = 4
_argc$ = 8						; size = 4
_argv$ = 12						; size = 4
_main	PROC
; File hello.c
; Line 4
        push    ebp
        mov     ebp, esp
        sub     esp, 36                                 ; 00000024H
; Line 11
        push    0
        call    DWORD PTR __imp__CoInitialize@4
; Line 13
        lea     eax, DWORD PTR _pShell$[ebp]
        push    eax
        push    OFFSET _IID_IShellDispatch
        push    1
        push    0
        push    OFFSET _CLSID_Shell
        call    DWORD PTR __imp__CoCreateInstance@20
; Line 15
        mov     ecx, 3
        mov     WORD PTR _vRootFolder$[ebp], cx
; Line 16
        mov     DWORD PTR _vRootFolder$[ebp+8], 36      ; 00000024H
; Line 17
        lea     edx, DWORD PTR _folder$[ebp]
        mov     DWORD PTR _pFolder$[ebp], edx
; Line 19
        lea     eax, DWORD PTR _pFolder$[ebp]
        push    eax
        sub     esp, 16                                 ; 00000010H
        mov     ecx, esp
        mov     edx, DWORD PTR _vRootFolder$[ebp]
        mov     DWORD PTR [ecx], edx
        mov     eax, DWORD PTR _vRootFolder$[ebp+4]
        mov     DWORD PTR [ecx+4], eax
        mov     edx, DWORD PTR _vRootFolder$[ebp+8]
        mov     DWORD PTR [ecx+8], edx
        mov     eax, DWORD PTR _vRootFolder$[ebp+12]
        mov     DWORD PTR [ecx+12], eax
        push    0
        push    OFFSET $SG113507
        push    0
        mov     ecx, DWORD PTR _pShell$[ebp]
        push    ecx
        mov     edx, DWORD PTR _pShell$[ebp]
        mov     eax, DWORD PTR [edx]
        mov     ecx, DWORD PTR [eax+40]
        call    ecx
; Line 20
        cmp     DWORD PTR _pFolder$[ebp], 0
        je      SHORT $LN1@main
; Line 22
        mov     edx, DWORD PTR _pFolder$[ebp]
        push    edx
        mov     eax, DWORD PTR _pFolder$[ebp]
        mov     ecx, DWORD PTR [eax]
        mov     edx, DWORD PTR [ecx+8]
        call    edx
$LN1@main:
; Line 24
        mov     eax, DWORD PTR _pShell$[ebp]
        push    eax
        mov     ecx, DWORD PTR _pShell$[ebp]
        mov     edx, DWORD PTR [ecx]
        mov     eax, DWORD PTR [edx+8]
        call    eax
; Line 26
        call    DWORD PTR __imp__CoUninitialize@0
; Line 28
        xor     eax, eax
; Line 29
        mov     esp, ebp
        pop     ebp
        ret     0
_main   ENDP
_TEXT   ENDS
END
