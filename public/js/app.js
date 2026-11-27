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
// Busca SOLO por el título de cada ítem del sidebar.
// Sin alias, sin siglas, sin sugerencias: cada resultado es un destino real
// y lo que buscás es lo que ves escrito en el menú.
const globalSearch = document.getElementById('globalSearch');
const menuResults  = document.getElementById('menuResults');

// Sin acentos, minúsculas y espacios colapsados:
// "orden" encuentra "Órdenes" y "Ajustes" == "ajustes".
function normalizarBusqueda(texto) {
  return (texto || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

// Títulos de los ítems navegables del sidebar, con su grupo (solo para mostrar).
function getMenuItems() {
  const items = [];
  let seccion = '';

  document.querySelectorAll('#sidebar .side-label, #sidebar .menu-item, #sidebar .sub-item').forEach(el => {
    if (el.classList.contains('side-label')) {
      seccion = el.textContent.trim();
      return;
    }
    if (el.tagName !== 'A') return;

    const href = el.getAttribute('href');
    if (!href || href === '#') return;

    const texto = el.textContent.trim().replace(/\s+/g, ' ');
    const grupoEl = el.closest('.menu-group');
    const grupo = grupoEl
      ? grupoEl.querySelector('button').textContent.trim().replace(/\s+/g, ' ')
      : seccion;

    items.push({ texto, href, grupo });
  });

  return items;
}

const menuItems = getMenuItems();

// Un título matchea si TODAS las palabras escritas empiezan alguna palabra del título.
//   "fact"         -> Facturas
//   "orden compra" -> Órdenes de Compra
function coincide(titulo, tokens, consulta) {
  const normal = normalizarBusqueda(titulo);
  if (normal === consulta) return 2;            // coincidencia exacta primero
  const palabras = normal.split(/[\s/]+/).filter(Boolean);
  return tokens.every(tok => palabras.some(p => p.startsWith(tok))) ? 1 : 0;
}

function buscar(query) {
  const tokens = normalizarBusqueda(query).split(' ').filter(Boolean);
  if (!tokens.length) return [];
  const consulta = tokens.join(' ');

  return menuItems
    .map(i => ({ item: i, score: coincide(i.texto, tokens, consulta) }))
    .filter(r => r.score > 0)
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
    menuResults.innerHTML = '<div class="mr-empty">Sin resultados</div>';
    menuResults.classList.add('open');
    return;
  }

  menuResults.innerHTML = resultadosActuales.map(r => `
    <a href="${r.item.href}" class="mr-item">
      <span class="mr-txt">${r.item.texto}</span>
      <span class="mr-group">${r.item.grupo}</span>
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
