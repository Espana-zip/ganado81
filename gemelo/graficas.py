from html import escape


def svg_pesajes(animal, mediciones):
    """Dibuja lecturas registradas por Prolog en un SVG legible y sin dependencias."""
    datos = sorted(
        (int(dia), float(peso))
        for dia, peso in mediciones
    )
    if not datos:
        raise ValueError("No existen pesajes")

    ancho, alto = 720, 395
    izquierda, derecha = 90, 630
    arriba, abajo = 105, 307

    dias = [dia for dia, _ in datos]
    pesos = [peso for _, peso in datos]
    minimo_dia, maximo_dia = min(dias), max(dias)
    rango_dias = max(maximo_dia - minimo_dia, 1)
    margen_peso = max(10, (max(pesos) - min(pesos)) * 0.12)
    minimo_peso = min(pesos) - margen_peso
    maximo_peso = max(pesos) + margen_peso
    rango_pesos = maximo_peso - minimo_peso

    def coordenadas(dia, peso):
        if minimo_dia == maximo_dia:
            x = (izquierda + derecha) / 2
        else:
            x = izquierda + (dia - minimo_dia) / rango_dias * (derecha - izquierda)
        y = abajo - (peso - minimo_peso) / rango_pesos * (abajo - arriba)
        return x, y

    puntos = [coordenadas(dia, peso) for dia, peso in datos]
    linea = " ".join(f"{x:.1f},{y:.1f}" for x, y in puntos)

    marcadores = []
    for (dia, peso), (x, y) in zip(datos, puntos):
        anclaje = "middle" if minimo_dia == maximo_dia else (
            "start" if x < (izquierda + derecha) / 2 else "end"
        )
        # Valor y día en líneas diferentes y con fuentes más grandes.
        marcadores.append(
            f'<g>'
            f'<circle cx="{x:.1f}" cy="{y:.1f}" r="7" '
            f'fill="#157347" stroke="white" stroke-width="2"/>'
            f'<text x="{x:.1f}" y="{y-33:.1f}" text-anchor="{anclaje}" '
            f'font-size="23" font-weight="700" fill="#174d36">{peso:g} kg</text>'
            f'<text x="{x:.1f}" y="{y-12:.1f}" text-anchor="{anclaje}" '
            f'font-size="19" font-weight="600" fill="#4d5c56">Día {dia}</text>'
            f'</g>'
        )

    # Tres referencias de peso hacen la gráfica más fácil de interpretar.
    referencias = []
    for proporcion in [0.0, 0.5, 1.0]:
        peso = minimo_peso + proporcion * rango_pesos
        y = abajo - proporcion * (abajo - arriba)
        referencias.append(
            f'<line x1="{izquierda}" y1="{y:.1f}" x2="{derecha}" y2="{y:.1f}" '
            f'stroke="#e7eee9" stroke-width="1"/>'
            f'<text x="{izquierda-12}" y="{y+6:.1f}" text-anchor="end" '
            f'font-size="17" fill="#52675d">{peso:g}</text>'
        )

    titulo = escape(str(animal), quote=True)
    return f'''<svg xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 {ancho} {alto}" role="img"
      aria-label="Pesajes de {titulo} en kilogramos por día simulado"
      font-family="Arial, Helvetica, sans-serif">
      <rect width="100%" height="100%" fill="#ffffff"/>
      <text x="26" y="34" font-size="25" font-weight="700" fill="#163f2e">Pesajes de {titulo}</text>
      <text x="26" y="59" font-size="16" fill="#51685b">Lecturas registradas · modelo académico</text>
      {''.join(referencias)}
      <line x1="{izquierda}" y1="{arriba-5}" x2="{izquierda}" y2="{abajo+7}" stroke="#b4c3bb" stroke-width="2"/>
      <line x1="{izquierda}" y1="{abajo+7}" x2="{derecha+8}" y2="{abajo+7}" stroke="#b4c3bb" stroke-width="2"/>
      <polyline points="{linea}" fill="none" stroke="#157347"
        stroke-width="4" stroke-linejoin="round" stroke-linecap="round"/>
      {''.join(marcadores)}
      <text x="360" y="363" text-anchor="middle" font-size="19"
        font-weight="600" fill="#4d5c56">Día simulado</text>
    </svg>'''
