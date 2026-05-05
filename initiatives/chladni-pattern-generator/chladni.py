"""Chladni pattern generator.

Computes nodal patterns of vibrating plates from Kirchhoff-Love thin-plate
theory and renders them to PNG.

Square plate
------------
Resonant frequencies use the closed-form

    f_{nm} = (pi*h / (2*L^2)) * sqrt(E / (12*rho*(1 - nu^2))) * (n^2 + m^2)

This form is exact for a simply-supported square plate and is an
approximation for a free-edge square plate (the actual free-edge spectrum
involves a numerical eigenvalue solve and differs from the closed form
by edge-correction terms). The nodal field combines degenerate (n,m)
and (m,n) modes:

    psi(x, y) = cos(n*pi*x/L)*cos(m*pi*y/L) +/- cos(m*pi*x/L)*cos(n*pi*y/L)

Both signs are physically valid; they correspond to different driving
symmetries.

Circular plate
--------------
Uses the actual free-edge boundary-value problem:
    M_r = 0  (radial bending moment)
    V_r = 0  (Kirchhoff effective shear)
at r = R. Substituting w(r,theta) = [A*J_n(k*r) + C*I_n(k*r)]*cos(n*theta)
with lambda = k*R yields a 2x2 linear system in (A, C). Setting the
determinant to zero gives the transcendental frequency equation, solved
here by sign-change bracketing on a fine grid plus brentq.

After applying the Bessel ODEs to eliminate second/third derivatives,
the BC entries reduce to:

    M_J = -(1 - nu)*lam*J_n'(lam) - (lam^2 - n^2*(1 - nu))*J_n(lam)
    M_I = -(1 - nu)*lam*I_n'(lam) + (lam^2 + n^2*(1 - nu))*I_n(lam)
    V_J = -lam*[lam^2 + n^2*(1 - nu)]*J_n'(lam) + n^2*(1 - nu)*J_n(lam)
    V_I =  lam*[lam^2 - n^2*(1 - nu)]*I_n'(lam) + n^2*(1 - nu)*I_n(lam)

The frequency equation is M_J*V_I - M_I*V_J = 0. For numerical stability
at large lambda, exp(-lam) is factored out of the I_n terms via
scipy.special.ive (only the sign of the determinant matters for root
finding, and exp(lam) > 0 does not affect sign).

References
----------
Leissa, A. W. *Vibration of Plates*. NASA SP-160, 1969. Tables 4.10
(free-edge circular plate) and surrounding text in Sec. 4.3 are the
verification anchor for the eigenvalues computed here.
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass, field
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
from scipy.optimize import brentq
from scipy.special import ive, iv, jv, jvp

# ----------------------------------------------------------------------------
# Material presets
# ----------------------------------------------------------------------------

MATERIALS: dict[str, dict[str, float]] = {
    "steel":    {"E": 200e9, "rho": 7850, "nu": 0.30},
    "aluminum": {"E": 69e9,  "rho": 2700, "nu": 0.33},
    "brass":    {"E": 110e9, "rho": 8500, "nu": 0.34},
    "glass":    {"E": 70e9,  "rho": 2500, "nu": 0.22},
}


@dataclass
class Mode:
    n: int
    m: int
    f: float                 # Hz
    weight: float = 1.0
    lam: float | None = None  # eigenvalue, circular only


# ----------------------------------------------------------------------------
# Square plate
# ----------------------------------------------------------------------------

def square_mode_frequency(
    n: int, m: int, L: float, h: float, E: float, rho: float, nu: float
) -> float:
    return (np.pi * h / (2.0 * L * L)) * np.sqrt(E / (12.0 * rho * (1.0 - nu * nu))) * (n * n + m * m)


def enumerate_square_modes(
    L: float, h: float, E: float, rho: float, nu: float, max_mode: int = 20
) -> list[Mode]:
    modes: list[Mode] = []
    # Iterate n <= m only — (n,m) and (m,n) share a frequency and the
    # nodal field combines both terms by construction.
    for n in range(1, max_mode + 1):
        for m in range(n, max_mode + 1):
            f = square_mode_frequency(n, m, L, h, E, rho, nu)
            modes.append(Mode(n=n, m=m, f=f))
    return modes


def evaluate_square_field(
    selected: list[Mode], L: float, resolution: int, superposition: str
) -> np.ndarray:
    if superposition not in ("+", "-"):
        raise ValueError(f"superposition must be '+' or '-', got {superposition!r}")

    xs = np.linspace(0.0, L, resolution)
    ys = np.linspace(0.0, L, resolution)
    X, Y = np.meshgrid(xs, ys)

    psi = np.zeros_like(X)
    for mode in selected:
        n, m = mode.n, mode.m
        cnx = np.cos(n * np.pi * X / L)
        cmy = np.cos(m * np.pi * Y / L)
        if n == m:
            # Degenerate diagonal: both terms identical. '+' doubles, '-'
            # cancels. Refuse '-' on a pure diagonal mode.
            if superposition == "-":
                raise ValueError(
                    f"superposition '-' produces psi = 0 on diagonal mode "
                    f"(n=m={n}). Use superposition '+' for diagonal modes."
                )
            term = cnx * cmy  # single term, weight 1 (drops the doubling)
        else:
            cmx = np.cos(m * np.pi * X / L)
            cny = np.cos(n * np.pi * Y / L)
            sign = 1.0 if superposition == "+" else -1.0
            term = cnx * cmy + sign * cmx * cny
        psi = psi + mode.weight * term
    return psi


# ----------------------------------------------------------------------------
# Circular plate (free-edge, numerical eigenvalues)
# ----------------------------------------------------------------------------

def _i_prime_scaled(n: int, lam: float) -> float:
    """exp(-lam) * I_n'(lam) via I_n'(x) = (I_{n-1}(x) + I_{n+1}(x)) / 2."""
    return 0.5 * (ive(n - 1, lam) + ive(n + 1, lam))


def _bc_entries(lam: float, n: int, nu: float) -> tuple[float, float, float, float]:
    """Return (M_J, M_I_scaled, V_J, V_I_scaled).

    M_I_scaled and V_I_scaled have exp(-lam) factored out for stability.
    Sign of det = sign of (M_J * V_I_scaled - M_I_scaled * V_J) since
    exp(lam) > 0.
    """
    Jn = jv(n, lam)
    Jp = jvp(n, lam)
    In_s = ive(n, lam)
    Ip_s = _i_prime_scaled(n, lam)

    one_minus_nu = 1.0 - nu
    n2_omn = n * n * one_minus_nu

    M_J = -one_minus_nu * lam * Jp - (lam * lam - n2_omn) * Jn
    M_I = -one_minus_nu * lam * Ip_s + (lam * lam + n2_omn) * In_s
    V_J = -lam * (lam * lam + n2_omn) * Jp + n2_omn * Jn
    V_I = lam * (lam * lam - n2_omn) * Ip_s + n2_omn * In_s
    return M_J, M_I, V_J, V_I


def _free_edge_det(lam: float, n: int, nu: float) -> float:
    M_J, M_I, V_J, V_I = _bc_entries(lam, n, nu)
    return M_J * V_I - M_I * V_J


def find_circular_eigenvalues(
    n: int, nu: float, num_roots: int = 8, lam_max: float = 80.0, dlam: float = 0.05
) -> list[float]:
    """Bracket sign changes of the BC determinant and brentq each.

    For n = 0 and n = 1, rigid-body modes correspond to lam = 0; the
    determinant has a high-order zero at the origin. Start scanning at
    lam_min = 1.0 to skip the spurious zero. The first true elastic
    mode is well above this floor (n=0: ~3.01, n=1: ~4.53).
    """
    lam_min = 1.0 if n <= 1 else 0.5
    grid = np.arange(lam_min, lam_max + dlam, dlam)
    det_vals = np.array([_free_edge_det(lam, n, nu) for lam in grid])

    roots: list[float] = []
    for i in range(len(grid) - 1):
        f1, f2 = det_vals[i], det_vals[i + 1]
        if f1 == 0.0:
            roots.append(float(grid[i]))
            continue
        if f1 * f2 < 0.0:
            try:
                root = brentq(_free_edge_det, grid[i], grid[i + 1], args=(n, nu))
                roots.append(float(root))
            except ValueError:
                # rare bracket-failure; skip
                pass
        if len(roots) >= num_roots:
            break
    return roots


def circular_mode_frequency(
    lam: float, R: float, h: float, E: float, rho: float, nu: float
) -> float:
    D = E * h ** 3 / (12.0 * (1.0 - nu * nu))
    return (lam * lam / (2.0 * np.pi * R * R)) * np.sqrt(D / (rho * h))


def enumerate_circular_modes(
    R: float, h: float, E: float, rho: float, nu: float,
    max_n: int = 12, max_m: int = 8,
) -> list[Mode]:
    modes: list[Mode] = []
    for n in range(0, max_n + 1):
        roots = find_circular_eigenvalues(n=n, nu=nu, num_roots=max_m + 1)
        # Index roots starting at m=0 (lowest physical root).
        for m, lam in enumerate(roots[: max_m + 1]):
            f = circular_mode_frequency(lam, R, h, E, rho, nu)
            modes.append(Mode(n=n, m=m, f=f, lam=lam))
    return modes


def evaluate_circular_field_with_nu(
    selected: list[Mode], R: float, nu: float, resolution: int
) -> tuple[np.ndarray, np.ndarray]:
    xs = np.linspace(-R, R, resolution)
    ys = np.linspace(-R, R, resolution)
    X, Y = np.meshgrid(xs, ys)
    r = np.hypot(X, Y)
    theta = np.arctan2(Y, X)
    mask_outside = r > R
    r_safe = np.clip(r, 1e-12, R)

    psi = np.zeros_like(X)
    for mode in selected:
        if mode.lam is None:
            continue
        n = mode.n
        lam = mode.lam
        s = lam * r_safe / R

        Jn_s = jv(n, s)
        # I_n(s) for s in [0, lam]; use iv directly (bounded since s <= lam).
        In_s = iv(n, s)

        # alpha satisfies BC1 (M_r = 0). Using scaled BC entries:
        M_J_lam, M_I_s_lam, _, _ = _bc_entries(lam, n, nu)
        # M_J + alpha_unscaled * M_I = 0  →  alpha_unscaled = -M_J / M_I.
        # M_I = exp(lam) * M_I_s_lam, so alpha_unscaled = -M_J / (exp(lam) * M_I_s_lam).
        alpha_unscaled = -M_J_lam / (np.exp(lam) * M_I_s_lam)

        radial = Jn_s + alpha_unscaled * In_s
        psi = psi + mode.weight * radial * np.cos(n * theta)

    return psi, mask_outside


# ----------------------------------------------------------------------------
# Mode selection
# ----------------------------------------------------------------------------

def select_modes(
    target_f: float, modes: list[Mode], tolerance: float = 0.02
) -> list[Mode]:
    if not modes:
        raise ValueError("no candidate modes provided")
    sorted_by_distance = sorted(modes, key=lambda mm: abs(mm.f - target_f))
    closest = sorted_by_distance[0]

    band_lo = target_f * (1.0 - tolerance)
    band_hi = target_f * (1.0 + tolerance)
    in_band = [mm for mm in modes if band_lo <= mm.f <= band_hi]

    selected_set = {(mm.n, mm.m): mm for mm in in_band}
    selected_set[(closest.n, closest.m)] = closest
    selected = list(selected_set.values())

    weights = []
    for mm in selected:
        d = abs(mm.f - target_f)
        # Avoid div by zero on exact match.
        weights.append(1.0 / max(d, 1e-9))
    total = sum(weights)
    out: list[Mode] = []
    for mm, w in zip(selected, weights):
        out.append(Mode(n=mm.n, m=mm.m, f=mm.f, weight=w / total, lam=mm.lam))
    return out


# ----------------------------------------------------------------------------
# Rendering
# ----------------------------------------------------------------------------

def render(
    psi: np.ndarray,
    style: str,
    output_path: Path,
    mask_outside: np.ndarray | None = None,
    shape: str = "square",
    extent: tuple[float, float, float, float] | None = None,
) -> None:
    if style not in ("lines", "shaded"):
        raise ValueError(f"style must be 'lines' or 'shaded', got {style!r}")

    fig, ax = plt.subplots(figsize=(8, 8), dpi=150)
    ax.set_aspect("equal")
    ax.axis("off")
    fig.patch.set_facecolor("white")

    if mask_outside is not None:
        psi = np.where(mask_outside, np.nan, psi)

    if style == "lines":
        ax.contour(
            psi,
            levels=[0.0],
            colors="black",
            linewidths=1.0,
            antialiased=True,
            extent=extent,
        )
    else:  # shaded
        amp = np.abs(psi)
        ax.imshow(
            amp,
            cmap="magma",
            origin="lower",
            extent=extent,
            interpolation="bilinear",
        )

    if shape == "circle" and extent is not None:
        # Crisp disk boundary on top of the contour
        x0 = (extent[0] + extent[1]) / 2.0
        y0 = (extent[2] + extent[3]) / 2.0
        radius = (extent[1] - extent[0]) / 2.0
        circle = plt.Circle(
            (x0, y0), radius, fill=False, edgecolor="black", linewidth=1.0
        )
        ax.add_patch(circle)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output_path, bbox_inches="tight", pad_inches=0.05, facecolor="white")
    plt.close(fig)


# ----------------------------------------------------------------------------
# Sidecar caption
# ----------------------------------------------------------------------------

def write_sidecar(
    txt_path: Path,
    args: argparse.Namespace,
    selected: list[Mode],
    plate_params: dict[str, float],
) -> None:
    lines: list[str] = []
    lines.append(f"Input frequency: {args.frequency:.3f} Hz")
    lines.append(f"Plate shape:     {args.shape}")
    if args.shape == "square":
        lines.append(f"Side length:     {plate_params['L']:.4f} m")
    else:
        lines.append(f"Radius:          {plate_params['R']:.4f} m")
    lines.append(f"Thickness:       {plate_params['h']:.5f} m")
    lines.append(
        f"Material:        E={plate_params['E']:.3e} Pa, "
        f"rho={plate_params['rho']:.0f} kg/m^3, nu={plate_params['nu']:.3f}"
    )
    if args.shape == "square":
        lines.append(f"Superposition:   {args.superposition}")
    lines.append(f"Render style:    {args.style}")
    lines.append(f"Resolution:      {args.resolution}x{args.resolution}")
    lines.append(f"Mode tolerance:  +/- {args.tolerance * 100:.2f}%")
    lines.append("")
    lines.append("Matched modes (n, m, f_nm Hz, weight):")
    for mm in sorted(selected, key=lambda x: -x.weight):
        lam_str = f", lam={mm.lam:.6f}" if mm.lam is not None else ""
        lines.append(
            f"  ({mm.n}, {mm.m}): f = {mm.f:.3f} Hz, weight = {mm.weight:.4f}{lam_str}"
        )

    txt_path.write_text("\n".join(lines) + "\n")


# ----------------------------------------------------------------------------
# Self-tests
# ----------------------------------------------------------------------------

LEISSA_FREE_EDGE_NU_033: list[tuple[int, int, float]] = [
    # (n, m, lam^2). Indexing convention here: m=0 is the lowest physical
    # (elastic) root. Leissa's tables for n=0 and n=1 reserve m=0 for the
    # rigid-body mode at lam=0; their "m=1" is our "m=0". Values for nu=1/3
    # from Leissa, Vibration of Plates, NASA SP-160, Table 4.10.
    (2, 0,  5.253),  # saddle, lowest free-edge mode
    (0, 0,  9.084),  # Leissa (n=0, m=1), first axisymmetric elastic mode
    (3, 0, 12.23),
    (1, 0, 20.52),   # Leissa (n=1, m=1), first n=1 elastic mode
    (4, 0, 21.6),
    (2, 1, 35.25),
    (0, 1, 38.55),   # Leissa (n=0, m=2)
]


def run_self_test() -> int:
    nu = 1.0 / 3.0
    print(f"Verifying free-edge circular plate eigenvalues against Leissa Table 4.10")
    print(f"(nu = 1/3)\n")
    print(f"{'n':>3} {'m':>3} {'computed lam^2':>15} {'Leissa lam^2':>15} {'rel err':>10}")
    failures = 0
    for n, m, lam2_ref in LEISSA_FREE_EDGE_NU_033:
        roots = find_circular_eigenvalues(n=n, nu=nu, num_roots=m + 2, lam_max=80.0)
        if len(roots) <= m:
            print(f"{n:>3} {m:>3}  insufficient roots found ({len(roots)})")
            failures += 1
            continue
        lam = roots[m]
        lam2 = lam * lam
        rel_err = abs(lam2 - lam2_ref) / lam2_ref
        marker = "" if rel_err < 0.01 else "  FAIL"
        print(f"{n:>3} {m:>3} {lam2:>15.4f} {lam2_ref:>15.4f} {rel_err * 100:>9.3f}% {marker}")
        if rel_err >= 0.01:
            failures += 1

    print()
    if failures == 0:
        print(f"All {len(LEISSA_FREE_EDGE_NU_033)} entries match within 1%.")
        return 0
    print(f"{failures} of {len(LEISSA_FREE_EDGE_NU_033)} entries failed.")
    return 1


# ----------------------------------------------------------------------------
# CLI
# ----------------------------------------------------------------------------

def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("--frequency", type=float, help="Input frequency in Hz.")
    p.add_argument("--output", type=str, default=None, help="Output PNG path.")
    p.add_argument("--shape", choices=["square", "circle"], default="square")
    p.add_argument("--side-length", type=float, default=0.20, help="Square side, meters.")
    p.add_argument("--radius", type=float, default=0.10, help="Disk radius, meters.")
    p.add_argument("--thickness", type=float, default=0.001, help="Plate thickness, meters.")
    p.add_argument("--material", choices=list(MATERIALS), default="steel")
    p.add_argument("--E", type=float, default=None, help="Young's modulus override (Pa).")
    p.add_argument("--rho", type=float, default=None, help="Density override (kg/m^3).")
    p.add_argument("--nu", type=float, default=None, help="Poisson ratio override.")
    p.add_argument("--superposition", choices=["+", "-", "both"], default="+",
                   help="Square plate only: ψ sign in mode superposition.")
    p.add_argument("--style", choices=["lines", "shaded"], default="lines")
    p.add_argument("--resolution", type=int, default=800)
    p.add_argument("--max-mode", type=int, default=20, help="Square: enumerate up to n,m=max-mode.")
    p.add_argument("--tolerance", type=float, default=0.02, help="Mode-match band, fraction of f_target.")
    p.add_argument("--self-test", action="store_true",
                   help="Verify circular eigenvalues against Leissa Table 4.10 and exit.")
    return p.parse_args(argv)


def resolve_material(args: argparse.Namespace) -> dict[str, float]:
    base = MATERIALS[args.material].copy()
    if args.E is not None:
        base["E"] = args.E
    if args.rho is not None:
        base["rho"] = args.rho
    if args.nu is not None:
        base["nu"] = args.nu
    return base


def run_one(args: argparse.Namespace, mat: dict[str, float], superposition: str,
            output_path: Path) -> None:
    if args.shape == "square":
        L = args.side_length
        modes = enumerate_square_modes(L, args.thickness, **mat, max_mode=args.max_mode)
        selected = select_modes(args.frequency, modes, tolerance=args.tolerance)
        psi = evaluate_square_field(selected, L, args.resolution, superposition)
        render(psi, args.style, output_path, shape="square",
               extent=(0.0, L, 0.0, L))
        plate_params = {"L": L, "h": args.thickness, **mat}
    else:
        R = args.radius
        modes = enumerate_circular_modes(R, args.thickness, **mat)
        selected = select_modes(args.frequency, modes, tolerance=args.tolerance)
        psi, mask = evaluate_circular_field_with_nu(
            selected, R, mat["nu"], args.resolution
        )
        render(psi, args.style, output_path, mask_outside=mask, shape="circle",
               extent=(-R, R, -R, R))
        plate_params = {"R": R, "h": args.thickness, **mat}

    sidecar_path = output_path.with_suffix(".txt")
    args_for_sidecar = argparse.Namespace(**vars(args))
    args_for_sidecar.superposition = superposition
    write_sidecar(sidecar_path, args_for_sidecar, selected, plate_params)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)

    if args.self_test:
        return run_self_test()

    if args.frequency is None:
        print("error: --frequency is required (or use --self-test)", file=sys.stderr)
        return 2

    mat = resolve_material(args)
    output = Path(args.output) if args.output else Path(f"chladni_{int(args.frequency)}hz.png")

    if args.shape == "square" and args.superposition == "both":
        for sign, suffix in (("+", "_plus"), ("-", "_minus")):
            stem = output.stem + suffix
            out_path = output.with_name(stem + output.suffix)
            try:
                run_one(args, mat, sign, out_path)
                print(f"wrote {out_path}")
            except ValueError as e:
                print(f"skip {sign}: {e}", file=sys.stderr)
    else:
        sup = args.superposition if args.superposition != "both" else "+"
        run_one(args, mat, sup, output)
        print(f"wrote {output}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
