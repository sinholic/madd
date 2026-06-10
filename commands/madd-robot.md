---
description: "Ship hardware/robot/firmware changes: MQL5 Expert Advisors, Arduino, ESP32, embedded C/C++. Replaces TDD with compile-flash-validate cycle."
argument-hint: "<feature description> [--platform mql5|mql4|arduino|esp32|cpp]"
version: "1.0.0"
changelog: |
  1.0.0 — Initial runbook: platform detection, static analysis, compile, simulate, flash confirmation, hardware validation
---

# Runbook: Ship hardware / robot / firmware

You are executing `/madd-robot`. Feature: **$ARGUMENTS**

Goal: spec → static analysis → compile → simulate (if possible) → flash (manual confirmation) → hardware validate → commit.

**Critical difference from `/madd-ship`:** No automated test runner. Hardware cannot be unit-tested the same way. Validation is manual + simulation where platform supports it.

---

## Step 0 — Pre-flight

`Bash`:
```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" && pwd
git status --short
```

`Read`: `AGENTS.md` if exists — extract `BUILD_CMD`, `DEPLOY_CMD`, `LANGUAGE`.

Parse `$ARGUMENTS` for `--platform <type>`.

If no `--platform` → auto-detect from files:
```bash
find . -maxdepth 5 \( -name "*.mq5" -o -name "*.mq4" -o -name "*.ino" \
  -o -name "CMakeLists.txt" -o -name "platformio.ini" -o -name "idf_component.yml" \) \
  | head -10
```

Map to `PLATFORM`:
- `.mq5` or `.mq4` files → `mql5` or `mql4`
- `.ino` file → `arduino`
- `platformio.ini` or `idf_component.yml` → `esp32`
- `CMakeLists.txt` + no above → `cpp`
- Still unclear → `AskUserQuestion`: "What platform is this for?" → mql5 / mql4 / arduino / esp32 / cpp / other

Store as `PLATFORM`.

---

## Step 1 — Spec (required for all platforms)

Write spec block:

```
**Feature:** <one sentence>
**Platform:** <PLATFORM>
**Hardware target:** <e.g. MetaTrader 5 / Arduino Uno / ESP32-WROOM / STM32F4>
**Acceptance criteria:**
  1. <observable hardware behavior>
  2. ...
**Safety constraints:**
  - <real-time deadline: X ms max latency>
  - <memory budget: X KB RAM>
  - <power budget: X mA>
  - <fail-safe behavior on error>
**Out of scope:** <non-goals>
```

`AskUserQuestion`:
- question: "Spec correct?"
- header: "Spec gate"
- options:
  - "Approved — proceed"
  - "Revise"
  - "Abort"

---

## Step 2 — Static analysis

### 2a. Read source files

`Read` all relevant source files in scope.

### 2b. Real-time constraint check (manual code review)

Check for platform-specific forbidden patterns:

**All platforms:**
- Blocking calls in interrupt handlers / real-time loops
- Dynamic memory allocation (`malloc`, `new`, `delete`) in hot path — flag if heap fragmentation risk
- Integer overflow on counter/timer variables without guard
- Magic numbers for pin/register assignments (should be named constants)
- Uninitialized variables used before assignment

**MQL5/MQL4:**
- `Sleep()` inside `OnTick()` or `OnCalculate()` — blocks MT tick processing
- Unchecked return value on `OrderSend()`, `OrderModify()`, `OrderClose()`
- Missing `ERR_NO_ERROR` / `GetLastError()` check after trade operations
- `ArrayResize()` without error check
- Accessing array index without bounds check
- `iClose()` / `iOpen()` with `shift=0` in `OnTick()` — incomplete bar

**Arduino:**
- `delay()` inside interrupt handler
- `Serial.print()` inside ISR (blocks)
- `millis()` overflow not handled (wraps at ~49 days)
- Long `loop()` blocking WiFi/BLE stack (ESP8266/ESP32 variant)
- Stack allocation of large arrays inside functions (stack overflow)

**ESP32:**
- `vTaskDelay(0)` missing in long tasks (starves IDLE task → watchdog reset)
- `esp_timer_create` callbacks doing heavy work (should be short)
- Partition table mismatch (OTA vs single app)
- Flash write inside ISR
- GPIO reserved for flash/JTAG used as general IO

**C++ embedded:**
- Virtual functions in ISR context
- `std::string` or `std::vector` in ISR (heap allocation)
- RTOS task stack too small for function call depth
- Missing `__attribute__((section(".isr_vector")))` on ISR functions

Report findings inline before continuing.

---

## Step 3 — Compile / build

Run platform-appropriate build:

**MQL5:**
```bash
# If MetaEditor CLI available (Windows + Wine or native)
metaeditor64.exe /compile:<file.mq5> /log
```
If MetaEditor not available: report "Compile step skipped — MetaEditor required. Check manually."

**Arduino:**
```bash
# arduino-cli must be installed
arduino-cli compile --fqbn <board-fqbn> <sketch-directory>
# Common FQBNs: arduino:avr:uno, arduino:avr:mega, esp32:esp32:esp32
```

**ESP32 (ESP-IDF):**
```bash
idf.py build 2>&1 | tail -30
```

**ESP32 (PlatformIO):**
```bash
pio run 2>&1 | tail -30
```

**C++ (CMake):**
```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build 2>&1 | tail -30
```

Compile must succeed. Fix all warnings treated as errors. Fix all errors.

`AskUserQuestion`:
- question: "Compile passed?"
- header: "Compile gate"
- options:
  - "Yes — proceed to simulation"
  - "No — compile errors" → loop back to fix

---

## Step 4 — Simulation (skip if not supported)

### 4a. Check simulator availability

| Platform | Simulator |
|----------|-----------|
| MQL5 | MetaTrader Strategy Tester (backtesting) |
| Arduino | Wokwi (online), SimulIDE |
| ESP32 | Wokwi, QEMU (limited) |
| C++ | Native unit tests if platform-abstracted; otherwise skip |

`AskUserQuestion`:
- question: "Run simulation before flash?"
- header: "Simulate"
- options:
  - "Yes — MQL5 Strategy Tester" (if mql5)
  - "Yes — Wokwi / simulator"
  - "Skip — no simulator available"
  - "Skip — testing on real hardware only"

### 4b. MQL5 Strategy Tester (if applicable)

Instruct user:
```
Strategy Tester steps:
1. Open MetaTrader 5
2. View → Strategy Tester (Ctrl+R)
3. Expert: <EA name>
4. Symbol: <symbol from spec>
5. Date range: cover edge cases in spec
6. Run visual mode first → inspect for unexpected behavior
7. Run optimization if spec requires parameter tuning
```

`AskUserQuestion`:
- "Strategy Tester result?"
- Options:
  - "Passed — behavior matches spec"
  - "Failed — bugs found" → loop back to fix
  - "Skipped"

### 4c. Other simulators

Provide Wokwi link pattern or SimulIDE instructions based on platform. Let user run and report.

---

## Step 5 — Flash / deploy (manual confirmation required)

**Warning block (always shown):**

> **Before flashing:**
> 1. Confirm hardware target matches build target in spec.
> 2. Confirm no live trading / active process on target hardware.
> 3. Confirm backup of current firmware exists (if applicable).
> 4. For MQL5: confirm EA is in testing mode before live account.

`AskUserQuestion`:
- question: "Ready to flash / deploy to hardware?"
- header: "Flash gate"
- options:
  - "Yes — flash now"
  - "No — skip, test simulation only"
  - "Abort"

If "Yes" → provide flash command:

**Arduino:**
```bash
arduino-cli upload -p <PORT> --fqbn <board-fqbn> <sketch-directory>
# PORT: /dev/ttyUSB0 (Linux) or /dev/cu.usbmodem* (Mac) or COM3 (Windows)
```

**ESP32 (IDF):**
```bash
idf.py -p <PORT> flash monitor
```

**ESP32 (PlatformIO):**
```bash
pio run -t upload --upload-port <PORT>
```

**MQL5:**
```
Manual: Copy compiled .ex5 to MetaTrader/MQL5/Experts/. Restart MT5. Attach EA to chart.
```

**C++:**
```bash
# OpenOCD + GDB (most ARM targets)
openocd -f interface/<programmer>.cfg -f target/<mcu>.cfg -c "program build/<binary>.elf verify reset exit"
```

---

## Step 6 — Hardware validation (manual checklist)

`AskUserQuestion`:
- question: "Verify each acceptance criterion on hardware. Results?"
- header: "HW validation"
- options:
  - "All pass"
  - "Some failed — describe"
  - "Unexpected behavior — describe"

Run through spec acceptance criteria one by one. Ask user to confirm each:

```
Checklist:
- [ ] <criterion 1 from spec>
- [ ] <criterion 2>
- [ ] No unintended side effects observed
- [ ] Real-time constraints met (latency within spec)
- [ ] Memory usage within budget
- [ ] Fail-safe behavior tested (unplug power / bad input / edge case)
```

If any fail → loop back to Step 2 with new info.

---

## Step 7 — Commit

### 7a. WORKLOG.md

Append hardware-specific log:
```markdown
## <feature-name> — <ISO-date> [ROBOT]
- Platform: <PLATFORM>
- Hardware tested on: <specific device>
- Real-time constraint validated: <yes/no, measurement>
- Known simulator limitations: <if simulation was skipped or partial>
- Flash method: <command used>
- Non-obvious decisions: <list>
```

### 7b. Commit

```bash
git add <changed-files> WORKLOG.md
git commit -m "feat(<platform>): <feature one-liner>

Hardware validated: <yes/sim-only>
Platform: <PLATFORM>"
```

### 7c. PR / MR

Follow madd-ship Phase 6d platform detection for PR/MR creation.

Add to PR description:
```markdown
## Hardware Notes
- **Platform:** <PLATFORM>
- **Tested on:** <hardware device>
- **Simulation:** <Strategy Tester / Wokwi / none>
- **Flash method:** <how to deploy>
- **Rollback:** <how to restore previous firmware>
```

---

## Commit prefix discipline

| Phase | Prefix |
|-------|--------|
| Static analysis fix | `fix(<platform>):` |
| New feature | `feat(<platform>):` |
| Config / constants | `config(<platform>):` |
| Simulation setup | `test(<platform>):` |

---

## Failure modes

| Symptom | Recovery |
|---------|----------|
| Compile fails (MetaEditor unavailable) | Check .mq5 syntax manually; document as "compile unverified" |
| Flash port not found | `ls /dev/tty*` (Mac/Linux); Device Manager (Windows) |
| Hardware not responding after flash | Wrong board FQBN; verify with `arduino-cli board list` |
| MQL5 EA crashes MT5 | Check journal for error code; use `ExpertRemove()` to detach |
| Real-time constraint violated | Profile with oscilloscope or `micros()`; optimize hot path |
| ESP32 boot loop after flash | Wrong partition table or missing NVS erase; `esptool.py erase_flash` |

---

## Caveats

- Never flash live trading EA to a live account without simulation + paper trading validation first.
- Hardware validation is always manual. Do not claim "tests pass" — claim "validated on hardware."
- Real-time constraints are hard — "it works usually" is not acceptance.
- Keep previous firmware backup before flashing production hardware.
- If platform not supported in this runbook, document manual steps and ask user to confirm each.
