import math, sys
def ring(cx, cy, r_out, r_in, filled):
    parts = []
    gap = 4.2  # degrees between segments
    for i in range(10):
        a0 = -90 + i * 36 + gap / 2
        a1 = -90 + (i + 1) * 36 - gap / 2
        def pt(r, a):
            return (cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a)))
        p1, p2 = pt(r_out, a0), pt(r_out, a1)
        p3, p4 = pt(r_in, a1), pt(r_in, a0)
        d = (f"M{p1[0]:.2f},{p1[1]:.2f} A{r_out},{r_out} 0 0 1 {p2[0]:.2f},{p2[1]:.2f} "
             f"L{p3[0]:.2f},{p3[1]:.2f} A{r_in},{r_in} 0 0 0 {p4[0]:.2f},{p4[1]:.2f} Z")
        fill = "url(#seg)" if i < filled else "rgba(255,255,255,0.16)"
        parts.append(f'<path d="{d}" fill="{fill}"/>')
    return "\n".join(parts)

def svg(mac):
    # iOS: full-bleed square (the system rounds it). Mac: 824 body on the 1024 grid with a shadow.
    if mac:
        body = '<rect x="100" y="100" width="824" height="824" rx="186" fill="url(#bg)" filter="url(#shadow)"/>'
        scale, off = 824 / 1024, 100
    else:
        body = '<rect x="0" y="0" width="1024" height="1024" fill="url(#bg)"/>'
        scale, off = 1, 0
    content = f'''
    <g transform="translate({off},{off}) scale({scale})">
      <circle cx="512" cy="512" r="300" fill="rgba(255,255,255,0.05)"/>
      {ring(512, 512, 372, 286, 7)}
      <path d="M392 524 L478 608 L648 420" fill="none" stroke="#FFF6E5" stroke-width="64" stroke-linecap="round" stroke-linejoin="round"/>
    </g>'''
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0.35" y2="1">
      <stop offset="0" stop-color="#17808D"/>
      <stop offset="1" stop-color="#0B4450"/>
    </linearGradient>
    <linearGradient id="seg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#FFD27A"/>
      <stop offset="1" stop-color="#F2A93B"/>
    </linearGradient>
    <filter id="shadow" x="-10%" y="-10%" width="120%" height="125%">
      <feDropShadow dx="0" dy="14" stdDeviation="16" flood-color="#000" flood-opacity="0.28"/>
    </filter>
  </defs>
  {body}
  {content}
</svg>'''

open("icon-ios.svg", "w").write(svg(False))
open("icon-mac.svg", "w").write(svg(True))
