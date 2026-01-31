;/* Class file Hello.class version 52.0 */
.source	Hello.java

.class	public synchronized Hello
.super	java/lang/Object
.implements com/jogamp/opengl/GLEventListener


.method	public <init>()V

	.limit stack 1
	.limit locals 1

	aload_0
	invokespecial	java/lang/Object/<init>()V
	return

.end method

.method	public init(Lcom/jogamp/opengl/GLAutoDrawable;)V

	.limit stack 0
	.limit locals 2

	return

.end method

.method	public display(Lcom/jogamp/opengl/GLAutoDrawable;)V

	.limit stack 4
	.limit locals 3

	aload_1
	invokeinterface	com/jogamp/opengl/GLAutoDrawable/getGL()Lcom/jogamp/opengl/GL;	1	
	invokeinterface	com/jogamp/opengl/GL/getGL2()Lcom/jogamp/opengl/GL2;	1	
	astore_2
	aload_2
	sipush	16384
	invokeinterface	com/jogamp/opengl/GL2/glClear(I)V	2	
	aload_2
	iconst_4
	invokeinterface	com/jogamp/opengl/GL2/glBegin(I)V	2	
	aload_2
	fconst_1
	fconst_0
	fconst_0
	invokeinterface	com/jogamp/opengl/GL2/glColor3f(FFF)V	4	
	aload_2
	fconst_0
	ldc	0.500000
	invokeinterface	com/jogamp/opengl/GL2/glVertex2f(FF)V	3	
	aload_2
	fconst_0
	fconst_1
	fconst_0
	invokeinterface	com/jogamp/opengl/GL2/glColor3f(FFF)V	4	
	aload_2
	ldc	0.500000
	ldc	-0.500000
	invokeinterface	com/jogamp/opengl/GL2/glVertex2f(FF)V	3	
	aload_2
	fconst_0
	fconst_0
	fconst_1
	invokeinterface	com/jogamp/opengl/GL2/glColor3f(FFF)V	4	
	aload_2
	ldc	-0.500000
	ldc	-0.500000
	invokeinterface	com/jogamp/opengl/GL2/glVertex2f(FF)V	3	
	aload_2
	invokeinterface	com/jogamp/opengl/GL2/glEnd()V	1	
	return

.end method

.method	public dispose(Lcom/jogamp/opengl/GLAutoDrawable;)V

	.limit stack 0
	.limit locals 2

	return

.end method

.method	public reshape(Lcom/jogamp/opengl/GLAutoDrawable;IIII)V

	.limit stack 0
	.limit locals 6

	return

.end method

.method	public static main([Ljava/lang/String;)V

	.limit stack 3
	.limit locals 6

	ldc	"GL2"
	invokestatic	com/jogamp/opengl/GLProfile/get(Ljava/lang/String;)Lcom/jogamp/opengl/GLProfile;
	astore_1
	new	com/jogamp/opengl/GLCapabilities
	dup
	aload_1
	invokespecial	com/jogamp/opengl/GLCapabilities/<init>(Lcom/jogamp/opengl/GLProfile;)V
	astore_2
	new	com/jogamp/opengl/awt/GLCanvas
	dup
	aload_2
	invokespecial	com/jogamp/opengl/awt/GLCanvas/<init>(Lcom/jogamp/opengl/GLCapabilitiesImmutable;)V
	astore_3
	new	Hello
	dup
	invokespecial	Hello/<init>()V
	astore 4 
	aload_3
	aload 4 
	invokevirtual	com/jogamp/opengl/awt/GLCanvas/addGLEventListener(Lcom/jogamp/opengl/GLEventListener;)V
	aload_3
	sipush	640
	sipush	480
	invokevirtual	com/jogamp/opengl/awt/GLCanvas/setSize(II)V
	new	javax/swing/JFrame
	dup
	ldc	"Hello, World!"
	invokespecial	javax/swing/JFrame/<init>(Ljava/lang/String;)V
	astore 5 
	aload 5 
	invokevirtual	javax/swing/JFrame/getContentPane()Ljava/awt/Container;
	aload_3
	invokevirtual	java/awt/Container/add(Ljava/awt/Component;)Ljava/awt/Component;
	pop
	aload 5 
	aload 5 
	invokevirtual	javax/swing/JFrame/getContentPane()Ljava/awt/Container;
	invokevirtual	java/awt/Container/getPreferredSize()Ljava/awt/Dimension;
	invokevirtual	javax/swing/JFrame/setSize(Ljava/awt/Dimension;)V
	aload 5 
	iconst_3
	invokevirtual	javax/swing/JFrame/setDefaultCloseOperation(I)V
	aload 5 
	iconst_1
	invokevirtual	javax/swing/JFrame/setVisible(Z)V
	return

.end method
