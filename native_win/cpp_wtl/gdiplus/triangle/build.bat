SET INCLUDE=C:\WTL\WTL10_10320_Release\Include;%INCLUDE%

cl hello.cpp ^
         /link ^
         gdiplus.lib
