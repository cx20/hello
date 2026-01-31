; Produced by NeoJasminVisitor (tinapoc)
; http://tinapoc.sourceforge.net
; The original JasminVisitor is part of the BCEL
; http://jakarta.apache.org/bcel/
; Sun Dec 02 01:16:09 JST 2012
 
.bytecode 51.0
.source Hello.java
.class public Hello
.super javax/swing/JFrame
 
.method public static main([Ljava/lang/String;)V
    .limit stack 3
    .limit locals 2
    .var 0 is arg0 [Ljava/lang/String; from Label0 to Label1
 
    Label0:
.line 7
       0: new Hello
       3: dup
       4: ldc "Hello, World"
       6: invokespecial Hello/<init>(Ljava/lang/String;)V
       9: astore_1
 
    .line 8
      10: aload_1
      11: iconst_1
      12: invokevirtual Hello/setVisible(Z)V
 
    Label1:
.line 9
      15: return
 
.end method
 
 
.method  <init>(Ljava/lang/String;)V
    .limit stack 3
    .limit locals 3
    .var 0 is this LHello; from Label0 to Label1
    .var 1 is arg0 Ljava/lang/String; from Label0 to Label1
 
    Label0:
.line 12
       0: aload_0
       1: aload_1
       2: invokespecial javax/swing/JFrame/<init>(Ljava/lang/String;)V
 
    .line 13
       5: aload_0
       6: iconst_3
       7: invokevirtual Hello/setDefaultCloseOperation(I)V
 
    .line 14
      10: aload_0
      11: aconst_null
      12: invokevirtual Hello/setLocationRelativeTo(Ljava/awt/Component;)V
 
    .line 15
      15: aload_0
      16: sipush 640
      19: sipush 480
      22: invokevirtual Hello/setSize(II)V
 
    .line 17
      25: new javax/swing/JLabel
      28: dup
      29: ldc "Hello, Swing(Java VM Assembler) World!"
      31: invokespecial javax/swing/JLabel/<init>(Ljava/lang/String;)V
      34: astore_2
 
    .line 18
      35: aload_2
      36: iconst_1
      37: invokevirtual javax/swing/JLabel/setVerticalAlignment(I)V
 
    .line 19
      40: aload_0
      41: aload_2
      42: invokevirtual Hello/add(Ljava/awt/Component;)Ljava/awt/Component;
      45: pop
 
    Label1:
.line 20
      46: return
 
.end method
