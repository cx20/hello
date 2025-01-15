compile:
```
C:\> cl hello.cpp ^
         /link ^
         user32.lib ^
         gdi32.lib ^
         opengl32.lib ^
         /SUBSYSTEM:WINDOWS
```
Result:
```
                                          
               +--------+                 
             / |      / |                 
            +--------+  |                 
            |  |     |  |                 
            |  +-----|--+                 
            | /      | /                  
            +--------+                    
                                          
```
