/* Ganado81: sin dependencias JS nuevas. El diseño y las plantillas vienen de Stitch. */
(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const all = (selector, root = document) => [...root.querySelectorAll(selector)];
  const put = (id, value) => { if ($(id)) $(id).textContent = value; };
  const num = (n, digits = 1) => n == null ? 'N/D' : Number(n).toLocaleString('es-MX', { maximumFractionDigits: digits });
  const signed = (n, digits = 2) => n == null ? 'N/D' : `${n > 0 ? '+' : ''}${num(n, digits)}`;
  const date = t => new Date(t * 1000).toLocaleDateString('es-MX');
  const time = t => new Date(t * 1000).toLocaleTimeString('es-MX', { hour: '2-digit', minute: '2-digit' });
  const demo = arete => arete.startsWith('DEMO-') ? 'SIMULADO • DEMO' : 'Captura manual';
  const healthKeys = ['sano', 'enfermo', 'en_tratamiento', 'cuarentena'];
  const healthLabels = { sano: 'Sano', enfermo: 'Enfermo', en_tratamiento: 'En tratamiento', cuarentena: 'Cuarentena' };
  const urlAnimal = arete => `/ficha?arete=${encodeURIComponent(arete)}`;
  const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const page = document.body.dataset.page;
  let animals = [], alerts = [], current = null, events = [], pageNumber = 1, activeTab = 'todas';
  let filteredEvents = [], historyDays = 0, loading = false;
  const models = {};
  for (const id of ['pasture-template', 'alert-template']) {
    if ($(id)) models[id] = $(id).content.firstElementChild.cloneNode(true);
  }

  async function api(path, body) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10000);
    try {
      const response = await fetch(`/api${path}`, {
        method: body === undefined ? 'GET' : 'POST', signal: controller.signal,
        headers: body === undefined ? { Accept: 'application/json' } : { Accept: 'application/json', 'Content-Type': 'application/json' },
        body: body === undefined ? undefined : JSON.stringify(body), cache: 'no-store'
      });
      const contentType = response.headers.get('content-type') || '';
      const text = await response.text();
      if (!text.trim()) {
        throw new Error(`Respuesta HTTP ${response.status} vacía del servidor. Revisa el runtime OTP y los logs de Erlang.`);
      }
      if (!contentType.toLowerCase().includes('application/json')) {
        throw new Error(`Respuesta HTTP ${response.status} no JSON (${contentType || 'sin Content-Type'}). Revisa los logs de Erlang.`);
      }
      let result;
      try { result = JSON.parse(text); }
      catch { throw new Error(`Respuesta HTTP ${response.status} con JSON inválido. Revisa los logs de Erlang.`); }
      if (!response.ok || !result.ok) {
        const error = new Error(result.error?.mensaje || `Error HTTP ${response.status}`);
        error.status = response.status;
        throw error;
      }
      return result.datos;
    } catch (error) {
      if (error.name === 'AbortError') throw new Error('El servidor no respondió a tiempo. Reintenta.');
      if (error instanceof TypeError) throw new Error('No se pudo conectar con el servidor local.');
      throw error;
    } finally { clearTimeout(timeout); }
  }

  function model(id, values) {
    const node = models[id].cloneNode(true);
    for (const [key, value] of Object.entries(values)) {
      const field = node.querySelector(`[data-field="${key}"]`);
      if (field) field.textContent = value;
    }
    return node;
  }

  function notice(message) {
    let toast = $('toast');
    if (!toast) {
      toast = document.createElement('div'); toast.id = 'toast'; toast.setAttribute('role', 'status');
      document.body.append(toast);
    }
    toast.textContent = message; toast.hidden = false;
    clearTimeout(notice.timer);
    notice.timer = setTimeout(() => { toast.hidden = true; }, 6000);
  }

  const open = id => {
    $(id).classList.remove('hidden');
    open.previous = document.activeElement;
    $(id).querySelector('input:not(:disabled),button')?.focus();
  };
  const close = id => { $(id).classList.add('hidden'); open.previous?.focus(); };
  function active(buttons, selected) {
    for (const btn of buttons) {
      const yes = btn === selected;
      btn.classList.toggle('bg-primary', yes); btn.classList.toggle('text-on-primary', yes);
      btn.classList.toggle('bg-surface-container', !yes); btn.classList.toggle('text-on-surface-variant', !yes);
      btn.setAttribute('aria-pressed', String(yes));
    }
  }

  function metrics(animal) {
    const history = animal.historial_pesajes;
    const last = history[0], previous = history[1], first = history[history.length - 1];
    const days = previous ? (last.fecha - previous.fecha) / 86400 : 0;
    const totalDays = (last.fecha - first.fecha) / 86400;
    return {
      previous, days, delta: previous ? last.peso_kg - previous.peso_kg : null,
      pct: previous ? (last.peso_kg - previous.peso_kg) / previous.peso_kg * 100 : null,
      recent: days > 0 ? (last.peso_kg - previous.peso_kg) / days : null,
      gmd: totalDays > 0 ? (last.peso_kg - first.peso_kg) / totalDays : null
    };
  }

  function common() {
    put('nav-alertas-count', alerts.length);
    put('nav-potreros', new Set(animals.map(a => a.potrero)).size);
    put('last-sync', `Última consulta API: ${new Date().toLocaleString('es-MX')} • Captura manual`);
  }

  function renderPanel() {
    const counts = Object.fromEntries(healthKeys.map(key => [key, animals.filter(a => a.salud === key).length]));
    const pastures = [...new Set(animals.map(a => a.potrero))].sort();
    put('panel-date', new Date().toLocaleDateString('es-MX', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' }));
    put('kpi-total', animals.length);
    put('kpi-demo', `${animals.filter(a => a.arete.startsWith('DEMO-')).length} DEMO ficticios`);
    put('kpi-treatment', counts.en_tratamiento);
    put('kpi-sick', `${counts.enfermo} cabezas`); put('kpi-quarantine', `${counts.cuarentena} cabezas`);
    $('treatment-bar').style.width = `${animals.length ? counts.en_tratamiento / animals.length * 100 : 0}%`;
    put('kpi-weight', animals.length ? num(animals.reduce((sum, a) => sum + a.peso_kg, 0) / animals.length) : 'N/D');
    const gmds = animals.map(a => metrics(a).recent).filter(x => x != null);
    put('kpi-gmd', `${gmds.length ? signed(gmds.reduce((a, b) => a + b, 0) / gmds.length) : 'N/D'} kg/día`);
    put('gmd-note', `${gmds.length} con intervalo válido`);
    put('kpi-pastures', pastures.length); put('pastures-note', `${animals.length} cabezas asignadas`);
    put('pastures-title', `Estado y Carga de Potreros (${pastures.length})`);
    put('health-total', animals.length); put('health-note', `${animals.length} cabezas con estado sanitario registrado`);
    let offset = 0;
    healthKeys.forEach((key, i) => {
      put(`health-${key}`, counts[key]);
      const share = animals.length ? counts[key] / animals.length * 100 : 0;
      put(`distribution-${key}`, `${counts[key]} (${num(share)}%)`);
      $(`distribution-bar-${i}`).style.width = `${share}%`;
      $(`donut-${i}`).setAttribute('stroke-dasharray', `${share * 2.3876} 238.76`);
      $(`donut-${i}`).setAttribute('stroke-dashoffset', -offset);
      offset += share * 2.3876;
    });
    const grid = $('pastures-grid'); grid.replaceChildren();
    for (const pasture of pastures) {
      const group = animals.filter(a => a.potrero === pasture), share = group.length / animals.length * 100;
      const node = model('pasture-template', {
        sector: 'Potrero registrado', name: pasture, share: `${num(share)}% del hato`,
        count: `${group.length} cabezas registradas`, status: `${group.filter(a => a.salud === 'sano').length} sanos`,
        weight: `Peso medio: ${num(group.reduce((sum, a) => sum + a.peso_kg, 0) / group.length)} kg`,
        capacity: 'Aforo: no registrado', animals: group.map(a => a.arete).join(', ')
      });
      node.querySelector('[data-field="bar"]').style.width = `${share}%`;
      node.querySelector('[data-field="open"]').onclick = () => {
        location.href = `/historial?potrero=${encodeURIComponent(pasture)}`;
      };
      grid.append(node);
    }
    if (!pastures.length) grid.textContent = 'Sin animales registrados. Usa Registrar Ingreso / Pesaje para comenzar.';
    active(all('#filterContainer button'), document.querySelector('#filterContainer [data-filter="todas"]'));
    renderPanelAlerts('todas');
  }

  function renderPanelAlerts(filter) {
    const list = $('alertsList'); list.replaceChildren();
    for (const alert of alerts.filter(a => filter === 'todas' || filter === 'peso' || a.severidad === filter)) {
      const animal = animals.find(a => a.arete === alert.arete);
      const high = alert.severidad === 'alta';
      const node = model('alert-template', {
        severity: high ? 'ALTA • Revisar captura' : 'MEDIA • Pérdida de peso',
        arete: alert.arete, potrero: `${animal?.potrero || 'No registrado'} • ${demo(alert.arete)}`,
        date: `${date(alert.fecha)} ${time(alert.fecha)}`, message: alert.mensaje,
        note: `${num(alert.peso_anterior_kg)} → ${num(alert.peso_actual_kg)} kg (−${num(alert.variacion_pct)}%). Alerta registrada, sin resolución documentada.`
      });
      node.querySelector('[data-field="stripe"]').style.backgroundColor = high ? '#ba1a1a' : '#8b5008';
      node.querySelector('[data-field="severity"]').className = `px-space-xs py-0.5 rounded-full font-label-sm text-label-sm font-bold ${high ? 'bg-error-container text-on-error-container' : 'bg-secondary-fixed text-on-secondary-fixed'}`;
      node.querySelector('[data-field="open"]').onclick = () => { location.href = urlAnimal(alert.arete); };
      list.append(node);
    }
    if (!list.children.length) list.textContent = 'Sin alertas para este filtro.';
    all('#filterContainer button').forEach(btn => {
      const key = btn.dataset.filter;
      btn.textContent = `${{ todas: 'Todas', alta: 'Altas', media: 'Medias', peso: 'Peso' }[key]} (${key === 'todas' || key === 'peso' ? alerts.length : alerts.filter(a => a.severidad === key).length})`;
    });
  }

  function renderFicha() {
    const a = current, m = metrics(a), animalAlerts = alerts.filter(x => x.arete === a.arete);
    const position = animals.findIndex(x => x.arete === a.arete);
    put('animal-position', `Animal ${position + 1} de ${animals.length}`);
    for (const [id, index] of [['animal-prev', position - 1], ['animal-next', position + 1]]) {
      $(id).disabled = !animals[index];
      $(id).onclick = () => { if (animals[index]) location.href = urlAnimal(animals[index].arete); };
    }
    put('breadcrumb-arete', `Arete ${a.arete}`); put('animal-arete', a.arete); put('tag-number', a.arete);
    put('animal-demo', demo(a.arete)); put('animal-health', healthLabels[a.salud]);
    const healthBadge = $('animal-health').parentElement;
    healthBadge.style.backgroundColor = a.salud === 'sano' ? '#c4ebd8' : '#ffdcc0';
    healthBadge.style.color = '#1a1c1a';
    healthBadge.firstElementChild.style.backgroundColor = a.salud === 'sano' ? '#082e21' : '#8b5008';
    healthBadge.firstElementChild.classList.remove('animate-ping');
    put('animal-alert', `${animalAlerts.length} alertas de peso registradas`);
    put('animal-created', `Alta: ${date(a.creado_en)}`); put('animal-pasture', a.potrero); put('timeline-pasture', a.potrero);
    put('animal-updated', `Último pesaje: ${date(a.historial_pesajes[0].fecha)}`);
    put('animal-variation', m.delta == null ? 'Sin pesaje anterior' : `${signed(m.delta)} kg (${signed(m.pct)}%)`);
    put('animal-days', m.previous ? `(intervalo: ${num(m.days, 3)} días)` : '');
    put('animal-weight', num(a.peso_kg));
    put('animal-previous', m.previous ? `Anterior: ${num(m.previous.peso_kg)} kg (${date(m.previous.fecha)})` : 'Sin pesaje anterior');
    put('animal-gmd', signed(m.gmd)); put('animal-recent-gmd', `Reciente: ${signed(m.recent)} kg/día`);
    put('animal-health-note', `${healthLabels[a.salud]}. Diagnóstico y protocolo veterinario no registrados.`);
    put('pesaje-animal', `Animal: ${a.arete} • ${demo(a.arete)}`);
    put('pesaje-last', `Último peso: ${num(a.peso_kg)} kg. La fecha del nuevo registro la asigna el servidor.`);
    const local = new Date(); local.setMinutes(local.getMinutes() - local.getTimezoneOffset());
    $('pesaje-date').value = local.toISOString().slice(0, 16);
    renderWeightHistory();
  }

  function renderWeightHistory() {
    const full = current.historial_pesajes;
    const rows = full.map((p, i) => {
      const previous = full[i + 1], delta = previous ? p.peso_kg - previous.peso_kg : null;
      const days = previous ? (p.fecha - previous.fecha) / 86400 : 0;
      const pct = previous ? -delta / previous.peso_kg * 100 : 0;
      return { ...p, delta, gmd: days > 0 ? delta / days : null, severity: pct >= 40 ? 'alta' : pct >= 10 ? 'media' : 'normal' };
    }).filter(p => !historyDays || p.fecha >= Date.now() / 1000 - historyDays * 86400);
    $('weight-history').innerHTML = rows.map(p => `<tr class="hover:bg-surface-container transition-colors">
      <td class="py-space-sm px-space-md">${date(p.fecha)} ${time(p.fecha)}</td>
      <td class="py-space-sm px-space-md text-right font-data-tabular font-bold text-primary">${num(p.peso_kg)}</td>
      <td class="py-space-sm px-space-md text-right font-data-tabular">${signed(p.delta)}${p.delta == null ? '' : ' kg'}</td>
      <td class="py-space-sm px-space-md text-right font-data-tabular">${signed(p.gmd)}</td>
      <td class="py-space-sm px-space-md">No registrado</td><td class="py-space-sm px-space-md">Sin observación clínica registrada</td>
      <td class="py-space-sm px-space-md">${severity(p.severity)}</td></tr>`).join('') || '<tr><td colspan="7" class="p-space-md">Sin pesajes en este rango.</td></tr>';
    const chartRows = [...rows].reverse(), weights = chartRows.map(p => p.peso_kg);
    if (!rows.length) { $('weight-chart').textContent = 'Sin pesajes en este rango.'; return; }
    const min = Math.min(...weights) - 10, max = Math.max(...weights) + 10;
    const firstTime = chartRows[0].fecha, interval = chartRows.at(-1).fecha - firstTime;
    const points = chartRows.map((p, i) => [
      interval > 0 ? 45 + (p.fecha - firstTime) / interval * 610 : 45 + i / Math.max(1, chartRows.length - 1) * 610,
      140 - (p.peso_kg - min) / (max - min) * 110
    ]);
    $('weight-chart').innerHTML = `<svg viewBox="0 0 700 180" preserveAspectRatio="none" class="w-full h-full" role="img" aria-label="Curva de pesos registrados, de ${num(min)} a ${num(max)} kg">
      <defs><linearGradient id="pesajeGrad" x1="0" x2="0" y1="0" y2="1"><stop offset="0%" stop-color="#214436" stop-opacity="0.25"/><stop offset="100%" stop-color="#214436" stop-opacity="0"/></linearGradient></defs>
      ${[30, 85, 140].map(y => `<line x1="40" x2="680" y1="${y}" y2="${y}" stroke="#e3e2df" stroke-dasharray="3 3"/>`).join('')}
      <polygon fill="url(#pesajeGrad)" points="${points.map(p => p.join(',')).join(' ')} ${points.at(-1)[0]},145 ${points[0][0]},145"/>
      <polyline fill="none" stroke="#082e21" stroke-width="3" points="${points.map(p => p.join(',')).join(' ')}"/>
      ${points.map(([x, y], i) => `<circle cx="${x}" cy="${y}" r="4.5" fill="white" stroke="#082e21" stroke-width="3"><title>${date(chartRows[i].fecha)}: ${num(weights[i])} kg</title></circle>`).join('')}
      ${points.filter((_, i) => i === 0 || i === points.length - 1 || points.length <= 6).map(([x], j) => {
        const i = points.length <= 6 ? j : j === 0 ? 0 : points.length - 1;
        return `<text x="${x}" y="15" text-anchor="middle" fill="#414844" font-size="11">${num(weights[i])} kg</text><text x="${x}" y="170" text-anchor="middle" fill="#717974" font-size="10">${date(chartRows[i].fecha)}</text>`;
      }).join('')}</svg>`;
  }

  function severity(level) {
    const [label, color, icon] = level === 'alta' ? ['Crítico', 'bg-error-container text-on-error-container', 'warning'] : level === 'media' ? ['Advertencia', 'bg-secondary-fixed text-on-secondary-fixed', 'error_outline'] : ['Informativo', 'bg-primary-fixed text-on-primary-fixed', 'check_circle'];
    return `<span class="inline-flex items-center gap-1 px-2 py-1 rounded font-label-sm text-label-sm font-bold ${color}"><span class="material-symbols-outlined text-[14px]">${icon}</span>${label}</span>`;
  }

  function buildEvents() {
    events = animals.flatMap(a => a.historial_pesajes.map(p => ({
      arete: a.arete, fecha: p.fecha, potrero: a.potrero, type: 'pesaje', severidad: 'normal',
      mensaje: `Pesaje registrado: ${num(p.peso_kg)} kg`, note: 'Sin observaciones clínicas registradas', action: 'Registro guardado'
    })));
    events.push(...alerts.map(a => ({ ...a, type: 'peso', potrero: animals.find(x => x.arete === a.arete)?.potrero || 'No registrado',
      note: `${num(a.peso_anterior_kg)} → ${num(a.peso_actual_kg)} kg (−${num(a.variacion_pct)}%)`,
      action: a.revisar_captura ? 'Revisar posible error de captura. Sin resolución registrada.' : 'Revisar salud, agua y pasto. Sin resolución registrada.'
    })));
    events.sort((a, b) => b.fecha - a.fecha);
    put('events-critical', alerts.filter(a => a.severidad === 'alta').length);
    put('events-warning', alerts.filter(a => a.severidad === 'media').length);
    put('events-week', events.filter(e => e.fecha >= Date.now() / 1000 - 7 * 86400).length);
    put('tab-todas', `Todas las novedades (${events.length})`);
    put('tab-criticas', `Alertas críticas (${alerts.filter(a => a.severidad === 'alta').length})`);
    put('tab-peso', `Anomalías de peso (${alerts.length})`);
    const previous = $('filter-pasture').value;
    $('filter-pasture').replaceChildren(new Option('Todos los potreros', 'all'), ...[...new Set(animals.map(a => a.potrero))].sort().map(p => new Option(p, p)));
    const requested = new URLSearchParams(location.search).get('potrero');
    $('filter-pasture').value = [...$('filter-pasture').options].some(o => o.value === previous) && previous !== 'all' ? previous : requested || 'all';
    if (!$('filter-pasture').value) $('filter-pasture').value = 'all';
    filterEvents();
  }

  function filterEvents() {
    const type = $('filter-type').value, level = $('filter-severity').value, pasture = $('filter-pasture').value;
    const range = $('filter-date').value, search = $('search-ear-tag').value.trim().toLocaleLowerCase('es');
    const days = range === '7d' ? 7 : range === '30d' ? 30 : 0;
    const severityKey = { critico: 'alta', advertencia: 'media', normal: 'normal' }[level];
    filteredEvents = events.filter(e =>
      (type === 'all' || e.type === type) && (level === 'all' || e.severidad === severityKey) &&
      (pasture === 'all' || e.potrero === pasture) && (!days || e.fecha >= Date.now() / 1000 - days * 86400) &&
      (!search || `${e.arete} ${e.potrero} ${e.mensaje}`.toLocaleLowerCase('es').includes(search)) &&
      (activeTab === 'todas' || activeTab === 'criticas' && e.severidad === 'alta' || activeTab === 'peso' && e.type === 'peso')
    );
    put('active-filters', `Vista: ${activeTab} • Tipo: ${$('filter-type').selectedOptions[0].text} • Severidad: ${$('filter-severity').selectedOptions[0].text} • Potrero: ${pasture} • ${$('filter-date').selectedOptions[0].text}${search ? ` • Búsqueda: ${search}` : ''}`);
    renderEvents();
  }

  function renderEvents() {
    const size = Number($('page-size').value), pages = Math.max(1, Math.ceil(filteredEvents.length / size));
    pageNumber = Math.min(pageNumber, pages);
    const start = (pageNumber - 1) * size, rows = filteredEvents.slice(start, start + size);
    put('events-count', `${filteredEvents.length} de ${events.length} eventos`);
    put('pagination-count', filteredEvents.length ? `Mostrando ${start + 1}–${start + rows.length} de ${filteredEvents.length}` : 'Sin eventos para estos filtros');
    $('events-body').innerHTML = rows.map(e => `<tr class="hover:bg-surface-container-low/80 transition-colors ${e.severidad === 'alta' ? 'bg-error-container/10' : e.severidad === 'media' ? 'bg-secondary-fixed/20' : ''}">
      <td class="py-space-md px-space-md align-top">${severity(e.severidad)}</td>
      <td class="py-space-md px-space-md align-top font-data-tabular whitespace-nowrap">${date(e.fecha)}<div class="font-body-sm text-body-sm">${time(e.fecha)}</div></td>
      <td class="py-space-md px-space-md align-top"><a class="font-data-tabular font-bold text-primary hover:underline" href="${urlAnimal(e.arete)}">${esc(e.arete)}</a><div class="font-body-sm text-body-sm">${demo(e.arete)}</div></td>
      <td class="py-space-md px-space-md align-top">No registrado</td>
      <td class="py-space-md px-space-md align-top"><div class="font-semibold">${esc(e.mensaje)}</div><div class="font-body-sm text-body-sm">${esc(e.note)}</div></td>
      <td class="py-space-md px-space-md align-top">${esc(e.potrero)}<div class="font-body-sm text-body-sm">Ubicación actual</div></td>
      <td class="py-space-md px-space-md align-top">No registrado</td>
      <td class="py-space-md px-space-md align-top"><div class="p-1.5 rounded bg-surface-container font-body-sm text-body-sm">${esc(e.action)}</div></td></tr>`).join('') || '<tr><td colspan="8" class="p-space-lg">No hay eventos para los filtros seleccionados.</td></tr>';
    const controls = $('pagination'); controls.replaceChildren();
    const buttons = [['Anterior', pageNumber - 1], [String(pageNumber), pageNumber], ['Siguiente', pageNumber + 1]];
    for (const [label, target] of buttons) {
      const b = document.createElement('button'); b.textContent = label;
      b.className = 'rounded bg-surface-container px-space-sm py-1 font-label-sm text-label-sm';
      b.disabled = target < 1 || target > pages || target === pageNumber;
      b.onclick = () => { pageNumber = target; renderEvents(); }; controls.append(b);
    }
  }

  function download(name, rows) {
    const cell = value => {
      const text = String(value ?? '');
      return `"${(/^[=+\-@\t\r]/.test(text) ? "'" : '') + text.replace(/"/g, '""')}"`;
    };
    const blob = new Blob(['\uFEFF' + rows.map(row => row.map(cell).join(',')).join('\r\n')], { type: 'text/csv;charset=utf-8' });
    const url = URL.createObjectURL(blob), link = document.createElement('a');
    link.href = url; link.download = name; link.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
  }

  async function load() {
    if (loading) return;
    loading = true; $('sync').disabled = true;
    $('app-status').hidden = false; $('app-status').textContent = 'Consultando el backend…';
    $('page-content').hidden = true;
    try {
      const [herd, warnings] = await Promise.all([api('/animales'), api('/alertas')]);
      animals = herd.animales; alerts = warnings.alertas;
      if (page === 'panel_general') renderPanel();
      else if (page === 'ficha_de_animal') {
        const tag = new URLSearchParams(location.search).get('arete') || animals[0]?.arete;
        if (!tag) throw new Error('El hato está vacío. Registra un animal en el Panel General.');
        current = (await api(`/animales/${encodeURIComponent(tag)}`)).animal;
        renderFicha();
      } else buildEvents();
      common(); $('page-content').hidden = false; $('app-status').hidden = true;
    } catch (error) {
      $('app-status').textContent = error.message + ' ';
      const retry = document.createElement('button'); retry.textContent = 'Reintentar';
      retry.className = 'text-primary font-bold underline'; retry.onclick = load; $('app-status').append(retry);
      const back = document.createElement('a'); back.href = '/'; back.textContent = ' Volver al Panel General'; $('app-status').append(back);
    } finally { loading = false; $('sync').disabled = false; }
  }

  async function save(form, errorId, work, after) {
    const button = form.querySelector('[type="submit"]');
    if (button.disabled) return;
    put(errorId, ''); button.disabled = true;
    try { await work(); after(); await load(); notice('Registro guardado en el backend.'); }
    catch (error) { put(errorId, error.message); }
    finally { button.disabled = false; }
  }

  $('sync').onclick = load;
  $('nav-alertas').onclick = () => { location.href = '/historial'; };
  all('[data-unavailable]').forEach(el => el.onclick = e => { e.preventDefault(); notice(`${el.dataset.unavailable}: no disponible en este MVP.`); });
  $('mobile-menu').onclick = () => {
    const expanded = document.body.classList.toggle('nav-open');
    $('mobile-menu').setAttribute('aria-expanded', expanded);
  };
  all('img').forEach(img => { img.addEventListener('error', () => { img.hidden = true; }); });
  all('[data-close]').forEach(btn => btn.onclick = () => close(btn.dataset.close));
  all('[role="dialog"]').forEach(modal => modal.onclick = e => { if (e.target === modal) close(modal.id); });
  document.addEventListener('keydown', e => {
    const modal = all('[role="dialog"]').find(el => !el.classList.contains('hidden'));
    if (e.key === 'Escape') { if (modal) close(modal.id); document.body.classList.remove('nav-open'); $('mobile-menu').setAttribute('aria-expanded', 'false'); }
    if (e.key === 'Tab' && modal) {
      const focusable = all('button:not(:disabled),input:not(:disabled),textarea:not(:disabled),select:not(:disabled)', modal);
      const first = focusable[0], last = focusable.at(-1);
      if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
      if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
    }
  });
  if (page === 'panel_general') {
    $('btnRegistrar').onclick = () => { put('registro-error', ''); open('modalRegistro'); };
    $('btnCerrarModal').onclick = $('btnCancelarModal').onclick = () => close('modalRegistro');
    all('#filterContainer button').forEach(btn => btn.onclick = () => { active(all('#filterContainer button'), btn); renderPanelAlerts(btn.dataset.filter); });
    $('form-registro').onsubmit = e => {
      e.preventDefault();
      const tag = $('registro-arete').value.trim(), weight = Number($('registro-peso').value);
      save(e.currentTarget, 'registro-error', async () => {
        // No hacer upsert silencioso: consultar primero; un 409 de alta se muestra al usuario.
        let exists;
        try { await api(`/animales/${encodeURIComponent(tag)}`); exists = true; }
        catch (error) { if (error.status !== 404) throw error; exists = false; }
        await api(exists ? `/animales/${encodeURIComponent(tag)}/pesajes` : '/animales', exists ? { peso_kg: weight } : { arete: tag, peso_kg: weight, potrero: $('registro-potrero').value.trim(), salud: 'sano' });
      }, () => { close('modalRegistro'); $('form-registro').reset(); });
    };
    // Para animales existentes, el potrero no se modifica y no es obligatorio.
    $('registro-potrero').required = false;
  } else if (page === 'ficha_de_animal') {
    $('back').onclick = () => { location.href = '/'; };
    $('open-pesaje').onclick = () => { put('pesaje-error', ''); open('modal-pesaje'); };
    $('btn-menu-acciones').onclick = () => $('menu-acciones').classList.toggle('hidden');
    $('form-pesaje').onsubmit = e => {
      e.preventDefault();
      save(e.currentTarget, 'pesaje-error', () => api(`/animales/${encodeURIComponent(current.arete)}/pesajes`, { peso_kg: Number($('pesaje-peso').value) }), () => { close('modal-pesaje'); $('pesaje-peso').value = ''; });
    };
    $('history-all').onclick = () => { historyDays = 0; active([$('history-all'), $('history-month')], $('history-all')); renderWeightHistory(); };
    $('history-month').onclick = () => { historyDays = 30; active([$('history-all'), $('history-month')], $('history-month')); renderWeightHistory(); };
    $('history-export').onclick = () => download('pesajes.csv', [['Arete', 'Fecha Unix', 'Peso kg', 'Origen'], ...current.historial_pesajes.filter(p => !historyDays || p.fecha >= Date.now() / 1000 - historyDays * 86400).map(p => [current.arete, p.fecha, p.peso_kg, demo(current.arete)])]);
  } else {
    all('.tab-btn').forEach(btn => btn.onclick = () => { activeTab = btn.dataset.tab; pageNumber = 1; active(all('.tab-btn'), btn); filterEvents(); });
    ['filter-type', 'filter-severity', 'filter-pasture', 'filter-date', 'page-size'].forEach(id => $(id).onchange = () => { pageNumber = 1; filterEvents(); });
    $('search-ear-tag').oninput = () => { pageNumber = 1; filterEvents(); };
    $('clear-filters').onclick = () => {
      for (const id of ['filter-type', 'filter-severity', 'filter-pasture', 'filter-date']) $(id).value = 'all';
      $('search-ear-tag').value = ''; activeTab = 'todas'; pageNumber = 1;
      active(all('.tab-btn'), $('tab-todas')); filterEvents();
    };
    $('events-export').onclick = () => download('bitacora.csv', [['Arete', 'Origen', 'Fecha Unix', 'Tipo', 'Severidad', 'Evento', 'Potrero actual'], ...filteredEvents.map(e => [e.arete, demo(e.arete), e.fecha, e.type, e.severidad, e.mensaje, e.potrero])]);
    $('events-register').onclick = () => { location.href = '/?registro=1'; };
  }
  load().then(() => { if (page === 'panel_general' && new URLSearchParams(location.search).has('registro')) open('modalRegistro'); });
})();
