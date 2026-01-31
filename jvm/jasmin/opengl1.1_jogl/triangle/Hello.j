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

	.limit stack 8
	.limit locals 19

	aload_1
	invokeinterface	com/jogamp/opengl/GLAutoDrawable/getGL()Lcom/jogamp/opengl/GL;	1	
	invokeinterface	com/jogamp/opengl/GL/getGL2()Lcom/jogamp/opengl/GL2;	1	
	astore_2
	aload_2
	sipush	16384
	invokeinterface	com/jogamp/opengl/GL2/glClear(I)V	2	
	bipush	9
	newarray	float	
	dup
	iconst_0
	fconst_1
	fastore
	dup
	iconst_1
	fconst_0
	fastore
	dup
	iconst_2
	fconst_0
	fastore
	dup
	iconst_3
	fconst_0
	fastore
	dup
	iconst_4
	fconst_1
	fastore
	dup
	iconst_5
	fconst_0
	fastore
	dup
	bipush	6
	fconst_0
	fastore
	dup
	bipush	7
	fconst_0
	fastore
	dup
	bipush	8
	fconst_1
	fastore
	astore_3
	bipush	9
	newarray	float	
	dup
	iconst_0
	fconst_0
	fastore
	dup
	iconst_1
	ldc	0.500000
	fastore
	dup
	iconst_2
	fconst_0
	fastore
	dup
	iconst_3
	ldc	0.500000
	fastore
	dup
	iconst_4
	ldc	-0.500000
	fastore
	dup
	iconst_5
	fconst_0
	fastore
	dup
	bipush	6
	ldc	-0.500000
	fastore
	dup
	bipush	7
	ldc	-0.500000
	fastore
	dup
	bipush	8
	fconst_0
	fastore
	astore 4 
	ldc	"attribute vec3 position;                     \nattribute vec3 color;                        \nvarying   vec4 vColor;                       \nvoid main()                                  \n{                                            \n  vColor = vec4(color, 1.0);                 \n  gl_Position = vec4(position, 1.0);         \n}                                            \n"
	astore 5 
	ldc	"precision mediump float;                     \nvarying   vec4 vColor;                       \nvoid main()                                  \n{                                            \n  gl_FragColor = vColor;                     \n}                                            \n"
	astore 6 
	iconst_2
	newarray	int	
	astore 7 
	aload_2
	iconst_2
	aload 7 
	iconst_0
	invokeinterface	com/jogamp/opengl/GL2/glGenBuffers(I[II)V	4	
	aload 4 
	invokestatic	com/jogamp/common/nio/Buffers/newDirectFloatBuffer([F)Ljava/nio/FloatBuffer;
	astore 8 
	aload_3
	invokestatic	com/jogamp/common/nio/Buffers/newDirectFloatBuffer([F)Ljava/nio/FloatBuffer;
	astore 9 
	aload_2
	ldc	34962
	aload 7 
	iconst_0
	iaload
	invokeinterface	com/jogamp/opengl/GL2/glBindBuffer(II)V	3	
	aload_2
	ldc	34962
	iconst_4
	aload 4 
	arraylength
	imul
	i2l
	aload 8 
	ldc	35044
	invokeinterface	com/jogamp/opengl/GL2/glBufferData(IJLjava/nio/Buffer;I)V	6	
	aload_2
	ldc	34962
	aload 7 
	iconst_1
	iaload
	invokeinterface	com/jogamp/opengl/GL2/glBindBuffer(II)V	3	
	aload_2
	ldc	34962
	iconst_4
	aload_3
	arraylength
	imul
	i2l
	aload 9 
	ldc	35044
	invokeinterface	com/jogamp/opengl/GL2/glBufferData(IJLjava/nio/Buffer;I)V	6	
	aload_2
	ldc	35633
	invokeinterface	com/jogamp/opengl/GL2/glCreateShader(I)I	2	
	istore 10 
	aload_2
	ldc	35632
	invokeinterface	com/jogamp/opengl/GL2/glCreateShader(I)I	2	
	istore 11 
	iconst_1
	anewarray	java/lang/String
	dup
	iconst_0
	aload 5 
	aastore
	astore 12 
	iconst_1
	newarray	int	
	dup
	iconst_0
	aload 12 
	iconst_0
	aaload
	invokevirtual	java/lang/String/length()I
	iastore
	astore 13 
	aload_2
	iload 10 
	iconst_1
	aload 12 
	aload 13 
	iconst_0
	invokeinterface	com/jogamp/opengl/GL2/glShaderSource(II[Ljava/lang/String;[II)V	6	
	aload_2
	iload 10 
	invokeinterface	com/jogamp/opengl/GL2/glCompileShader(I)V	2	
	iconst_1
	anewarray	java/lang/String
	dup
	iconst_0
	aload 6 
	aastore
	astore 14 
	iconst_1
	newarray	int	
	dup
	iconst_0
	aload 14 
	iconst_0
	aaload
	invokevirtual	java/lang/String/length()I
	iastore
	astore 15 
	aload_2
	iload 11 
	iconst_1
	aload 14 
	aload 15 
	iconst_0
	invokeinterface	com/jogamp/opengl/GL2/glShaderSource(II[Ljava/lang/String;[II)V	6	
	aload_2
	iload 11 
	invokeinterface	com/jogamp/opengl/GL2/glCompileShader(I)V	2	
	aload_2
	invokeinterface	com/jogamp/opengl/GL2/glCreateProgram()I	1	
	istore 16 
	aload_2
	iload 16 
	iload 10 
	invokeinterface	com/jogamp/opengl/GL2/glAttachShader(II)V	3	
	aload_2
	iload 16 
	iload 11 
	invokeinterface	com/jogamp/opengl/GL2/glAttachShader(II)V	3	
	aload_2
	iload 16 
	invokeinterface	com/jogamp/opengl/GL2/glLinkProgram(I)V	2	
	aload_2
	iload 16 
	invokeinterface	com/jogamp/opengl/GL2/glUseProgram(I)V	2	
	aload_2
	iload 16 
	ldc	"position"
	invokeinterface	com/jogamp/opengl/GL2/glGetAttribLocation(ILjava/lang/String;)I	3	
	istore 17 
	aload_2
	iload 17 
	invokeinterface	com/jogamp/opengl/GL2/glEnableVertexAttribArray(I)V	2	
	aload_2
	iload 16 
	ldc	"color"
	invokeinterface	com/jogamp/opengl/GL2/glGetAttribLocation(ILjava/lang/String;)I	3	
	istore 18 
	aload_2
	iload 18 
	invokeinterface	com/jogamp/opengl/GL2/glEnableVertexAttribArray(I)V	2	
	aload_2
	ldc	34962
	aload 7 
	iconst_0
	iaload
	invokeinterface	com/jogamp/opengl/GL2/glBindBuffer(II)V	3	
	aload_2
	iload 17 
	iconst_3
	sipush	5126
	iconst_0
	iconst_0
	lconst_0
	invokeinterface	com/jogamp/opengl/GL2/glVertexAttribPointer(IIIZIJ)V	8	
	aload_2
	ldc	34962
	aload 7 
	iconst_1
	iaload
	invokeinterface	com/jogamp/opengl/GL2/glBindBuffer(II)V	3	
	aload_2
	iload 18 
	iconst_3
	sipush	5126
	iconst_0
	iconst_0
	lconst_0
	invokeinterface	com/jogamp/opengl/GL2/glVertexAttribPointer(IIIZIJ)V	8	
	aload_2
	iconst_4
	iconst_0
	iconst_3
	invokeinterface	com/jogamp/opengl/GL2/glDrawArrays(III)V	4	
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
