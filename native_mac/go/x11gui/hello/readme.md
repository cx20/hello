# Hello, World! in Go + X11 GUI

This sample demonstrates a simple "Hello, World!" GUI application in Go using X11 (XQuartz on macOS) via CGo.

## Requirements

- XQuartz: https://www.xquartz.org/
- Go
  ```
  brew install go
  ```

## Build

```bash
sh build.sh
```

## Run

```bash
sh run.sh
```

## Result

```
+------------------------------------------+
|Hello, World!                    [_][~][X]|
+------------------------------------------+
|                                          |
| Hello, X11 GUI(Go) World!                |
|                                          |
+------------------------------------------+
```

## Notes

- Requires XQuartz on macOS
- `run.sh` starts XQuartz automatically if needed
- `run.sh` defaults `DISPLAY` to `:0` when unset
- If needed, set `X11_PREFIX` before running `build.sh`
