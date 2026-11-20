
from html import escape


def svg_pesajes(animal, mediciones):
    """Genera una gráfica SVG con pesajes reales del modelo."""

    datos = sorted(
        (int(dia), float(peso))
        for dia, peso in mediciones
    )

    if not datos:
        raise ValueError("No existen pesajes")

    ancho, alto = 760, 360

    dias = [d for d, _ in datos]
    pesos = [p for _, p in datos]

    dia_min = min(dias)
    rango_dias = max(max(dias) - dia_min, 1)

    peso_min = min(pesos) - 10
    peso_max = max(pesos) + 10
    rango_pesos = peso_max - peso_min

    def coordenadas(dia, peso):
        x = 65 + (dia - dia_min) / rango_dias * 630
        y = 285 - (peso - peso_min) / rango_pesos * 220
        return x, y

    puntos = [
        coordenadas(dia, peso)
        for dia, peso in datos
    ]

    linea = " ".join(
        f"{x:.1f},{y:.1f}" for x, y in puntos
    )

    marcadores = "".join(
        f'<circle cx="{x:.1f}" cy="{y:.1f}" '
        f'r="5" fill="#16a34a"/>'
        f'<text x="{x+8:.1f}" y="{y-12:.1f}" '
        f'font-size="12" fill="#334155">'
        f'{peso:g} kg · día {dia}</text>'
        for (dia, peso), (x, y)
        in zip(datos, puntos)
    )

    titulo = escape(str(animal))

    return f'''<svg xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 {ancho} {alto}">
      <rect width="100%" height="100%" fill="#ffffff"/>
      <text x="35" y="35" font-size="22"
        font-weight="bold" fill="#0f172a">
        Pesajes de {titulo}
      </text>
      <line x1="65" y1="45" x2="65" y2="295"
        stroke="#94a3b8"/>
      <line x1="65" y1="295" x2="710" y2="295"
        stroke="#94a3b8"/>
      <polyline points="{linea}"
        fill="none" stroke="#16a34a"
        stroke-width="3"/>
      {marcadores}
      <text x="320" y="335" font-size="13"
        fill="#475569">Día simulado</text>
    </svg>'''
