# Sample Outputs

@../CLAUDE.md

Three reference PNGs at distinct frequencies on a steel plate (20 cm × 20 cm × 1 mm). Each PNG has a sidecar `.txt` listing input frequency, matched mode(s), exact resonant frequency, plate parameters, render style, and superposition.

## Files

- `steel_300hz_lines.png` + `.txt` -- mode (1,2), simple cross
- `steel_780hz_shaded.png` + `.txt` -- mode (2,3), 5-cell lattice, magma colormap
- `steel_2460hz_lines.png` + `.txt` -- mode (4,5), dense lattice

## Regenerate

From the parent directory:

```
python chladni.py --frequency 300 --output samples/steel_300hz_lines.png --style lines
python chladni.py --frequency 780 --output samples/steel_780hz_shaded.png --style shaded
python chladni.py --frequency 2460 --output samples/steel_2460hz_lines.png --style lines
```
