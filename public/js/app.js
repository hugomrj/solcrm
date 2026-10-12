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

function getMenuItems() {
  const items = [];
  document.querySelectorAll('#sidebar .menu-item, #sidebar .sub-item').forEach(a => {
    if (a.tagName === 'A' && a.getAttribute('href') && a.getAttribute('href') !== '#') {
      items.push({
        texto: a.textContent.trim().replace(/\s+/g, ' '),
        href:  a.getAttribute('href')
      });
    }
  });
  return items;
}

const menuItems = getMenuItems();

function renderResults(query) {
  if (!query || query.length < 1) {
    menuResults.classList.remove('open');
    menuResults.innerHTML = '';
    return;
  }

  const q = query.toLowerCase();
  const matches = menuItems.filter(i => i.texto.toLowerCase().includes(q)).slice(0, 8);

  if (matches.length === 0) {
    menuResults.innerHTML = '<div class="mr-empty">Sin resultados</div>';
    menuResults.classList.add('open');
    return;
  }

  menuResults.innerHTML = matches.map(m => `
    <a href="${m.href}" class="mr-item">
      <span>${m.texto}</span>
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
    if (e.key === 'Enter') {
      const first = menuResults.querySelector('.mr-item');
      if (first) window.location.href = first.getAttribute('href');
    }
    if (e.key === 'Escape') {
      globalSearch.blur();
      menuResults.classList.remove('open');
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