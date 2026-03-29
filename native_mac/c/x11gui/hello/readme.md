compile:
```
$ sh build.sh
```
run:
```
$ sh run.sh
```
Result:
```
+------------------------------------------+
|Hello, World!                    [_][~][X]|
+------------------------------------------+
|                                          |
| Hello, X11 GUI World!                    |
|                                          |
+------------------------------------------+
```

Notes:
- Requires XQuartz on macOS
- `run.sh` starts XQuartz automatically if needed
- `run.sh` defaults `DISPLAY` to `:0` when unset
- If needed, set `X11_PREFIX` before running `build.sh`
