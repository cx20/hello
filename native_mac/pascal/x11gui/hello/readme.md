# Hello, World! in Pascal + X11 GUI

This sample demonstrates a simple "Hello, World!" GUI application in Free Pascal using X11 (XQuartz on macOS).

## Requirements

- XQuartz: https://www.xquartz.org/
- Free Pascal (fpc)
  ```
  brew install fpc
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
| Hello, X11 GUI(Pascal) World!            |
|                                          |
+------------------------------------------+
```

## Notes

- Requires XQuartz on macOS
- `run.sh` starts XQuartz automatically if needed
- `run.sh` defaults `DISPLAY` to `:0` when unset
- If needed, set `X11_PREFIX` before running `build.sh`
