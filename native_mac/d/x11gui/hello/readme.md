# Hello, World! in D + X11 GUI

This sample demonstrates a simple "Hello, World!" GUI application in D using X11 (XQuartz on macOS).

## Requirements

- XQuartz: https://www.xquartz.org/
- D compiler: `dmd`, `ldc2`, or `gdc`
  ```
  brew install dmd
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
| Hello, X11 GUI(D) World!                 |
|                                          |
+------------------------------------------+
```

## Notes

- Requires XQuartz on macOS
- `run.sh` starts XQuartz automatically if needed
- `run.sh` defaults `DISPLAY` to `:0` when unset
- If needed, set `X11_PREFIX` before running `build.sh`
