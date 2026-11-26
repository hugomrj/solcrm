document.addEventListener('DOMContentLoaded', () => {
  const itemsContainer = document.getElementById('itemsContainer');
  if (!itemsContainer) return;

  let itemIdx = 0;
  const itemsIniciales = window.itemsIniciales || [];

  window.addItemRow = function(data = {}) {
    const tpl = document.getElementById('itemRowTpl').innerHTML.replace(/__i__/g, itemIdx++);
    const wrap = document.createElement('div');
    wrap.innerHTML = tpl;
    const row = wrap.firstElementChild;
    itemsContainer.appendChild(row);

    const desc = row.querySelector('.item-desc'); // Ahora es hidden
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
      tot.value = new Intl.NumberFormat('es-PY').format(t);
      tot.dataset.val = t;
      window.recalc();
    }

    // Cuando cambia el select, actualizamos precio y descripción
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
    let sub = 0;
    itemsContainer.querySelectorAll('.item-row').forEach(row => {
      sub += parseFloat(row.querySelector('.item-total').dataset.val) || 0;
    });
    const imp = sub * 0.10;
    const tot = sub + imp;

    const format = (n) => new Intl.NumberFormat('es-PY').format(n);
    
    document.getElementById('subtotal').textContent = format(sub);
    document.getElementById('impuestos').textContent = format(imp);
    document.getElementById('total').textContent = format(tot);
  };

  if (itemsIniciales.length > 0) {
    itemsIniciales.forEach(it => window.addItemRow(it));
  } else {
    window.addItemRow();
  }
});