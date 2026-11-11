"""Genera las copias runtime de Stitch; solo usa la biblioteca estandar.

No modifica design/. Conserva las clases, el shell y el tema del export;
agrega hooks y plantillas vacias para los datos obtenidos por app.js.
Ejecutar desde cualquier directorio: python3 scripts/adaptar_stitch.py.
"""
from copy import deepcopy
from pathlib import Path
import re
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "design/stitch_ganado81_dashboard_ganadero"
DEST = ROOT / "priv/static"


def text(el):
    return " ".join("".join(el.itertext()).split())


def leaf(root, value):
    return next(el for el in root.iter() if not len(el) and text(el) == value)


def mark(el, name, value="—"):
    el.set("id", name)
    el.text = value
    return el


def bind(root, value, name, initial="—"):
    return mark(leaf(root, value), name, initial)


def children(el, tag=None):
    return [x for x in el if tag is None or x.tag == tag]


def cls(root, name):
    return next(el for el in root.iter() if name in el.get("class", "").split())


def fragment(markup):
    return ET.fromstring(markup)


def replace(parent, old, new):
    i = list(parent).index(old)
    parent.remove(old)
    parent.insert(i, new)


def empty(el):
    for child in list(el):
        el.remove(child)
    el.text = None


def template(container, name, model):
    empty(container)
    result = ET.SubElement(container, "template", {"id": name})
    result.append(model)


def field(root, value, name, initial="—"):
    el = leaf(root, value)
    el.set("data-field", name)
    el.text = initial
    return el


def common(body):
    # Se eliminan los handlers ficticios, no el tema Tailwind del head.
    for el in body.iter():
        for key in list(el.attrib):
            if key.startswith("on"):
                del el.attrib[key]
    routes = {"panel-general": "/", "ficha-de-animal": "/ficha",
              "historial-y-alertas": "/historial", "potreros": "/#potreros"}
    for a in body.iter("a"):
        path = a.get("data-path")
        a.set("href", routes.get(path, "#"))
        if path == "reportes-siniiga":
            a.set("data-unavailable", "Reportes SINIIGA")
        if path == "potreros":
            bind(a, "8", "nav-potreros")
    header = body.find("header")
    bind(header, "Rancho Las Moras • Hermosillo, Son.", "rancho", "Rancho sin configurar • MVP escolar")
    bind(header, "Ing. Rogelio Valenzuela", "usuario", "Usuario local (sin autenticación)")
    bind(header, "Datos Simulados (Entorno Demo)", "demo-global", "API en memoria • DEMO-* ficticios")
    sync = next(b for b in header.iter("button") if "Sincronizar Campo" in text(b))
    sync.set("id", "sync")
    alerts = next(b for b in header.iter("button") if b.get("aria-label"))
    alerts.set("id", "nav-alertas")
    bind(alerts, "3", "nav-alertas-count")
    next(b for b in header.iter("button") if "Rancho Activo" in text(b)).set("data-unavailable", "Configuración de rancho")
    aside = body.find("aside")
    aside.set("id", "sidebar")
    aside.find(".//p").text = "Captura conectada al servidor local. Sin modo offline."
    shell = next(el for el in body if el.get("class") == "pl-64")
    shell.set("id", "app-shell")
    main = body.find(".//main")
    main.set("id", "main")
    wrapper = main.find("div")
    wrapper.set("id", "page-content")
    # No se muestran valores del export mientras carga la API o si falla JS.
    wrapper.set("hidden", "hidden")
    status = fragment('<div id="app-status" role="status" class="p-space-md rounded-lg bg-surface-container">Conectando con el backend…</div>')
    main.insert(0, status)
    main.insert(1, fragment('<noscript>Se requiere JavaScript para consultar los datos del backend.</noscript>'))
    menu = fragment('<button id="mobile-menu" aria-label="Abrir navegación" aria-controls="sidebar" aria-expanded="false" class="rounded-lg bg-surface-container p-space-sm"><span class="material-symbols-outlined">menu</span></button>')
    header.find("div").insert(0, menu)
    footer = body.find(".//footer")
    for el in footer.iter():
        if not len(el) and "Modo Demostrativo Activo" in (el.text or ""):
            el.text = "MVP en memoria • DEMO-* ficticios"
    # viewBox es sensible a mayusculas en SVG; el export lo entrega en minusculas.
    for el in body.iter():
        for old, new in [("viewbox", "viewBox"), ("preserveaspectratio", "preserveAspectRatio")]:
            if old in el.attrib:
                el.set(new, el.attrib.pop(old))
        if el.tag == "lineargradient":
            el.tag = "linearGradient"
    return wrapper


def panel(w):
    sections = children(w, "section")
    intro, kpis, pastures, lower = sections
    date = next(x for x in intro.iter("span") if "calendar_today" in text(x) and len(x))
    date.set("id", "panel-date")
    empty(date)
    date.text = "Fecha del servidor local"
    bind(intro, "Rancho Las Moras", "panel-rancho", "Proyecto 81 • Hato local")
    bind(intro, "Datos simulados en memoria", "panel-source", "API en memoria; DEMO-* ficticios")
    # El sensor RFID no existe en el backend.
    indicator = next(x for x in intro.iter("span") if "Báscula RFID Activa" in text(x))
    empty(indicator)
    indicator.text = "Captura manual conectada"
    banner = next(x for x in w.iter("p") if "Nota técnica de visualización" in text(x))
    empty(banner)
    banner.text = "Datos del backend local en memoria. Los aretes DEMO-* son ficticios. Un reinicio pierde los registros; no hay persistencia."
    cards = children(kpis, "div")
    for value, name in [("482", "kpi-total"), ("18", "kpi-treatment"), ("438", "kpi-weight"), ("74%", "kpi-pastures")]:
        bind(kpis, value, name)
    for old, new in [("Vientres", "Sanos"), ("Novillos", "Enfermos"), ("Vaquillas", "Tratamiento"), ("Toros", "Cuarentena")]:
        leaf(cards[0], old).text = new
    for old, name in [("210", "health-sano"), ("145", "health-enfermo"), ("95", "health-en_tratamiento"), ("32", "health-cuarentena")]:
        bind(cards[0], old, name)
    trend = cls(cards[0], "items-baseline")[1]
    empty(trend)
    mark(trend, "kpi-demo", "")
    leaf(cards[0], "SIMULADO").text = "API LOCAL"
    leaf(cards[0], "Censo general estabulado y en potrero").text = "Censo registrado en el gen_server"
    labels = [x for x in cards[1].iter("span") if "Antibiótico / Vacunación:" in text(x)]
    empty(labels[0]); labels[0].text = "Enfermos:"
    x = next(x for x in cards[1].iter("span") if "Corral de Aislamiento:" in text(x))
    empty(x); x.text = "Cuarentena:"
    bind(cards[1], "12 cabezas", "kpi-sick")
    bind(cards[1], "6 cabezas", "kpi-quarantine")
    bar = next(x for x in cards[1].iter("div") if x.get("style"))
    bar.set("id", "treatment-bar"); bar.set("style", "width:0%")
    trend = cls(cards[2], "items-baseline")[-1]
    empty(trend); mark(trend, "weight-delta", "")
    leaf(cards[2], "Última pesada quincenal global").text = "Promedio de los pesos actuales registrados"
    bind(cards[2], "1.15 kg / día", "kpi-gmd")
    bind(cards[2], "Óptimo", "gmd-note", "Calculado")
    leaf(cards[3], "Ocupación de Potreros").text = "Potreros con Ganado"
    leaf(cards[3], "74% Global").text = "Aforo no registrado"
    leaf(cards[3], "de capacidad óptima").text = "potreros registrados"
    bind(cards[3], "482 de 650 UGM asignadas", "pastures-note")
    bind(cards[3], "Reserva: 168 UGM libres", "capacity-note", "Capacidad: no registrada")
    bind(cards[3], "5 potreros balanceados", "pastures-health", "")
    for x in cards[3].iter("div"):
        if x.get("style"): x.set("style", "width:0%")
    pastures.set("id", "potreros")
    bind(pastures, "Estado y Carga de Potreros (8 Sectores)", "pastures-title", "Estado y Carga de Potreros")
    leaf(pastures, "Rotación de praderas, aforo de forraje y balance de pastoreo activo").text = "Agrupación por potrero actual; aforo y forraje no registrados"
    legend = children(pastures)[0][-1]
    empty(legend); legend.text = "Barra: proporción del hato, no capacidad del potrero"
    grid = children(pastures)[1]
    grid.set("id", "pastures-grid")
    model = deepcopy(children(grid)[0])
    for old, name in [("Sector Norte • P-01", "sector"), ("El Mezquite", "name"), ("85%", "share"), ("68 cabezas registradas", "count"), ("Pastoreo activo", "status"), ("Pasto Buffel", "weight"), ("14 días en uso", "capacity"), ("Lote A-1 (Vientres)", "animals")]:
        field(model, old, name)
    bar = next(x for x in model.iter("div") if x.get("style"))
    bar.set("data-field", "bar"); bar.set("style", "width:0%")
    button = model.find(".//button")
    button.set("data-field", "open"); button.text = "Ver animales →"
    template(grid, "pasture-template", model)
    alerts = next(x for x in w.iter() if x.get("id") == "alertsList")
    model = deepcopy(children(alerts)[0])
    badge = next(x for x in model.iter("span") if "CRÍTICA" in text(x) and len(x))
    empty(badge); badge.set("data-field", "severity")
    field(model, "MX-26-8104", "arete")
    field(model, "• Novillo Brangus (Lote B-4)", "potrero")
    field(model, "Hace 2 horas", "date")
    ps = list(model.iter("p"))
    for p, name in zip(ps, ["message", "note"]):
        empty(p); p.set("data-field", name)
    model.find(".//button").set("data-field", "open")
    model.find(".//button").text = "Ver ficha"
    model.find("div").set("data-field", "stripe")
    template(alerts, "alert-template", model)
    filters = next(x for x in w.iter() if x.get("id") == "filterContainer")
    for btn, value, label in zip(filters, ["todas", "alta", "media", "peso"], ["Todas", "Altas", "Medias", "Peso"]):
        btn.set("data-filter", value); btn.text = label
    leaf(lower, "Incidentes clínicos, sanitarios y movimientos de pradera pendientes").text = "Alertas por pérdida de peso generadas por el backend"
    right = children(lower)[1]
    donut, kit = children(right)
    leaf(donut, "Distribución por Categorías").text = "Distribución por Salud"
    bind(donut, "482 cabezas clasificadas", "health-note")
    bind(donut, "482", "health-total")
    for old, new in [("Vientres de Cría", "Sanos"), ("Novillos Media Ceba", "Enfermos"), ("Vaquillas Reposición", "En tratamiento"), ("Sementales Registrados", "Cuarentena")]:
        el = next(x for x in donut.iter("span") if old in text(x))
        empty(el); el.text = new
    values = ["210 (43.5%)", "145 (30.1%)", "95 (19.7%)", "32 (6.7%)"]
    for key, value in zip(["sano", "enfermo", "en_tratamiento", "cuarentena"], values):
        bind(donut, value, "distribution-" + key)
    for i, circle in enumerate(list(donut.iter("circle"))[1:]):
        circle.set("id", "donut-" + str(i)); circle.set("stroke-dasharray", "0 239")
    for i, bar in enumerate(x for x in donut.iter("div") if x.get("style")):
        bar.set("id", "distribution-bar-" + str(i)); bar.set("style", "width:0%")
    # Conservar el componente botiquin, sin inventar existencias.
    leaf(kit, "Suministros y biológicos en almacén").text = "Inventario no disponible en el modelo del MVP"
    for el in kit.iter():
        if not len(el) and el.text and any(v in el.text for v in ["Lote 2024", "Stock bajo", "Rango 26-", "140 dosis", "2 frascos", "150 aretes"]):
            el.text = "No registrado"
    kit.find("button").set("data-unavailable", "Inventario veterinario")
    modal = next(x for x in w.iter() if x.get("id") == "modalRegistro")
    modal.set("role", "dialog"); modal.set("aria-modal", "true"); modal.set("aria-label", "Registro de báscula")
    inputs = list(modal.iter("input"))
    for inp in inputs: inp.attrib.pop("value", None)
    inputs[0].set("id", "registro-arete"); inputs[0].set("maxlength", "32")
    inputs[0].set("required", "required")
    inputs[1].set("id", "registro-peso"); inputs[1].set("min", "0.01"); inputs[1].set("max", "2000"); inputs[1].set("step", "any"); inputs[1].set("required", "required")
    select = modal.find(".//select")
    replacement = fragment('<input id="registro-potrero" required="required" maxlength="64" placeholder="Potrero para un animal nuevo" class="w-full px-space-md py-space-sm rounded-lg bg-surface-container border-0 font-label-md text-label-md" />')
    replace(next(p for p in modal.iter() if select in list(p)), select, replacement)
    inputs[2].set("disabled", "disabled"); inputs[2].set("placeholder", "No disponible en este MVP; no se guarda")
    save = next(x for x in modal.iter() if x.get("id") == "btnGuardarRegistro")
    empty(save); save.text = "Guardar en backend"; save.set("type", "submit")
    form = fragment('<form id="form-registro" class="flex flex-col gap-space-md"></form>')
    shell = modal.find("div")
    content, actions = list(shell)[1:]
    shell.remove(content); shell.remove(actions)
    form.extend([content, fragment('<p id="registro-error" role="alert" class="text-error"></p>'), actions])
    shell.append(form)
    for b in modal.iter("button"):
        if b is not save: b.set("type", "button")
    leaf(modal, "Captura en manga o corral de manejo").text = "Arete existente: nuevo pesaje. Arete nuevo: alta con salud sano. Potrero solo se guarda al dar de alta."
    bind(w, "Valores simulados para demostración técnica del sistema ganadero Ganado81.", "data-note", "DEMO-* son ficticios; los demás registros se capturan manualmente.")
    bind(w, "Última sincronización con báscula: Hace 4 minutos • Servidor Local Rancho", "last-sync", "")


def ficha(w):
    top, header, grid, history, bottom, modal = list(w)
    top.find(".//button").set("id", "back")
    bind(top, "Novillos", "breadcrumb-category", "Animales")
    bind(top, "Arete MX-26-8104", "breadcrumb-arete")
    bind(top, "Animal 14 de 128", "animal-position")
    for i, b in enumerate(list(top.iter("button"))[1:]):
        b.set("id", ["animal-prev", "animal-next"][i]); b.attrib.pop("title", None)
    bind(header, "MX-26-8104", "animal-arete")
    bind(header, "MX-26", "tag-prefix", "ARETE")
    bind(header, "8104", "tag-number")
    leaf(header, "SINIIGA MÉXICO").text = "IDENTIFICADOR LOCAL"
    leaf(header, "SAGARPA • SENASICA").text = "Código de barras ilustrativo"
    bind(header, "RANCHO: R-104", "animal-ranch", "Rancho: no registrado")
    bind(header, "RFID: 982 00041892019", "animal-rfid", "RFID: no registrado")
    bind(header, "Brangus Negro • Macho Castrado (Novillo de Media Ceba) • Lote Ceba Norte 2024", "animal-description", "Raza, sexo y categoría: no registrados")
    bind(header, "En Tratamiento Médico (Respiratorio)", "animal-health")
    bind(header, "Alerta: Pérdida Reciente (-18 kg en 14d)", "animal-alert")
    bind(header, "Datos Simulados", "animal-demo")
    buttons = list(header.iter("button"))
    buttons[0].set("id", "open-pesaje")
    buttons[1].set("data-unavailable", "Aplicación de dosis")
    buttons[2].set("data-unavailable", "Movimiento desde la web")
    buttons[3].set("id", "btn-menu-acciones")
    for b in buttons[4:]: b.set("data-unavailable", text(b))
    bind(grid, "Alta: 14/03/2023", "animal-created")
    for value in ["Brangus Negro", "75% Angus / 25% Brahman", "24 Meses (2.0 años)", "Novillo Ceba Media", "Lote Ceba Norte 2024", "42 cabezas asociadas", "Asignado hace 18 días", "Nacimiento en rancho (Madre: Vaca R-408 • Potrero 3)"]:
        leaf(grid, value).text = "No registrado"
    bind(grid, "Potrero 2 - Los Álamos", "animal-pasture")
    photo = next(el for el in grid.iter("span") if "Inspección fotográfica" in text(el) and len(el))
    empty(photo); photo.text = "Imagen ilustrativa de Stitch; no es este animal"
    grid.find(".//img").set("alt", "Imagen ilustrativa de un animal; no corresponde al registro")
    bind(grid, "Último Pesaje: 20 Mayo 2024", "animal-updated")
    bind(grid, "-18 kg (-3.91%)", "animal-variation")
    bind(grid, "(en 14 días)", "animal-days")
    bind(grid, "442", "animal-weight")
    previous = next(el for el in grid.iter("span") if "Anterior: 460 kg" in text(el) and len(el))
    empty(previous); mark(previous, "animal-previous")
    bind(grid, "+0.95", "animal-gmd")
    bind(grid, "Reciente: -1.28 kg/día", "animal-recent-gmd")
    bind(grid, "5.0", "animal-condition", "N/D")
    leaf(grid, "Moderada • Grasa costillar tenue").text = "Condición corporal no registrada"
    leaf(grid, "Rango Óptimo Ceba: 6.0 - 7.5").text = "Sin evaluación registrada"
    leaf(grid, "5 Moderada (442 kg)").text = "Valor actual: no registrado"
    for el in grid.iter("div"):
        if "title" in el.attrib:
            el.attrib.pop("title"); empty(el)
    leaf(grid, "Cuarentena Preventiva en Lote").text = "Estado sanitario del backend"
    bind(grid, "Aislado de la línea de embarque hacia rastro o subasta por período de retiro de antibiótico activo.", "animal-health-note", "")
    bind(grid, "28 Días Retiro", "animal-retirement", "Retiro no registrado")
    bind(history, "Todos (60 días)", "history-all", "Todos")
    bind(history, "Últimos 30d", "history-month", "Últimos 30d")
    bind(history, "Exportar CSV", "history-export", "Exportar CSV")
    bind(history, "Tendencia de Peso (Marzo - Mayo 2024)", "chart-title", "Tendencia de peso registrada (kg)")
    goal = next(el for el in history.iter("span") if "Meta de Ceba" in text(el) and len(el))
    empty(goal); goal.text = "Sin meta registrada"
    legend = next(el for el in history.iter("span") if "Peso Real (kg)" in text(el))
    empty(legend); legend.text = "Peso registrado (kg)"
    chart = next(el for el in history.iter("div") if "h-44" in el.get("class", "").split())
    empty(chart); chart.set("id", "weight-chart")
    tbody = history.find(".//tbody")
    empty(tbody); tbody.set("id", "weight-history")
    treatment, pasture = list(bottom)
    # Se mantienen ambos componentes, pero no las prescripciones ficticias.
    for el in treatment.iter():
        if not len(el) and el.text and text(el) not in ["vaccines", "stethoscope", "history_edu", "Tratamiento Médico Activo", "Diagnóstico Presuntivo", "Medicamento & Dosis", "Tiempo de Retiro en Carne"]:
            el.text = "No registrado"
    treatment.find(".//button").set("data-unavailable", "Receta veterinaria")
    bind(treatment, "Tratamiento Médico Activo", "treatment-title", "Estado y Tratamiento Médico")
    # Cambia solo el contenido de la linea de tiempo, no el componente.
    leaf(pasture, "Rotación y disponibilidad de pastizal").text = "Ubicación actual; historial de traslados no registrado"
    leaf(pasture, "Ver Mapa del Rancho").set("data-unavailable", "Mapa del rancho")
    timeline = cls(pasture, "space-y-space-md")
    first = deepcopy(list(timeline)[1])
    bind(first, "Potrero 2 - Los Álamos", "timeline-pasture")
    leaf(first, "Entrada: 02/05/2024 (18 días de pastoreo)").text = "Fecha de entrada: no registrada"
    leaf(first, "Causa: Rotación por agotamiento forrajero en Potrero 1").text = "Motivo: no registrado"
    empty(timeline); timeline.append(first)
    list(pasture.iter("button"))[-1].set("data-unavailable", "Programar traslado")
    modal.set("role", "dialog"); modal.set("aria-modal", "true"); modal.set("aria-label", "Registrar pesaje")
    bind(modal, "Animal: MX-26-8104 (R-104)", "pesaje-animal")
    form = modal.find(".//form"); form.set("id", "form-pesaje")
    weight = form.find(".//input"); weight.set("id", "pesaje-peso")
    weight.set("min", "0.01"); weight.set("max", "2000"); weight.set("step", "any")
    bind(form, "Último peso registrado: 442 kg hace 2 días", "pesaje-last")
    date = next(el for el in form.iter("input") if el.get("type") == "datetime-local")
    date.set("id", "pesaje-date"); date.attrib.pop("value", None); date.set("disabled", "disabled")
    select = form.find(".//select"); empty(select)
    ET.SubElement(select, "option").text = "No registrada (no se guarda)"; select.set("disabled", "disabled")
    for b in form.iter("button"):
        if b.get("type") == "button" and "Cancelar" not in text(b):
            b.set("disabled", "disabled")
            b.text = text(b).replace(" (Actual)", "").replace(" (Óptima)", "")
            if "bg-primary-container" in b.get("class", ""):
                b.set("class", b.get("class").replace("bg-primary-container", "bg-surface-container").replace("text-on-primary-container", "text-on-surface"))
    leaf(form, "Condición Corporal Estimada").text = "Condición Corporal Estimada (no registrada; no se guarda)"
    form.find(".//textarea").set("disabled", "disabled")
    form.find(".//textarea").set("placeholder", "No disponible en este MVP; no se guarda")
    for b in modal.iter("button"):
        if "close" == text(b) or "Cancelar" == text(b): b.set("data-close", "modal-pesaje")
    form.insert(0, fragment('<p class="font-body-sm text-body-sm">Solo se guarda el peso. La fecha la asigna el servidor; los demás campos están deshabilitados.</p>'))
    form.insert(len(form)-1, fragment('<p id="pesaje-error" role="alert" class="text-error"></p>'))


def historial(w):
    header, tabs, filters, table = list(w)
    actions = list(header.iter("button"))
    actions[0].set("id", "events-export")
    actions[1].set("id", "events-register")
    leaf(actions[1], "+ Registrar Evento Masivo").text = "+ Registrar Ingreso / Pesaje"
    for value, name in [("03", "events-critical"), ("07", "events-warning"), ("42", "events-week")]:
        bind(header, value, name)
    # No afirmar que existen mecanismos de resolucion/estado de alertas.
    leaf(header, "Alertas Críticas Activas").text = "Alertas Críticas Registradas"
    for old, new in [("1 distocia y 2 caídas abruptas de peso", "Pérdidas de peso con revisión de captura"), ("Aforos de forraje y retiros activos", "Pérdidas de peso entre pesajes"), ("+18% vs semana prev.", "Últimos 7 días"), ("Pesajes, movimientos y aretado", "Pesajes y alertas registradas"), ("Protocolo Valenzuela", "Backend Erlang/OTP"), ("MODO SIMULADO", "MVP EN MEMORIA"), ("Entorno con datos simulados para validación de flujo ganadero en Rancho Las Moras (8 potreros operativos).", "Los aretes DEMO-* son ficticios. Los eventos se derivan de pesajes y alertas; no hay datos de movimientos ni tratamientos."), ("Báscula y aretado listos en corral", "Conectado a la API local")]:
        # Los textos con icono estan en tails; reemplazar contenido del bloque.
        el = next(x for x in header.iter() if old in text(x) and not any(old in text(c) for c in x))
        empty(el); el.text = new
    for btn in tabs:
        key = btn.get("data-tab")
        empty(btn); btn.set("id", "tab-" + key)
        btn.text = {"todas": "Todas", "criticas": "Críticas", "peso": "Alertas de peso", "movimientos": "Movimientos (no registrados)"}[key]
    def options(id_, values):
        el = next(x for x in filters.iter() if x.get("id") == id_)
        empty(el)
        for value, label in values:
            ET.SubElement(el, "option", {"value": value}).text = label
    options("filter-type", [("all", "Todos los eventos"), ("peso", "Alertas de peso"), ("pesaje", "Pesajes")])
    options("filter-pasture", [("all", "Todos los potreros")])
    options("filter-date", [("all", "Todo el historial"), ("7d", "Últimos 7 días"), ("30d", "Últimos 30 días")])
    active = list(filters)[1]
    labels = list(active)[0]; empty(labels); labels.set("id", "active-filters")
    active.find(".//button").set("id", "clear-filters")
    bind(active, "8 de 48 eventos visibles", "events-count")
    tbody = table.find(".//tbody"); empty(tbody); tbody.set("id", "events-body")
    select = table.find(".//select"); select.set("id", "page-size")
    bind(table, "Mostrando 1-8 de 48 eventos simulados", "pagination-count")
    pagination_count = next(x for x in table.iter() if x.get("id") == "pagination-count")
    next(x for x in table.iter() if pagination_count in list(x)).set("id", "events-pagination-controls")
    controls = next(x for x in table.iter("div") if len(list(x)) == 5 and list(x)[0].tag == "button")
    empty(controls); controls.set("id", "pagination")


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    for page, adapt in [("panel_general", panel), ("ficha_de_animal", ficha), ("historial_y_alertas", historial)]:
        source = (SOURCE / page / "code.html").read_text()
        # El head original (tema, fuentes, CDN y estilos) se conserva byte a byte.
        head = source[:source.index("</head>")]
        head += '<link rel="stylesheet" href="/static/app.css"/><title>Ganado81</title></head>'
        body = re.search(r"<body\b.*?</body>", source, re.S).group()
        body = re.sub(r"<script\b[^>]*>.*?</script>", "", body, flags=re.S)
        root = ET.fromstring(body)
        root.set("data-page", page)
        adapt(common(root))
        for el in root.iter():
            if el.tag not in ["input", "select", "textarea"] or not el.get("id"):
                continue
            parent = next(p for p in root.iter() if el in list(p))
            label = parent.find("label")
            if label is None:
                grandparent = next((p for p in root.iter() if parent in list(p)), parent)
                label = grandparent.find("label")
            if label is not None:
                label.set("for", el.get("id"))
        script = ET.SubElement(root, "script", {"src": "/static/app.js", "defer": "defer"})
        script.text = " "
        (DEST / (page + ".html")).write_text(head + ET.tostring(root, encoding="unicode", method="html") + "</html>\n")
        print("Generado:", page)


if __name__ == "__main__":
    main()
