# Chladni Pattern Generator

A single-file Python script that takes an input frequency (Hz) plus plate parameters and renders the Chladni nodal pattern that frequency would excite. The pattern comes from solving thin-plate vibration equations — no image generation, no stylistic faking.

## Install

```
pip install numpy matplotlib scipy
```

Python 3.10+ recommended (uses union types in annotations).

## Run

### Static PNG generator

```
python chladni.py --frequency 780 --output out.png
python chladni.py --shape circle --frequency 600 --radius 0.10 --style shaded --output disk.png
python chladni.py --self-test    # verifies free-edge circular eigenvalues
```

Each PNG is accompanied by a sidecar `.txt` listing the input frequency, the matched mode(s) with their exact resonant frequencies and weights, and the plate parameters used. Open the sidecar to verify what you are looking at.

### Reactive browser interface

Open `web/index.html` directly in a browser (it ships with the mode bank inlined; no server needed). Or serve it locally:

```
python -m http.server  # from this directory, then visit /web/
```

The web UI has live frequency/Q/intensity sliders, on/off (animates pattern flatten/resolve), shape and style pickers, a Lorentzian mode-mixing kernel for soft snapping, and tick marks at every mode peak on the slider. To regenerate the mode bank for different default plate parameters, edit the constants at the top of `build_web.py` and run `python build_web.py`.

## Three example invocations

These produce the PNGs in `samples/`. All on a steel plate of kitchen-experiment dimensions (20 cm × 20 cm × 1 mm). Each frequency is chosen to land cleanly on a single mode with no neighboring modes inside the ±2% match tolerance.

```
python chladni.py --frequency 300  --output samples/steel_300hz_lines.png   --style lines
python chladni.py --frequency 780  --output samples/steel_780hz_shaded.png  --style shaded
python chladni.py --frequency 2460 --output samples/steel_2460hz_lines.png  --style lines
```

| Frequency | Mode  | Visual                     |
|-----------|-------|----------------------------|
| 300 Hz    | (1,2) | clean antidiagonal + arcs  |
| 780 Hz    | (2,3) | five-cell shaded lattice   |
| 2460 Hz   | (4,5) | dense diagonal-wave nodal  |

## What is exact and what is approximate

### Square plate — approximate

The closed-form

```
f_{nm} = (π·h / (2·L²)) · sqrt(E / (12·ρ·(1−ν²))) · (n² + m²)
```

and the nodal field

```
ψ(x, y) = cos(n·π·x/L)·cos(m·π·y/L) ± cos(m·π·x/L)·cos(n·π·y/L)
```

are exact for a *simply-supported* square plate (zero displacement and zero bending moment along the edges). They are an *approximation* for a *free-edge* square plate — the boundary condition that actually applies to a Chladni demonstration. The real free-edge spectrum involves a numerical eigenvalue solve and differs from the closed form by edge-correction terms that this script does not compute.

The patterns produced are still recognizable as Chladni-style nodal lines and approximately correct for the lower modes; the closed form drifts further from reality as `n + m` grows.

### Circular plate — exact (within thin-plate theory)

For circular plates the script does the actual free-edge boundary-value problem from Kirchhoff–Love thin-plate theory:

```
M_r = 0  at r = R   (radial bending moment)
V_r = 0  at r = R   (Kirchhoff effective shear)
```

This yields a transcendental eigenvalue equation in `λ = k·R`, solved numerically by sign-change bracketing on a fine grid plus `scipy.optimize.brentq`. After applying the Bessel ODEs to eliminate higher derivatives, the four boundary-condition entries reduce to:

```
M_J = -(1−ν)·λ·J_n'(λ) − (λ² − n²·(1−ν))·J_n(λ)
M_I = -(1−ν)·λ·I_n'(λ) + (λ² + n²·(1−ν))·I_n(λ)
V_J = -λ·[λ² + n²·(1−ν)]·J_n'(λ) + n²·(1−ν)·J_n(λ)
V_I =  λ·[λ² − n²·(1−ν)]·I_n'(λ) + n²·(1−ν)·I_n(λ)
```

The frequency equation is `M_J·V_I − M_I·V_J = 0`. For numerical stability at large λ, `exp(−λ)` is factored out of the I_n terms via `scipy.special.ive`.

Mode shape:
```
ψ_{n,m}(r, θ) = [J_n(λ_{n,m}·r/R) + α·I_n(λ_{n,m}·r/R)] · cos(n·θ)
```
with α determined by `M_r = 0` at the boundary.

The first seven computed eigenvalues for ν = 1/3 match Leissa's *Vibration of Plates* (NASA SP-160, 1969) Table 4.10 to within 0.5 %. Run `python chladni.py --self-test` to verify.

### What the script does *not* model

- Damping. Real plates have finite Q; nearby modes get blended at any drive frequency. The script approximates this by including all candidate modes within a configurable ±tolerance band, weighted by inverse frequency distance, but the weights are heuristic, not derived from a damping model.
- Anisotropy or material variation across the plate.
- Drive-point effects. The actual nodal pattern depends on where the plate is driven; the script renders the ideal mode-shape geometry, which is the symmetric envelope of all possible drive points.
- Nonlinear effects at large amplitude.
- Out-of-plane (extensional) modes. Only flexural (bending) modes.
- Sand dynamics. Real Chladni figures are the steady-state distribution of sand grains on nodal lines; the script renders the mathematical zero set, which is the limit of zero amplitude / infinite settling time.

## Mode matching

For an input frequency `f_target`:

1. Enumerate candidate modes up to a cutoff (default n,m ≤ 20 for square; n ≤ 12, m ≤ 8 for circular).
2. Compute `f_{nm}` for each.
3. Always include the closest mode by `|f_{nm} − f_target|`.
4. Additionally include any modes within `±tolerance` (default 2 %) of `f_target`.
5. Weight each selected mode by `1 / |f_{nm} − f_target|`, normalize to sum to 1.
6. Evaluate ψ as the weighted sum.

If you want a single dominant mode, use a frequency that lands on it cleanly (no neighbors in the band) — the three sample frequencies above were chosen this way. To see mode mixing, pick a frequency *between* two modes (e.g., 540 Hz on this steel plate, which sits between (1,3) at 600 Hz and (1,2) at 300 Hz, but neither is in the ±2 % band; widen `--tolerance` to mix them).

## CLI flags

| Flag              | Default     | Notes                                        |
|-------------------|-------------|----------------------------------------------|
| `--frequency`     | (required)  | Hz                                           |
| `--output`        | `chladni_<freq>hz.png` | PNG path. Sidecar `.txt` is written alongside |
| `--shape`         | `square`    | `square` or `circle`                         |
| `--side-length`   | `0.20`      | Square side, meters                          |
| `--radius`        | `0.10`      | Disk radius, meters                          |
| `--thickness`     | `0.001`     | Plate thickness, meters                      |
| `--material`      | `steel`     | `steel`, `aluminum`, `brass`, `glass`        |
| `--E --rho --nu`  |             | Override material constants individually      |
| `--superposition` | `+`         | Square only: `+`, `-`, or `both`             |
| `--style`         | `lines`     | `lines` (zero-contour) or `shaded` (\|ψ\| with magma colormap) |
| `--resolution`    | `800`       | Grid resolution per axis                     |
| `--max-mode`      | `20`        | Square enumeration cutoff                    |
| `--tolerance`     | `0.02`      | Fractional tolerance for mode-match band     |
| `--self-test`     |             | Verify circular eigenvalues against Leissa Table 4.10 and exit |

## Material presets

| Material  | E (GPa) | ρ (kg/m³) | ν     |
|-----------|---------|-----------|-------|
| steel     | 200     | 7850      | 0.30  |
| aluminum  |  69     | 2700      | 0.33  |
| brass     | 110     | 8500      | 0.34  |
| glass     |  70     | 2500      | 0.22  |

Override any of the three for non-preset materials (e.g., `--material steel --rho 7800` for a specific steel grade).

## References

- Leissa, A. W. *Vibration of Plates.* NASA SP-160, 1969. Table 4.10 anchors the verification of the free-edge circular plate eigenvalues.
- Kirchhoff, G. *Über das Gleichgewicht und die Bewegung einer elastischen Scheibe.* Crelle's Journal 40 (1850).
- Chladni, E. F. F. *Entdeckungen über die Theorie des Klanges.* Leipzig, 1787.
