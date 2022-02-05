; Produced by NeoJasminVisitor (tinapoc)
; http://tinapoc.sourceforge.net
; The original JasminVisitor is part of the BCEL
; http://jakarta.apache.org/bcel/
; Sun Dec 02 00:54:44 JST 2012
 
.bytecode 51.0
.source Hello.java
.class public Hello
.super java/awt/Frame
 
.method public static main([Ljava/lang/String;)V
    .limit stack 3
    .limit locals 2
    .var 0 is arg0 [Ljava/lang/String; from Label0 to Label1
 
    Label0:
.line 6
       0: new Hello
       3: dup
       4: ldc "Hello, World"
       6: invokespecial Hello/<init>(Ljava/lang/String;)V
       9: astore_1
 
    .line 7
      10: aload_1
      11: iconst_1
      12: invokevirtual Hello/setVisible(Z)V
 
    Label1:
.line 8
      15: return
 
.end method
 
.method  <init>(Ljava/lang/String;)V
    .limit stack 4
    .limit locals 3
    .var 0 is this LHello; from Label0 to Label1
    .var 1 is arg0 Ljava/lang/String; from Label0 to Label1
 
    Label0:
.line 11
       0: aload_0
       1: aload_1
       2: invokespecial java/awt/Frame/<init>(Ljava/lang/String;)V
 
    .line 13
       5: aload_0
       6: new java/awt/FlowLayout
       9: dup
      10: iconst_0
      11: invokespecial java/awt/FlowLayout/<init>(I)V
      14: invokevirtual Hello/setLayout(Ljava/awt/LayoutManager;)V
 
    .line 15
      17: new java/awt/Label
      20: dup
      21: ldc "Hello, AWT(Java VM Assembler) World!"
      23: invokespecial java/awt/Label/<init>(Ljava/lang/String;)V
      26: astore_2
 
    .line 16
      27: aload_0
      28: aload_2
      29: invokevirtual Hello/add(Ljava/awt/Component;)Ljava/awt/Component;
      32: pop
 
    .line 18
      33: aload_0
      34: new HelloWindowAdapter
      37: dup
      38: invokespecial HelloWindowAdapter/<init>()V
      41: invokevirtual Hello/addWindowListener(Ljava/awt/event/WindowListener;)V
 
    .line 19
      44: aload_0
      45: sipush 640
      48: sipush 480
      51: invokevirtual Hello/setSize(II)V
 
    Label1:
.line 20
      54: return
 
.end method
