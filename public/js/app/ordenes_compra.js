document.addEventListener('DOMContentLoaded', () => {
  const itemsContainer = document.getElementById('itemsContainer');
  if (!itemsContainer) return;

  let itemIdx = 0;
  const itemsIniciales = window.itemsIniciales || [];
  const fmt = (n) => new Intl.NumberFormat('es-PY').format(n || 0);

  window.addItemRow = function(data = {}) {
    const tpl = document.getElementById('itemRowTpl').innerHTML.replace(/__i__/g, itemIdx++);
    const wrap = document.createElement('div');
    wrap.innerHTML = tpl;
    const row = wrap.firstElementChild;
    itemsContainer.appendChild(row);

    const desc = row.querySelector('.item-desc');
    const cant = row.querySelector('.item-cant');
    const prec = row.querySelector('.item-precio');
    const tot  = row.querySelector('.item-total');
    const sel  = row.querySelector('select');

    if (data.descripcion) desc.value = data.descripcion;
    if (data.cantidad)    cant.value = data.cantidad;
    if (data.precio)      prec.value = data.precio;
    if (data.articulo_id) sel.value = data.articulo_id;

    if (typeof VanillaSelect !== 'undefined' && !sel.dataset.vanillaInit) {
      sel.dataset.vanillaInit = 'true';
      new VanillaSelect(sel);
    }

    function rowCalc() {
      const t = (parseFloat(cant.value) || 0) * (parseFloat(prec.value) || 0);
      tot.value = fmt(t);
      tot.dataset.val = t;
      window.recalc();
    }

    sel.addEventListener('change', () => {
      const opt = sel.selectedOptions[0];
      if (opt && opt.dataset.precio) {
        prec.value = opt.dataset.precio;
        desc.value = opt.dataset.nombre || opt.textContent.trim();
      } else {
        prec.value = 0;
        desc.value = "";
      }
      rowCalc();
    });

    cant.addEventListener('input', rowCalc);
    prec.addEventListener('input', rowCalc);

    rowCalc();
    if (typeof lucide !== 'undefined') lucide.createIcons();
  };

  window.recalc = function() {
    let total = 0;
    itemsContainer.querySelectorAll('.item-row').forEach(row => {
      total += parseFloat(row.querySelector('.item-total').dataset.val) || 0;
    });
    document.getElementById('total').textContent = fmt(total);
  };

  if (itemsIniciales.length > 0) {
    itemsIniciales.forEach(it => window.addItemRow(it));
  } else {
    window.addItemRow();
  }
});
