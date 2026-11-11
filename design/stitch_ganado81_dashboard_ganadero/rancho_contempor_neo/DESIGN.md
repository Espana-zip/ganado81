---
name: Rancho Contemporáneo
colors:
  surface: '#faf9f6'
  surface-dim: '#dbdad7'
  surface-bright: '#faf9f6'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f4f3f0'
  surface-container: '#efeeeb'
  surface-container-high: '#e9e8e5'
  surface-container-highest: '#e3e2df'
  on-surface: '#1a1c1a'
  on-surface-variant: '#414844'
  inverse-surface: '#2f312f'
  inverse-on-surface: '#f2f1ee'
  outline: '#717974'
  outline-variant: '#c1c8c3'
  surface-tint: '#426656'
  primary: '#082e21'
  on-primary: '#ffffff'
  primary-container: '#214436'
  on-primary-container: '#8bb19f'
  inverse-primary: '#a9cfbc'
  secondary: '#8b5008'
  on-secondary: '#ffffff'
  secondary-container: '#ffb064'
  on-secondary-container: '#764200'
  tertiary: '#102d22'
  on-tertiary: '#ffffff'
  tertiary-container: '#274337'
  on-tertiary-container: '#91afa0'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#c4ebd8'
  primary-fixed-dim: '#a9cfbc'
  on-primary-fixed: '#002116'
  on-primary-fixed-variant: '#2b4d3f'
  secondary-fixed: '#ffdcc0'
  secondary-fixed-dim: '#ffb875'
  on-secondary-fixed: '#2d1600'
  on-secondary-fixed-variant: '#6b3b00'
  tertiary-fixed: '#caead9'
  tertiary-fixed-dim: '#aecebe'
  on-tertiary-fixed: '#032016'
  on-tertiary-fixed-variant: '#304c40'
  background: '#faf9f6'
  on-background: '#1a1c1a'
  surface-variant: '#e3e2df'
typography:
  headline-xl:
    fontFamily: Plus Jakarta Sans
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
    letterSpacing: -0.02em
  headline-xl-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 30px
    fontWeight: '700'
    lineHeight: 38px
    letterSpacing: -0.01em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-md:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '500'
    lineHeight: 18px
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 14px
    letterSpacing: 0.04em
  data-metric:
    fontFamily: Plus Jakarta Sans
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
  data-tabular:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-desktop: 1.5rem
  margin: 1rem
  margin-tablet: 1.5rem
  margin-desktop: 2.5rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1.25rem
  space-xl: 2rem
---

## Brand & Style

El sistema de diseño fusiona la robustez técnica del software de operaciones agrícolas con una estética editorial sobria, arraigada en el noroeste de México. El tono general equilibra rigor veterinario, claridad financiera y pragmatismo de campo. 

La dirección estilística es un modernismo utilitario: superficies de alto contraste optimizadas para legibilidad bajo luz solar cenital en corrales y camionetas, alternando con interfaces densas y estructuradas para el trabajo nocturno de oficina. Prescinde de ornamentaciones superficiales, recurriendo a jerarquía tipográfica precisa, bordes arquitectónicos delgados y acentos inspirados en el paisaje árido y productivo (agave, cuero curtido, tierra caliza).

La UI proyecta certeza operativa: cada peso registrado, arete de identificación (SINIIGA) o estatus de cuarentena debe ser inequívoco y visible de un solo vistazo.

## Colors

La paleta se inspira en la flora y suelo del noroeste:

- **Primario (#214436, #1A362B):** Verde agave y monte serrano. Aporta peso institucional, seguridad y presencia en barras de navegación, botones primarios y encabezados estructurales.
- **Secundario y Acento (#C8823B, #9E6122):** Tono cuero curtido y ocre de desierto. Utilizado para acciones secundarias estratégicas, puntos focales de interacción y estados activos de navegación en potreros.
- **Superficies y Neutros (#F8F7F4 base, #FFFFFF contenedor, #E4DFD7 bordes):** Arena clara y caliza. Sustituyen el blanco clínico frío por una base marfilada que atenúa el deslumbramiento solar y mantiene un contraste de texto neto con #1F2421 (texto principal) y #5C645F (metadatos secundarios).
- **Semántica Ganadera y Veterinaria:**
  - *Saludable / Normal:* #2E7D32 con superficie contenedora #E8F5E9.
  - *Observación / Alerta Preventiva:* #ED6C02 con superficie contenedora #FFF4E5.
  - *Crítico / Tratamiento Activo:* #D32F2F con superficie contenedora #FFEBEE.
  - *Simulado / Proyección:* Violeta seco #5E35B1 con contenedor #EDE7F6, diferenciando inmediatamente datos reales de estimaciones de engorda o parición.

## Typography

El emparejamiento tipográfico combina la calidez geométrica de **Plus Jakarta Sans** en titulares y cifras de rendimiento con la neutralidad técnica y legibilidad de **Inter** en cuerpos de texto y registros tabulares.

Para la gestión de ganado, es mandatorio activar las funciones OpenType de espaciado tabular (`tnum`) y ceros barrados (`zero`) en cualquier campo numérico: números de arete SINIIGA (10-12 dígitos), pesaje en báscula (kg), ganancia diaria promedio (GDP) e identificación de lotes. Esto asegura una alineación vertical perfecta en columnas numéricas y previene errores críticos de lectura rápida en campo.

## Layout & Spacing

El diseño adopta una cuadrícula fluida de 12 columnas en escritorio y tabletas apaisadas, adaptándose a 4 columnas en dispositivos móviles de campo. 

- **Escritorio:** Barra lateral colapsable fija (260px expandida / 72px colapsada) con área de datos principal flexible, márgenes exteriores de 2.5rem y canaletas (gutters) de 1.5rem. Permite dashboards multimodales (ej. lista de lotes + vista de pesaje individual simultáneos).
- **Tableta y Móvil:** Márgenes exteriores compactos de 1rem a 1.5rem. Los componentes de captura rápida (registro en corral o báscula) ocupan el 100% del ancho disponible para evitar toques erróneos.
- **Ritmo Vertical:** Módulos de espaciado en múltiplos de 4px y 8px. Las tablas densas utilizan rellenos compactos (`space-sm` vertical, `space-md` horizontal) para maximizar los registros visibles sin scroll excesivo.

## Elevation & Depth

La jerarquía visual se construye a través de superficies tonales estructuradas y bordes definidos, evitando sombras difusas que pierden nitidez bajo la luz directa del sol.

- **Superficies por capas:** El fondo de la aplicación reposa sobre el neutro arena (#F8F7F4). Las tarjetas, tablas y paneles de control operan sobre blanco puro (#FFFFFF), delimitadas por un contorno nítido de 1px en #E4DFD7.
- **Sombreado contenido:** Para ventanas modales, paneles flotantes de lote o menús contextuales, se aplica una sombra limpia y corta: `0 4px 12px -2px rgba(33, 68, 54, 0.08)`. El matiz sutil del color primario (#214436) en la sombra evita la sensación de gris sucio y refuerza la paleta orgánica.
- **Estados de foco e interacción:** El enfoque activo prescinde del brillo artificial y se marca mediante un doble borde concéntrico: 2px blanco interior más 2px en #214436 o #C8823B.

## Shapes

El sistema emplea una geometría sobria de nivel `1` (Soft): esquinas con radio base de 0.25rem (4px) en inputs y celdas, 0.5rem (8px) en tarjetas y paneles principales, y 0.75rem (12px) en contenedores flotantes o modales. 

Esta angularidad contenida transmite precisión y resistencia instrumental. Los únicos elementos que admiten curvatura completa tipo pastilla (full rounded) son los chips de estado clínico y los badges de potrero, facilitando su identificación visual inmediata frente a las cajas de datos rectangulares.

## Components

### Botones
- **Primario:** Fondo #214436, texto #FFFFFF, tipografía Inter Medium 14px, radio 4px. En hover cambia a #1A362B. En pantallas táctiles de báscula la altura mínima es de 44px.
- **Secundario / Terreno:** Fondo transparente, borde 1px en #C8823B, texto #9E6122.
- **Destructivo:** Fondo #FFEBEE, borde 1px #D32F2F, texto #D32F2F.

### Tablas Ganaderas de Alta Densidad
- Cabeceras fijas con fondo #F8F7F4, texto #5C645F en mayúsculas pequeñas (11px, interletraje amplio).
- Filas alternadas o delimitadas por líneas horizontales de 1px en #E4DFD7. Altura de fila compacta (40px) y amplia para campo táctil (52px).
- Columnas de arete SINIIGA y pesaje configuradas obligatoriamente con tipografía `data-tabular` alineada a la derecha para montos y centrada para códigos alfanuméricos.

### Chips de Estado y Salud
- Forma semirredondeada o pastilla, con punto indicador (dot) de 6px en el margen izquierdo:
  - *Saludable:* Fondo #E8F5E9, texto #2E7D32, punto #2E7D32.
  - *Observación:* Fondo #FFF4E5, texto #ED6C02, punto #ED6C02.
  - *Crítico / Cuarentena:* Fondo #FFEBEE, texto #D32F2F, punto #D32F2F con parpadeo suave estático si requiere intervención el mismo día.

### Tarjetas de Métricas (KPIs)
- Fondo blanco, borde #E4DFD7, relleno `space-lg`.
- Muestra el valor en `data-metric` (#1F2421), la etiqueta descriptiva en `label-md` (#5C645F) y una barra lateral de 3px con el color del lote o indicador de tendencia ganadera (ej. GDP en kg/día).

### Selector de Potreros y Lotes
- Componente segmentado interactivo con indicación de ocupación de cabezas de ganado respecto al aforo máximo (ej. "Potrero El Mezquite: 84/100 cabezas"), con indicador gráfico de barra de progreso en tonos agave u ocre.

### Badge de Registro "Simulado"
- Distintivo reservado para cálculos predictivos de engorda, preñez o proyección de forraje.
- Fondo #EDE7F6, borde discontinuo de 1px en #5E35B1, texto #5E35B1 con prefijo de icono de cálculo o texto literal "SIMULADO" en 10px negrita, impidiendo que el operador confunda pesos reales con pronósticos.