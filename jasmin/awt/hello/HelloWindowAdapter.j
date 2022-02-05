; Produced by NeoJasminVisitor (tinapoc)
; http://tinapoc.sourceforge.net
; The original JasminVisitor is part of the BCEL
; http://jakarta.apache.org/bcel/
; Sun Dec 02 00:54:57 JST 2012
 
.bytecode 51.0
.source Hello.java
.class  HelloWindowAdapter
.super java/awt/event/WindowAdapter
 
.method  <init>()V
    .limit stack 1
    .limit locals 1
    .var 0 is this LHelloWindowAdapter; from Label0 to Label1
 
    Label0:
.line 24
       0: aload_0
       1: invokespecial java/awt/event/WindowAdapter/<init>()V
 
    Label1:
       4: return
 
.end method
 
.method public windowClosing(Ljava/awt/event/WindowEvent;)V
    .limit stack 1
    .limit locals 2
    .var 0 is this LHelloWindowAdapter; from Label0 to Label1
    .var 1 is arg0 Ljava/awt/event/WindowEvent; from Label0 to Label1
 
    Label0:
.line 26
       0: iconst_0
       1: invokestatic java/lang/System/exit(I)V
 
    Label1:
.line 27
       4: return
 
.end method
