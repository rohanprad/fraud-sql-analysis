"""Build the README charts from the exported results/ CSVs.

SQL in BigQuery does the analysis; Python only draws the pictures. Each chart is
rendered twice, for GitHub's light and dark themes.

Run:  python charts/make_charts.py
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import pandas as pd  # noqa: E402
from matplotlib.patches import FancyBboxPatch, Rectangle  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "results"
OUT = ROOT / "charts"

# Reference palette: first three categorical slots are validated all-pairs for
# colour-vision deficiency in both modes; chrome/ink per mode.
THEMES = {
    "light": dict(surface="#fcfcfb", ink="#0b0b0b", ink2="#52514e", muted="#898781",
                  grid="#e1e0d9", axis="#c3c2b7", s1="#2a78d6", s2="#eb6834", s3="#1baf7a",
                  s1_soft="#b7d3f6", band="#f0efec", context="#c3c2b7"),
    "dark": dict(surface="#1a1a19", ink="#ffffff", ink2="#c3c2b7", muted="#898781",
                 grid="#2c2c2a", axis="#383835", s1="#3987e5", s2="#d95926", s3="#199e70",
                 s1_soft="#184f95", band="#262624", context="#4a4a47"),
}
plt.rcParams.update({
    "font.family": ["Segoe UI", "DejaVu Sans"],
    "font.size": 11,
    "svg.fonttype": "none",
})


def pct1(x):
    """One decimal place, rounding halves up (float 9.85 would otherwise print 9.8)."""
    from decimal import Decimal, ROUND_HALF_UP
    return str(Decimal(str(x)).quantize(Decimal("0.1"), rounding=ROUND_HALF_UP))


def style_axes(ax, t, xgrid=False, ygrid=True):
    ax.set_facecolor(t["surface"])
    for side in ("top", "right", "left"):
        ax.spines[side].set_visible(False)
    ax.spines["bottom"].set_color(t["axis"])
    ax.tick_params(colors=t["muted"], length=0, labelsize=10)
    ax.grid(False)
    if ygrid:
        ax.yaxis.grid(True, color=t["grid"], linewidth=1)
    if xgrid:
        ax.xaxis.grid(True, color=t["grid"], linewidth=1)
    ax.set_axisbelow(True)


def title_block(fig, t, title, subtitle):
    fig.text(0.055, 0.955, title, ha="left", va="top", fontsize=15, fontweight="bold", color=t["ink"])
    fig.text(0.055, 0.895, subtitle, ha="left", va="top", fontsize=10.5, color=t["ink2"])


def hbar_rounded(ax, y, width, height, color, fig):
    """Horizontal bar: 4px rounded data-end, square at the baseline."""
    fig.canvas.draw()
    bbox = ax.get_window_extent()
    x0, x1 = ax.get_xlim()
    y0, y1 = ax.get_ylim()
    rx = 4 * (x1 - x0) / bbox.width
    ry = 4 * abs(y1 - y0) / bbox.height
    ax.add_patch(FancyBboxPatch((0, y - height / 2), width, height,
                                boxstyle=f"round,pad=0,rounding_size={rx}",
                                mutation_aspect=ry / rx, linewidth=0, facecolor=color))
    ax.add_patch(Rectangle((0, y - height / 2), min(width, 2 * rx), height, linewidth=0, facecolor=color))


def vbar_rounded(ax, x, height, width, color, fig):
    """Vertical bar: 4px rounded top, square at the baseline."""
    fig.canvas.draw()
    bbox = ax.get_window_extent()
    x0, x1 = ax.get_xlim()
    y0, y1 = ax.get_ylim()
    rx = 4 * (x1 - x0) / bbox.width
    ry = 4 * (y1 - y0) / bbox.height
    ax.add_patch(FancyBboxPatch((x - width / 2, 0), width, height,
                                boxstyle=f"round,pad=0,rounding_size={ry}",
                                mutation_aspect=rx / ry, linewidth=0, facecolor=color))
    ax.add_patch(Rectangle((x - width / 2, 0), width, min(height, 2 * ry), linewidth=0, facecolor=color))


# ---------------------------------------------------------------- 1. the recommendation
def chart_value_capture(mode):
    t = THEMES[mode]
    df = pd.read_csv(RES / "capture_compare.csv")
    fig = plt.figure(figsize=(10, 6.2), dpi=160, facecolor=t["surface"])
    ax = fig.add_axes([0.075, 0.1, 0.8, 0.68])
    style_axes(ax, t)
    ax.set_xlim(0, 30)
    ax.set_ylim(0, 100)

    # random checks: reviewing X% catches X% of fraud value
    ax.plot([0, 30], [0, 30], color=t["muted"], linewidth=1.2, solid_capstyle="round")
    ax.text(30.4, 30, "Random checks", va="center", fontsize=10, color=t["ink2"])

    series = [("expected_loss", "Expected loss\n(chance × amount)", t["s1"]),
              ("biggest_amount", "Biggest purchases\nfirst", t["s2"]),
              ("risk_score", "Risk score\n(fraud count)", t["s3"])]
    for key, label, colour in series:
        d = df[df.method == key].sort_values("pct_reviewed")
        xs = [0] + d.pct_reviewed.tolist()
        ys = [0] + d.pct_fraud_value_caught.tolist()
        ax.plot(xs, ys, color=colour, linewidth=2.4 if key == "expected_loss" else 2,
                solid_joinstyle="round", solid_capstyle="round", label=label.replace("\n", " "))

    # the recommended operating point
    pt = df[(df.method == "expected_loss") & (df.pct_reviewed == 5)].iloc[0]
    ax.plot([5, 5], [0, pt.pct_fraud_value_caught], color=t["axis"], linewidth=1, zorder=1)
    ax.scatter([5], [pt.pct_fraud_value_caught], s=64, color=t["s1"], zorder=5,
               edgecolors=t["surface"], linewidths=2)
    ax.annotate(f"Review 5% of transactions\n→ catch {pt.pct_fraud_value_caught:.0f}% of fraud value "
                f"(${pt.fraud_value_caught / 1000:,.0f}k)",
                xy=(5, pt.pct_fraud_value_caught), xytext=(9.5, 33),
                fontsize=10.5, color=t["ink"], fontweight="bold",
                arrowprops=dict(arrowstyle="-", color=t["ink2"], linewidth=1))

    ax.set_xticks(range(0, 31, 5))
    ax.set_xticklabels([f"{x}%" for x in range(0, 31, 5)])
    ax.set_yticks(range(0, 101, 25))
    ax.set_yticklabels([f"{y}%" for y in range(0, 101, 25)])
    ax.set_xlabel("Share of transactions reviewed (riskiest first)", color=t["ink2"], fontsize=10.5, labelpad=8)
    ax.set_ylabel("Share of fraud value caught", color=t["ink2"], fontsize=10.5, labelpad=8)
    leg = ax.legend(loc="upper left", frameon=False, fontsize=10, labelcolor=t["ink"], handlelength=1.6)
    title_block(fig, t, "Ranking by money at risk catches half of fraud value from 5% of reviews",
                "Test period: days 128–182, never used to build the rules. 5,327 frauds worth $817k.")
    fig.savefig(OUT / f"01_value_capture_{mode}.png", facecolor=t["surface"])
    plt.close(fig)


# ---------------------------------------------------------------- 2. the warning signs
SIGNS = [  # (signal, value, label)
    ("product", "C", "Product C"),
    ("device", "mobile", "Mobile device"),
    ("email_domain", "outlook.com", "Email: outlook.com"),
    ("amount", "1_<$10", "Amount under $10"),
    ("card_type", "credit", "Credit card"),
    ("time", "overnight", "Overnight (quietest hours)"),
    ("velocity_24h", "3-5 previous", "3–5 purchases in last 24h"),
    ("email_domain", "hotmail.com", "Email: hotmail.com"),
    ("card_type", "debit", "Debit card"),
    ("product", "W", "Product W"),
    ("device", "no device data", "No device data"),
    ("velocity_24h", "0 previous", "First purchase in 24h"),
]


def chart_warning_signs(mode):
    t = THEMES[mode]
    rates = pd.read_csv(RES / "signal_rates.csv")
    overall = pd.read_csv(RES / "overview.csv").query("split == 'train'").fraud_rate_pct.iloc[0]
    rows = []
    for sig, val, label in SIGNS:
        r = rates[(rates.signal == sig) & (rates.value == val)].iloc[0]
        rows.append((label, r.fraud_rate_pct, r.lift))
    rows.sort(key=lambda r: r[1])  # smallest at the bottom of the plot

    fig = plt.figure(figsize=(10, 6.6), dpi=160, facecolor=t["surface"])
    ax = fig.add_axes([0.25, 0.08, 0.66, 0.72])
    style_axes(ax, t, xgrid=True, ygrid=False)
    ax.spines["bottom"].set_visible(False)
    ax.set_xlim(0, 13.5)
    ax.set_ylim(-0.6, len(rows) - 0.4)
    ax.set_yticks(range(len(rows)))
    ax.set_yticklabels([r[0] for r in rows], color=t["ink"], fontsize=10.5)
    ax.set_xticks(range(0, 13, 2))
    ax.set_xticklabels([f"{x}%" for x in range(0, 13, 2)])
    for i, (label, rate, lift) in enumerate(rows):
        colour = t["s1"] if lift >= 1 else t["s1_soft"]
        hbar_rounded(ax, i, rate, 0.56, colour, fig)
        ax.text(rate + 0.15, i, f"{pct1(rate)}%  ({pct1(lift)}×)", va="center", fontsize=10,
                color=t["ink"] if lift >= 1 else t["ink2"], zorder=6,
                bbox=dict(boxstyle="square,pad=0.15", facecolor=t["surface"], edgecolor="none"))
    ax.axvline(overall, color=t["ink2"], linewidth=1.2, zorder=4)
    ax.text(overall + 0.1, len(rows) - 0.45, f"Average {overall:.1f}%", fontsize=10,
            color=t["ink2"], va="bottom")
    title_block(fig, t, "Product C and mobile purchases are about 3× more likely to be fraud",
                "Fraud rate by warning sign, training period (days 1–127). Lighter bars: safer than average.")
    fig.savefig(OUT / f"02_warning_signs_{mode}.png", facecolor=t["surface"])
    plt.close(fig)


# ---------------------------------------------------------------- 3. the overnight pattern
def chart_overnight(mode):
    t = THEMES[mode]
    h = pd.read_csv(RES / "fraud_by_hour.csv").sort_values("hour_dataset")
    overall = h.fraud.sum() / h.txns.sum() * 100
    night = h[h.is_overnight]
    lo, hi = night.hour_dataset.min() - 0.5, night.hour_dataset.max() + 0.5

    fig = plt.figure(figsize=(10, 6.6), dpi=160, facecolor=t["surface"])
    ax1 = fig.add_axes([0.085, 0.53, 0.88, 0.26])   # volume (context)
    ax2 = fig.add_axes([0.085, 0.1, 0.88, 0.34])    # fraud rate (the point)
    for ax in (ax1, ax2):
        style_axes(ax, t)
        ax.set_xlim(-0.6, 23.6)
        ax.axvspan(lo, hi, color=t["band"], zorder=0, linewidth=0)
        ax.set_xticks(range(0, 24, 2))
        ax.set_xticklabels([f"{x:02d}" for x in range(0, 24, 2)])

    ax1.set_ylim(0, 45000)
    ax1.set_yticks([0, 20000, 40000])
    ax1.set_yticklabels(["0", "20k", "40k"])
    ax1.set_xticklabels([])
    ax1.set_title("Transactions per hour", loc="left", fontsize=10.5, color=t["ink2"], pad=6)
    for _, r in h.iterrows():
        vbar_rounded(ax1, r.hour_dataset, r.txns, 0.62, t["context"], fig)

    ax2.set_ylim(0, 12)
    ax2.set_yticks([0, 4, 8, 12])
    ax2.set_yticklabels(["0%", "4%", "8%", "12%"])
    ax2.set_title("Fraud rate", loc="left", fontsize=10.5, color=t["ink2"], pad=6)
    for _, r in h.iterrows():
        vbar_rounded(ax2, r.hour_dataset, r.fraud_rate_pct, 0.62,
                     t["s1"] if r.is_overnight else t["s1_soft"], fig)
    ax2.axhline(overall, color=t["ink2"], linewidth=1.2, zorder=4)
    ax2.text(13.6, overall + 0.3, f"Average {pct1(overall)}%", ha="left", fontsize=10, color=t["ink2"],
             zorder=6, bbox=dict(boxstyle="square,pad=0.15", facecolor=t["surface"], edgecolor="none"))
    peak = h.loc[h.fraud_rate_pct.idxmax()]
    ax2.text(peak.hour_dataset, peak.fraud_rate_pct + 0.35, f"{pct1(peak.fraud_rate_pct)}%",
             ha="center", fontsize=10, color=t["ink"], fontweight="bold")
    ax1.text((lo + hi) / 2, 43000, "Overnight", ha="center", va="top", fontsize=10.5,
             color=t["ink"], fontweight="bold")
    ax2.set_xlabel("Hour on the dataset's clock (offset from real time; the quiet hours are the real night)",
                   color=t["ink2"], fontsize=10, labelpad=8)
    day = h[~h.is_overnight]
    night_rate = night.fraud.sum() / night.txns.sum() * 100
    day_rate = day.fraud.sum() / day.txns.sum() * 100
    title_block(fig, t, "Fraud is highest overnight, when genuine activity is quietest",
                f"Training period (days 1–127). Overnight = hours with under 25% of peak volume: "
                f"{pct1(round(night_rate, 2))}% fraud vs {pct1(round(day_rate, 2))}% the rest of the day.")
    fig.savefig(OUT / f"03_overnight_{mode}.png", facecolor=t["surface"])
    plt.close(fig)


if __name__ == "__main__":
    for m in ("light", "dark"):
        chart_value_capture(m)
        chart_warning_signs(m)
        chart_overnight(m)
    print("charts written to", OUT)
