# Chladni Web UI — QA Checklist

**Tester:**
**Date:**
**Browser / OS:**
**Initial URL hash (paste here if non-default):**

---

## How to fill this out

After each item is `→`. Write your feedback inline. Conventions:
- **leave blank** = fine, no comment
- `ok` = explicitly checked and working
- `polish: <what>` = works but feels off; describe
- `broken: <what>` = doesn't work; describe
- `wrong: <what>` = works but the result is incorrect; describe
- anything else = free-form note

Reference items by ID (`H6`, `Q4`) when we iterate.

---

## 0. First impressions (free-form, before anything else)

- Overall feel (1–10):
- One thing that landed well:
- One thing that fell flat:
- Top 3 priorities to fix first (by ID):
  1.
  2.
  3.

---

## A · Header & navigation

A1. Brand mark icon (small orange swirl, top-left, 22×22 SVG) →
A2. Brand text "CHLADNI / cymatic mode explorer" →
A3. Snapshot/save icon button (top-right, ↓ glyph) →
A4. About icon button (top-right, ⓘ glyph, opens Wikipedia) →
A5. Header bottom divider →

## B · Background & page chrome

B1. Dark background with subtle radial gradients (warm top, cool bottom) →
B2. SVG noise texture overlay (very faint film grain) →
B3. Page width / max-width / breathing room →
B4. Vertical rhythm between sections →

## C · Plate canvas

C1. Plate renders cleanly at viewport size →
C2. Rounded corners on plate →
C3. Warm bloom around plate when DRIVING →
C4. Bloom fades when PAUSED →
C5. 3D tilt as cursor moves over plate →
C6. Tilt resets when cursor leaves →
C7. Plate background color (when no pattern, e.g., off + lines mode) →

## D · Plate overlay (corner labels)

D1. Mode label `(n,m)` bottom-left, monospace →
D2. Frequency under mode label (Hz) →
D3. LOCKED badge top-right appears only when freq is locked tightly to a peak →
D4. LOCKED badge styling →
D5. Overlay opacity (faded by default, full on hover) →

## E · Render: Lines style

E1. Zero-contour lines render correctly (warm white) →
E2. Soft glow underneath each line →
E3. Lines fade in/out smoothly with DRIVING toggle →
E4. Line thickness / antialiasing →

## F · Render: Shaded style

F1. Magma colormap on `|ψ|` →
F2. Brightness scales with Intensity slider →
F3. Auto-normalization per frame (always uses full magma range) →
F4. Outside-disk masked dark in circle mode →

## G · Render: Sand style

G1. ~4000 sand-colored particles render →
G2. Particles migrate to nodal lines while DRIVING →
G3. Particles drift back to random when PAUSED →
G4. Asymmetric crystallize/decay timing feels right (fast settle, slow decay) →
G5. Boundary handling (no grain escape past plate edge) →
G6. Particle visual density / size / color →
G7. Performance / frame rate →

## H · Frequency control

H1. Big freq display upper-left of slider section (e.g., "1916 Hz") →
H2. Frequency slider drags smoothly across full range →
H3. Slider thumb hover/active states (turns orange, scales up) →
H4. Tick marks on tick canvas at every mode peak (faint gray verticals) →
H5. Current frequency highlighted as orange tick →
H6. Click on tick canvas snaps freq to nearest mode →
H7. Hover tick canvas shows mode tooltip with `(n,m)` and Hz →
H8. Tooltip positioning (centered above tick) →
H9. Min / max bounds labels below slider →

## I · Active mode readout

I1. Dominant mode `(n,m) · f_nm Hz · weight%` shown next to freq display →
I2. Updates live as you drag →
I3. Secondary mode shown when its weight >10% →
I4. Color turns orange when locked tightly to a peak →

## J · Driver button (DRIVING / PAUSED)

J1. Button text matches state ("DRIVING" / "PAUSED") →
J2. Pulsing orange dot when DRIVING →
J3. Click toggles smoothly with on/off animation visible on plate →

## K · Audio system

K1. Audio toggle button shows AUDIO / SILENT →
K2. First click starts the sine oscillator at slider freq →
K3. Audio frequency follows slider in real time →
K4. Gain tracks `intensity × amplitude` (fades on PAUSE) →
K5. Audio button styling (orange border when on) →
K6. Pleasant/clean tone (no clicks, pops, drift) →

## L · Shape picker (segmented)

L1. Square option works →
L2. Circle option works →
L3. Switching shape redraws ticks and freq range →
L4. Symmetry control hides on circle →
L5. Active state styling →

## M · Render style picker (segmented)

M1. Lines / Shaded / Sand all selectable →
M2. Active state highlighted →
M3. Transitions between styles don't flicker badly →

## N · Symmetry +/− (square only)

N1. + and − produce visibly different patterns →
N2. Hidden on circle (per L4) →
N3. Diagonal modes (n=m) with − handled gracefully →

## O · Sharpness (Q) slider

O1. Range 5–200, current numeric value displayed live →
O2. Low Q (5–10) visibly mixes neighboring modes →
O3. High Q (100+) confines to dominant mode sharply →
O4. Slider feel →

## P · Intensity slider

P1. Percentage display (0–100%) →
P2. Affects Shaded brightness →
P3. Affects Sand particle alpha →
P4. Affects audio gain →
P5. Note: doesn't affect Lines style. Should it? →

## Q · Plate properties panel (collapsible)

Q1. Panel collapses/expands; arrow rotates →
Q2. Summary line shows current material × dimensions →
Q3. Material picker (Steel / Aluminum / Brass / Glass) →
Q4. Switching material rescales frequencies live (brass much lower, etc.) →
Q5. Side / diameter slider (0.05–0.50 m) →
Q6. Thickness slider (0.1–5 mm) →
Q7. Numeric values next to each slider update live →
Q8. Hint text legibility →

## R · Footer

R1. Plate config meta string (left) →
R2. Keyboard shortcuts legend with kbd styling (right) →

## S · Keyboard shortcuts

S1. Space toggles DRIVING →
S2. ← / → steps to adjacent mode peak →
S3. ↑ / ↓ adjusts Q (±5 per press) →
S4. S cycles render style (lines→shaded→sand) →
S5. M cycles plate shape (square↔circle) →
S6. A toggles audio →
S7. D saves PNG →
S8. Shortcuts don't intercept typing in non-range inputs →

## T · URL state persistence

T1. URL hash updates as you interact (visible in address bar) →
T2. Reloading the page restores all state →
T3. Pasting the URL elsewhere shows the same view →

## U · PNG snapshot / export

U1. D key triggers download →
U2. Snapshot icon button (top-right) works →
U3. Filename includes shape, frequency, style →
U4. Image is the current frame, no UI chrome captured →
U5. Image quality (1024×1024 backing) →

## V · Physics correctness (cross-check vs CLI / known modes)

V1. 300 Hz steel square → mode (1,2): clean antidiagonal + corner arcs →
V2. 1916 Hz steel square → mode (4,4): 4×4 grid →
V3. 780 Hz steel square → mode (2,3): five-cell lattice →
V4. Switching to circle at ~130 Hz → saddle (n=2, m=0) →
V5. Brass plate rings noticeably lower than steel at same dims →
V6. Smaller plate (5 cm side) rings much higher than 20 cm →
V7. Off-mode frequencies blend modes plausibly →
V8. Sand particles converge to the same nodal lines that Lines/Shaded show →

## W · Mobile / responsive

W1. Layout reflows on narrow viewport (<600px) →
W2. Plate scales to viewport width →
W3. Controls remain reachable on phone →
W4. Touch interactions (slider drag, button taps) →

## X · Accessibility

X1. aria-pressed on DRIVING and AUDIO toggles →
X2. aria-labels on key elements →
X3. Focus states visible when tabbing through →
X4. Reduced-motion preference respected (currently not checked — note if pulse should pause) →

## Y · Edge cases

Y1. Frequency at slider min (50 Hz) →
Y2. Frequency at slider max (6000+ Hz, depends on shape/material) →
Y3. Intensity at 0 (everything goes dark; check it doesn't hide modes that should be there in Lines mode) →
Y4. Q at extremes (5 = very wide; 200 = very sharp) →
Y5. Rapid DRIVING toggle (no glitches, particles handle it) →
Y6. Changing shape mid-drag of freq slider →
Y7. Changing material/geometry while DRIVING →

## Z · Free-form notes

Anything you want to add that doesn't fit above:

-
-
-

---

## Wishlist (features you'd want but I haven't built)

-
-
-
