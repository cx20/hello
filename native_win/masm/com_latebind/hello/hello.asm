	TITLE	hello.c
	.686P
	.XMM
	include listing.inc
	.model	flat

INCLUDELIB LIBCMT
INCLUDELIB OLDNAMES

PUBLIC	_main
EXTRN	__imp__GetUserDefaultLCID@0:PROC
EXTRN	__imp__CoUninitialize@0:PROC
EXTRN	__imp__CoCreateInstance@20:PROC
EXTRN	__imp__CLSIDFromProgID@8:PROC
EXTRN	__imp__CoInitialize@4:PROC
EXTRN	__imp__SysAllocString@4:PROC
EXTRN	__imp__VariantInit@4:PROC
EXTRN	_GUID_NULL:BYTE
EXTRN	_IID_IDispatch:BYTE
_DATA	SEGMENT
$SG73423 DB	'B', 00H, 'r', 00H, 'o', 00H, 'w', 00H, 's', 00H, 'e', 00H
	DB	'F', 00H, 'o', 00H, 'r', 00H, 'F', 00H, 'o', 00H, 'l', 00H, 'd'
	DB	00H, 'e', 00H, 'r', 00H, 00H, 00H
$SG73424 DB	'S', 00H, 'h', 00H, 'e', 00H, 'l', 00H, 'l', 00H, '.', 00H
	DB	'A', 00H, 'p', 00H, 'p', 00H, 'l', 00H, 'i', 00H, 'c', 00H, 'a'
	DB	00H, 't', 00H, 'i', 00H, 'o', 00H, 'n', 00H, 00H, 00H
$SG73425 DB	'H', 00H, 'e', 00H, 'l', 00H, 'l', 00H, 'o', 00H, ',', 00H
	DB	' ', 00H, 'C', 00H, 'O', 00H, 'M', 00H, '(', 00H, 'M', 00H, 'A'
	DB	00H, 'S', 00H, 'M', 00H, ')', 00H, ' ', 00H, 'W', 00H, 'o', 00H
	DB	'r', 00H, 'l', 00H, 'd', 00H, '!', 00H, 00H, 00H
_DATA	ENDS
; Function compile flags: /Odtp
_TEXT	SEGMENT
_varg$ = -128						; size = 64
_vResult$ = -64						; size = 16
_clsid$ = -48						; size = 16
_param$ = -32						; size = 16
_dispid$ = -16						; size = 4
_ptName$ = -12						; size = 4
_pFolder$ = -8						; size = 4
_pShell$ = -4						; size = 4
_argc$ = 8						; size = 4
_argv$ = 12						; size = 4
_main	PROC
; File hello.c
; Line 4
	push	ebp
	mov	ebp, esp
	sub	esp, 128				; 00000080H
; Line 9
	mov	DWORD PTR _ptName$[ebp], OFFSET $SG73423
; Line 10
	mov	DWORD PTR _param$[ebp], 0
	mov	DWORD PTR _param$[ebp+4], 0
	mov	DWORD PTR _param$[ebp+8], 0
	mov	DWORD PTR _param$[ebp+12], 0
; Line 14
	push	0
	call	DWORD PTR __imp__CoInitialize@4
; Line 16
	lea	eax, DWORD PTR _clsid$[ebp]
	push	eax
	push	OFFSET $SG73424
	call	DWORD PTR __imp__CLSIDFromProgID@8
; Line 17
	lea	ecx, DWORD PTR _pShell$[ebp]
	push	ecx
	push	OFFSET _IID_IDispatch
	push	1
	push	0
	lea	edx, DWORD PTR _clsid$[ebp]
	push	edx
	call	DWORD PTR __imp__CoCreateInstance@20
; Line 18
	lea	eax, DWORD PTR _dispid$[ebp]
	push	eax
	call	DWORD PTR __imp__GetUserDefaultLCID@0
	push	eax
	push	1
	lea	ecx, DWORD PTR _ptName$[ebp]
	push	ecx
	push	OFFSET _GUID_NULL
	mov	edx, DWORD PTR _pShell$[ebp]
	push	edx
	mov	eax, DWORD PTR _pShell$[ebp]
	mov	ecx, DWORD PTR [eax]
	mov	edx, DWORD PTR [ecx+20]
	call	edx
; Line 20
	mov	eax, 16					; 00000010H
	imul	ecx, eax, 0
	lea	edx, DWORD PTR _varg$[ebp+ecx]
	push	edx
	call	DWORD PTR __imp__VariantInit@4
; Line 21
	mov	eax, 16					; 00000010H
	imul	ecx, eax, 0
	mov	edx, 3
	mov	WORD PTR _varg$[ebp+ecx], dx
; Line 22
	mov	eax, 16					; 00000010H
	imul	ecx, eax, 0
	mov	DWORD PTR _varg$[ebp+ecx+8], 36		; 00000024H
; Line 24
	mov	edx, 16					; 00000010H
	shl	edx, 0
	lea	eax, DWORD PTR _varg$[ebp+edx]
	push	eax
	call	DWORD PTR __imp__VariantInit@4
; Line 25
	mov	ecx, 16					; 00000010H
	shl	ecx, 0
	mov	edx, 3
	mov	WORD PTR _varg$[ebp+ecx], dx
; Line 26
	mov	eax, 16					; 00000010H
	shl	eax, 0
	mov	DWORD PTR _varg$[ebp+eax+8], 0
; Line 28
	mov	ecx, 16					; 00000010H
	shl	ecx, 1
	lea	edx, DWORD PTR _varg$[ebp+ecx]
	push	edx
	call	DWORD PTR __imp__VariantInit@4
; Line 29
	mov	eax, 16					; 00000010H
	shl	eax, 1
	mov	ecx, 8
	mov	WORD PTR _varg$[ebp+eax], cx
; Line 30
	push	OFFSET $SG73425
	call	DWORD PTR __imp__SysAllocString@4
	mov	edx, 16					; 00000010H
	shl	edx, 1
	mov	DWORD PTR _varg$[ebp+edx+8], eax
; Line 32
	mov	eax, 16					; 00000010H
	imul	ecx, eax, 3
	lea	edx, DWORD PTR _varg$[ebp+ecx]
	push	edx
	call	DWORD PTR __imp__VariantInit@4
; Line 33
	mov	eax, 16					; 00000010H
	imul	ecx, eax, 3
	mov	edx, 3
	mov	WORD PTR _varg$[ebp+ecx], dx
; Line 34
	mov	eax, 16					; 00000010H
	imul	ecx, eax, 3
	mov	DWORD PTR _varg$[ebp+ecx+8], 0
; Line 36
	mov	DWORD PTR _param$[ebp+8], 4
; Line 37
	lea	edx, DWORD PTR _varg$[ebp]
	mov	DWORD PTR _param$[ebp], edx
; Line 39
	push	0
	push	0
	lea	eax, DWORD PTR _vResult$[ebp]
	push	eax
	lea	ecx, DWORD PTR _param$[ebp]
	push	ecx
	push	1
	call	DWORD PTR __imp__GetUserDefaultLCID@0
	push	eax
	push	OFFSET _GUID_NULL
	mov	edx, DWORD PTR _dispid$[ebp]
	push	edx
	mov	eax, DWORD PTR _pShell$[ebp]
	push	eax
	mov	ecx, DWORD PTR _pShell$[ebp]
	mov	edx, DWORD PTR [ecx]
	mov	eax, DWORD PTR [edx+24]
	call	eax
; Line 41
	mov	ecx, 16					; 00000010H
	imul	edx, ecx, 0
	lea	eax, DWORD PTR _varg$[ebp+edx]
	push	eax
	call	DWORD PTR __imp__VariantInit@4
; Line 42
	mov	ecx, 16					; 00000010H
	shl	ecx, 0
	lea	edx, DWORD PTR _varg$[ebp+ecx]
	push	edx
	call	DWORD PTR __imp__VariantInit@4
; Line 43
	mov	eax, 16					; 00000010H
	shl	eax, 1
	lea	ecx, DWORD PTR _varg$[ebp+eax]
	push	ecx
	call	DWORD PTR __imp__VariantInit@4
; Line 44
	mov	edx, 16					; 00000010H
	imul	eax, edx, 3
	lea	ecx, DWORD PTR _varg$[ebp+eax]
	push	ecx
	call	DWORD PTR __imp__VariantInit@4
; Line 46
	mov	edx, DWORD PTR _vResult$[ebp+8]
	mov	DWORD PTR _pFolder$[ebp], edx
; Line 47
	cmp	DWORD PTR _pFolder$[ebp], 0
	je	SHORT $LN2@main
; Line 49
	mov	eax, DWORD PTR _pFolder$[ebp]
	push	eax
	mov	ecx, DWORD PTR _pFolder$[ebp]
	mov	edx, DWORD PTR [ecx]
	mov	eax, DWORD PTR [edx+8]
	call	eax
	npad	1
$LN2@main:
; Line 51
	mov	ecx, DWORD PTR _pShell$[ebp]
	push	ecx
	mov	edx, DWORD PTR _pShell$[ebp]
	mov	eax, DWORD PTR [edx]
	mov	ecx, DWORD PTR [eax+8]
	call	ecx
; Line 53
	call	DWORD PTR __imp__CoUninitialize@0
; Line 55
	xor	eax, eax
; Line 56
	mov	esp, ebp
	pop	ebp
	ret	0
_main	ENDP
_TEXT	ENDS
END
