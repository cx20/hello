.class public Hello
.super java/lang/Object
 
.method public ()V
   aload_0
   invokespecial java/lang/Object/()V
   return
.end method
 
.method public static main([Ljava/lang/String;)V
   .limit stack 2
   getstatic java/lang/System/out Ljava/io/PrintStream;
   ldc "Hello, Java VM World!"
   invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V
   return
.end method
