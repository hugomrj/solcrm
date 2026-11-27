// ==========================================
// 1. LÓGICA DEL TEMA OSCURO / CLARO
// ==========================================
const themeBtn = document.getElementById('themeBtn');
const html = document.documentElement;

function applyTheme(isDark) {
  if (isDark) {
    html.classList.add('dark');
    themeBtn.innerHTML = '<i data-lucide="sun"></i>';
    localStorage.setItem('theme', 'dark');
  } else {
    html.classList.remove('dark');
    themeBtn.innerHTML = '<i data-lucide="moon"></i>';
    localStorage.setItem('theme', 'light');
  }
  html.classList.add('theming');
  if (typeof lucide !== 'undefined') lucide.createIcons();
}

const savedTheme = localStorage.getItem('theme');
const systemPrefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;

if (savedTheme === 'dark' || (!savedTheme && systemPrefersDark)) {
  applyTheme(true);
} else {
  applyTheme(false);
}

if (themeBtn) {
  themeBtn.addEventListener('click', () => {
    const isCurrentlyDark = html.classList.contains('dark');
    applyTheme(!isCurrentlyDark);
  });
}

// ==========================================
// 2. INICIALIZAR ICONOS LUCIDE
// ==========================================
function initIcons() {
  if (typeof lucide !== 'undefined') lucide.createIcons();
}
document.addEventListener('DOMContentLoaded', initIcons);
setTimeout(initIcons, 100);

// ==========================================
// 3. TOGGLE SIDEBAR EN MÓVIL
// ==========================================
const burger = document.getElementById('burger');
const sideClose = document.getElementById('sideClose');
const scrim = document.getElementById('scrim');

function toggleSidebar() {
  document.body.classList.toggle('side-open');
}
if (burger) burger.addEventListener('click', toggleSidebar);
if (sideClose) sideClose.addEventListener('click', toggleSidebar);
if (scrim) scrim.addEventListener('click', toggleSidebar);

// ==========================================
// 4. TOGGLE MENÚ DE USUARIO
// ==========================================
const avatarBtn = document.getElementById('avatarBtn');
const userMenu = document.getElementById('userMenu');
const userWrap = document.getElementById('userWrap');

if (avatarBtn) {
  avatarBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    userMenu.classList.toggle('open');
  });
}

document.addEventListener('click', (e) => {
  if (userWrap && !userWrap.contains(e.target)) {
    userMenu.classList.remove('open');
  }
});

// ==========================================
// 5. ACORDEÓN DEL SIDEBAR
// ==========================================
window.toggleMenuGroup = function(button) {
  const clickedGroup = button.parentElement;
  const isOpen = clickedGroup.classList.contains('open');

  document.querySelectorAll('.menu-group').forEach(group => {
    group.classList.remove('open');
  });

  if (!isOpen) clickedGroup.classList.add('open');
};

document.addEventListener('click', (e) => {
  if (e.target.closest('.sub-item') && window.innerWidth <= 1023) {
    document.body.classList.remove('side-open');
  }
});

// ==========================================
// 6. BÚSQUEDA EN EL MENÚ (Ctrl+K)
// ==========================================
const globalSearch = document.getElementById('globalSearch');
const menuResults  = document.getElementById('menuResults');

// Sin acentos, minúsculas y espacios colapsados.
// Así "orden" encuentra "Órdenes" y "compra" encuentra "Compras".
function normalizarBusqueda(texto) {
  return (texto || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

// Términos extra por destino: el nombre del menú no siempre es lo que
// el usuario escribe ("pdf", "cobrar", "ticket"...). La clave es el texto
// normalizado del ítem del sidebar.
const ALIAS_MENU = {
  'tablero':              ['inicio', 'resumen', 'home', 'homepage'],
  'pipeline de ventas':   ['embudo', 'oportunidades', 'negocios', 'kanban', 'etapas'],
  'clientes':             ['cartera', 'fichas'],
  'contactos':            ['agenda', 'personas', 'telefonos'],
  'clientes potenciales': ['leads', 'interesados', 'prospectos'],
  'calendario':           ['agenda', 'eventos', 'reuniones', 'mes'],
  'tareas':               ['pendientes', 'todo', 'recordatorios'],
  'llamadas':             ['telefono', 'contactar'],
  'propuestas':           ['cotizacion', 'oferta', 'propuesta'],
  'presupuestos':         ['cotizar', 'costos', 'ppto'],
  'facturas':             ['pdf', 'facturar', 'facturacion', 'iva', 'cobrar', 'comprobante', 'impresora'],
  'pagos':                ['cobrar', 'cobranza', 'cobros', 'recibos', 'transferencia', 'efectivo'],
  'notas de credito':     ['descuento', 'devolucion', 'ajuste factura', 'nc'],
  'articulos':            ['productos', 'catalogo', 'precios', 'items', 'servicios'],
  'soporte':              ['tickets', 'incidencias', 'reclamos', 'ayuda tecnica'],
  'suscripciones':        ['mensual', 'abonos', 'planes', 'contratos'],
  'proyectos':            ['obras', 'trabajos'],
  'compras':              ['abastecimiento'],
  'proveedores':          ['comprar', 'provision', 'importadora'],
  'ordenes de compra':    ['oc', 'pedidos', 'reposicion'],
  'inventario':           ['deposito', 'almacen'],
  'stock':                ['inventario', 'existencias', 'deposito', 'almacen', 'movimientos'],
  'ajustes':              ['inventario', 'conteo', 'correccion', 'merma'],
  'gastos':               ['egresos', 'salidas', 'costos', 'alquiler'],
  'archivos':             ['documentos', 'carpetas'],
  'explorador':           ['archivos', 'documentos', 'descargas', 'adjuntos'],
  'informes':             ['reportes', 'estadisticas', 'graficos'],
  'conversion':           ['reportes', 'embudo', 'ganadas', 'perdidas'],
  'actividad':            ['reportes', 'productividad'],
  'configuracion':        ['ajustes', 'settings', 'empresa'],
  'usuarios':             ['equipo', 'accesos', 'personas'],
  'roles':                ['permisos', 'accesos', 'perfiles'],
};

// Agrupa los destinos por sección del sidebar y deduce el grupo real
// ("Propuestas" vive en Ventas > ...). También registra los rótulos
// de sección para poder buscar "operaciones", "ventas", etc.
function getMenuItems() {
  const items   = [];
  const secciones = [];
  let seccion = '';

  document.querySelectorAll('#sidebar .side-label, #sidebar .menu-item, #sidebar .sub-item').forEach(el => {
    if (el.classList.contains('side-label')) {
      seccion = el.textContent.trim();
      if (seccion) secciones.push({ texto: seccion, grupo: seccion });
      return;
    }

    if (el.tagName !== 'A') {
      // Botón de un grupo desplegable (Ventas, Compras, Informes...):
      // se registra como término de búsqueda, no como destino.
      const grupo = el.querySelector('span') ? el.textContent.trim().replace(/\s+/g, ' ') : '';
      if (grupo) secciones.push({ texto: grupo, grupo: grupo });
      return;
    }

    const href = el.getAttribute('href');
    if (!href || href === '#') return;

    const texto = el.textContent.trim().replace(/\s+/g, ' ');
    // Sub-ítem: el grupo es el botón del desplegable que lo contiene.
    const grupoEl = el.closest('.menu-group');
    const grupo = grupoEl ? grupoEl.querySelector('button').textContent.trim().replace(/\s+/g, ' ') : seccion;

    items.push({
      texto: texto,
      href:  href,
      grupo: grupo || seccion,
      clave: normalizarBusqueda(texto),
    });
  });

  return { items, secciones };
}

const { items: menuItems, secciones: menuSecciones } = getMenuItems();

// La guía de uso no está en el sidebar: se agrega como destino más.
menuItems.push({
  texto: 'Guía de uso',
  href:  '/ayuda',
  grupo: 'Ayuda',
  clave: normalizarBusqueda('guia de uso ayuda tutorial manual learn como funciona'),
  externo: true,
});

// Iniciales de un texto: "Órdenes de Compra" -> "oc" (ignora palabras cortas).
function iniciales(texto) {
  return normalizarBusqueda(texto).split(' ').filter(p => p.length > 2).map(p => p[0]).join('');
}

// Siglas explícitas por destino. Se buscan tal cual y valen alto,
// así "oc" va a Órdenes de Compra y no matchea por letras sueltas.
const SIGLAS_MENU = {
  'ordenes de compra':   ['oc'],
  'notas de credito':    ['nc'],
  'presupuestos':        ['ppto'],
};

// Devuelve un puntaje (>0 = matchea). Cuanto más alto, mejor.
//   100  el texto empieza con la consulta            -> "fact" -> Facturas
//    80  empieza una palabra del texto               -> "comp" -> Órdenes de Compra
//    60  la consulta aparece dentro de una palabra   -> "opera" -> Operaciones
//    40  coinciden las iniciales                     -> "oc" -> Órdenes de Compra
//    30  aparece en un alias cuadrando el prefijo
function puntajeBusqueda(item, tokens, consultaCompleta) {
  const palabras = item.clave.split(/[\s/]+/).filter(Boolean);
  const alias    = (ALIAS_MENU[item.clave] || []).join(' ');
  const aliasPalabras = normalizarBusqueda(alias).split(' ').filter(Boolean);
  const ini      = iniciales(item.texto);
  const siglas   = SIGLAS_MENU[item.clave] || [];

  let total = 0;
  for (const tok of tokens) {
    let mejor = 0;

    // Sigla exacta ("oc", "nc", "ppto"): la prioridad más alta tras el nombre exacto.
    if (siglas.includes(tok))                       mejor = 110;
    else if (item.clave === consultaCompleta)       mejor = 120;
    else if (item.clave.startsWith(tok))            mejor = 100;
    else if (palabras.some(p => p.startsWith(tok))) mejor = 80;
    // "contiene" solo con 3+ letras: con 2 letras matchea de casualidad
    // dentro de otra palabra ("st-oc-k", "pote-nc-iales").
    else if (tok.length >= 3 && palabras.some(p => p.includes(tok))) mejor = 60;
    else if (tok.length >= 3 && ini.startsWith(tok)) mejor = 50;
    // Alias: palabra completa o prefijo de palabra (NO subcadena: "oc" no debe
    // matchear dentro de "negocios").
    else if (tok.length >= 3 && aliasPalabras.some(a => a.startsWith(tok))) mejor = 30;

    if (mejor === 0) return 0;   // todas las palabras tienen que matchear
    total += mejor;
  }
  return total;
}

function buscar(query) {
  const tokens = normalizarBusqueda(query).split(' ').filter(Boolean);
  if (!tokens.length) return [];
  const completa = tokens.join(' ');

  // 1) Destinos que matchean por nombre/alias.
  const destinos = menuItems
    .map(i => ({ item: i, score: puntajeBusqueda(i, tokens, completa) }))
    .filter(r => r.score > 0);

  // 2) Si la consulta coincide con una sección ("operaciones", "ventas"),
  //    sumamos sus módulos como sugerencias, con puntaje más bajo.
  const seccion = menuSecciones.find(s => {
    const t = normalizarBusqueda(s.texto);
    return t.startsWith(completa) || completa.startsWith(t);
  });
  if (seccion) {
    const nombre = normalizarBusqueda(seccion.grupo);
    menuItems.forEach(i => {
      if (destinos.some(d => d.item === i)) return;
      if (normalizarBusqueda(i.grupo) === nombre) {
        destinos.push({ item: i, score: 10, sugerido: true });
      }
    });
  }

  return destinos
    .sort((a, b) => b.score - a.score || a.item.texto.localeCompare(b.item.texto))
    .slice(0, 10);
}

let resultadosActuales = [];
let indiceActivo = -1;

function pintarActivo() {
  menuResults.querySelectorAll('.mr-item').forEach((el, i) => {
    el.classList.toggle('active', i === indiceActivo);
  });
}

function renderResults(query) {
  if (!query || !query.trim()) {
    menuResults.classList.remove('open');
    menuResults.innerHTML = '';
    resultadosActuales = [];
    indiceActivo = -1;
    return;
  }

  resultadosActuales = buscar(query);
  indiceActivo = -1;

  if (resultadosActuales.length === 0) {
    menuResults.innerHTML = '<div class="mr-empty">Sin resultados para “' +
      query.replace(/[<>&"]/g, '') + '”</div>';
    menuResults.classList.add('open');
    return;
  }

  menuResults.innerHTML = resultadosActuales.map(r => `
    <a href="${r.item.href}" class="mr-item"${r.item.externo ? ' target="_blank" rel="noopener"' : ''}>
      <span class="mr-txt">${r.item.texto}</span>
      <span class="mr-group">${r.sugerido ? 'en ' : ''}${r.item.grupo}</span>
    </a>
  `).join('');

  menuResults.classList.add('open');
}

if (globalSearch) {
  globalSearch.addEventListener('input', (e) => renderResults(e.target.value));
  globalSearch.addEventListener('focus', (e) => renderResults(e.target.value));

  document.addEventListener('keydown', (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
      e.preventDefault();
      globalSearch.focus();
      globalSearch.select();
    }
  });

  globalSearch.addEventListener('keydown', (e) => {
    const total = resultadosActuales.length;

    if (e.key === 'ArrowDown' && total > 0) {
      e.preventDefault();
      indiceActivo = (indiceActivo + 1) % total;
      pintarActivo();
      return;
    }
    if (e.key === 'ArrowUp' && total > 0) {
      e.preventDefault();
      indiceActivo = (indiceActivo - 1 + total) % total;
      pintarActivo();
      return;
    }
    if (e.key === 'Enter') {
      e.preventDefault();
      const elegido = resultadosActuales[indiceActivo >= 0 ? indiceActivo : 0];
      if (!elegido) return;
      if (elegido.item.externo) window.open(elegido.item.href, '_blank', 'noopener');
      else window.location.href = elegido.item.href;
      return;
    }
    if (e.key === 'Escape') {
      globalSearch.blur();
      menuResults.classList.remove('open');
      indiceActivo = -1;
    }
  });

  document.addEventListener('click', (e) => {
    if (!e.target.closest('.searchbar-wrap')) {
      menuResults.classList.remove('open');
    }
  });
}



// ==========================================
// 7. MODAL DE CONFIRMACIÓN
// ==========================================
const confirmModal  = document.getElementById('confirmModal');
const confirmOk     = document.getElementById('confirmOk');
const confirmCancel = document.getElementById('confirmCancel');
const confirmTitle  = document.getElementById('confirmTitle');
const confirmMsg    = document.getElementById('confirmMessage');
const confirmIcon   = document.getElementById('confirmIcon');

let pendingForm = null;

function openConfirm(form, opts) {
  pendingForm = form;

  confirmTitle.textContent = opts.title || '¿Estás seguro?';
  confirmMsg.textContent   = opts.message || 'Esta acción no se puede deshacer.';

  // Icono según tipo
  const tipo = opts.type || 'warn';
  confirmIcon.className = 'modal-icon' + (tipo === 'warn' ? '' : ' ' + tipo);
  confirmIcon.innerHTML = '<i data-lucide="' +
    (tipo === 'danger' ? 'trash-2' :
     tipo === 'success' ? 'check-circle-2' : 'alert-triangle') +
    '"></i>';

  // Botón OK
  confirmOk.className = 'btn ' + (tipo === 'danger' ? 'btn-danger' : 'btn-primary');
  confirmOk.textContent = opts.ok || 'Confirmar';

  if (typeof lucide !== 'undefined') lucide.createIcons();

  confirmModal.classList.add('open');
  setTimeout(() => confirmOk.focus(), 50);
}

function closeConfirm() {
  confirmModal.classList.remove('open');
  pendingForm = null;
}

// Interceptar submits con data-confirm
document.addEventListener('submit', (e) => {
  const form = e.target.closest('form[data-confirm]');
  if (!form) return;
  if (form.dataset.confirmed === 'true') return;

  e.preventDefault();

  openConfirm(form, {
    title:   form.dataset.confirmTitle   || '¿Estás seguro?',
    message: form.dataset.confirm,
    type:    form.dataset.confirmType    || 'warn',
    ok:      form.dataset.confirmOk      || 'Confirmar'
  });
});

// Botones del modal
if (confirmOk) {
  confirmOk.addEventListener('click', () => {
    if (!pendingForm) return;
    pendingForm.dataset.confirmed = 'true';
    pendingForm.submit();
    closeConfirm();
  });
}

if (confirmCancel) {
  confirmCancel.addEventListener('click', closeConfirm);
}

// Click en el backdrop cierra
if (confirmModal) {
  confirmModal.addEventListener('click', (e) => {
    if (e.target === confirmModal) closeConfirm();
  });
}

// Esc cierra
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && confirmModal && confirmModal.classList.contains('open')) {
    closeConfirm();
  }
});




// ==========================================
// 8. TOGGLE ACTIVIDAD COMPLETADA
// ==========================================
window.toggleActividad = function(btn) {
  const id = btn.dataset.actividadId;
  if (!id) return;

  const tenantSlug = window.location.pathname.split('/').filter(Boolean)[0];

  fetch(`/${tenantSlug}/actividades/${id}/completar`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
  })
  .then(r => r.json())
  .then(data => {
    if (data.ok) {
      const row = btn.closest('.trow');
      if (row) row.classList.toggle('done', data.completada);
    }
  })
  .catch(err => console.error(err));
};
