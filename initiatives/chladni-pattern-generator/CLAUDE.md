# Chladni Pattern Generator

@../CLAUDE.md

Side software project: a Python script that takes an input frequency (Hz) plus plate parameters and renders the Chladni nodal pattern that frequency would excite on the plate.

## Files

- `chladni.py` -- single-file CLI script (numpy + matplotlib + scipy)
- `README.md` -- install + example invocations + physics-assumptions note
- `samples/` -- three reference PNGs at distinct frequencies on a steel kitchen-plate
- `build_web.py` -- generates the web UI's `data.js` mode bank
- `web/` -- reactive browser UI (canvas, sliders, on/off, soft mode snap)

## Physics summary

- **Square plate:** closed-form free-edge approximation `f_{nm} = (π·h / (2·L²)) · sqrt(E / (12·ρ·(1-ν²))) · (n² + m²)`. Nodal field `ψ = cos(nπx/L)cos(mπy/L) ± cos(mπx/L)cos(nπy/L)`.
- **Circular plate:** actual free-edge Kirchhoff-Love boundary-value problem (`M_r = 0`, `V_r = 0` at `r = R`). Transcendental eigenvalue equation in `λ = kR` solved numerically; mode shape `[J_n(λr/R) + α·I_n(λr/R)]·cos(nθ)`. Verified against Leissa, *Vibration of Plates* (NASA SP-160, 1969), Table 4.10.

## Run

```
python chladni.py --frequency 300 --output samples/steel_300hz_lines.png --style lines
python chladni.py --self-test    # verifies circular eigenvalues against Leissa
open web/index.html              # reactive browser UI (no server needed)
```
