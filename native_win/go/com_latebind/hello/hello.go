package main

import (
    ole "github.com/go-ole/go-ole"
    "github.com/go-ole/go-ole/oleutil"
)

func main() {
    ole.CoInitialize(0)
    defer ole.CoUninitialize()

    unknown, _ := oleutil.CreateObject("Shell.Application")
    shell := unknown.MustQueryInterface(ole.IID_IDispatch)
    defer shell.Release()

    oleutil.MustCallMethod(shell, "BrowseForFolder", 0, "Hello, COM(Go) World!", 0, 36).ToIDispatch()
}