// public/js/pipeline.js
// Drag & drop del pipeline de oportunidades

document.addEventListener('DOMContentLoaded', () => {
  initPipelineDragDrop();
});

function initPipelineDragDrop() {
  const kanban = document.getElementById('kanban');
  if (!kanban) return;

  let draggedCard = null;

  // --- Cards ---
  kanban.querySelectorAll('.kcard').forEach(card => {
    card.addEventListener('dragstart', (e) => {
      draggedCard = card;
      card.classList.add('dragging');
      e.dataTransfer.effectAllowed = 'move';
      e.dataTransfer.setData('text/plain', card.dataset.oportunidadId);
    });

    card.addEventListener('dragend', () => {
      card.classList.remove('dragging');
      draggedCard = null;
      kanban.querySelectorAll('.kcol').forEach(c => c.classList.remove('over'));
    });
  });

  // --- Columnas ---
  kanban.querySelectorAll('.kcol').forEach(col => {
    col.addEventListener('dragover', (e) => {
      e.preventDefault();
      e.dataTransfer.dropEffect = 'move';

      if (!col.classList.contains('over')) {
        kanban.querySelectorAll('.kcol').forEach(c => c.classList.remove('over'));
        col.classList.add('over');
      }
    });

    col.addEventListener('dragleave', (e) => {
      // Solo quitar cuando salimos de la columna realmente
      if (!col.contains(e.relatedTarget)) {
        col.classList.remove('over');
      }
    });

    col.addEventListener('drop', async (e) => {
      e.preventDefault();
      col.classList.remove('over');

      if (!draggedCard) return;

      const oportunidadId = draggedCard.dataset.oportunidadId;
      const nuevaEtapaId  = col.dataset.etapaId;
      const etapaActual   = draggedCard.closest('.kcol').dataset.etapaId;

      if (etapaActual === nuevaEtapaId) return;

      const stack = col.querySelector('.kstack');

      // Mover la card visualmente (optimista)
      stack.appendChild(draggedCard);

      // Actualizar contadores de ambas columnas
      updateColumnCounts();

      // Enviar al servidor
      try {
        const resp = await fetch(`/${getTenantSlug()}/pipeline/${oportunidadId}/mover`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: `etapa_id=${nuevaEtapaId}`
        });

        if (!resp.ok) throw new Error('Error al mover');
      } catch (err) {
        console.error(err);
        // Revertir si falla
        location.reload();
      }
    });
  });

  function updateColumnCounts() {
    kanban.querySelectorAll('.kcol').forEach(col => {
      const cards = col.querySelectorAll('.kcard').length;
      const badge = col.querySelector('.kcol-h .n');
      if (badge) badge.textContent = cards;
    });
  }

  function getTenantSlug() {
    // El slug es el primer segmento del path: /acme/pipeline → "acme"
    return window.location.pathname.split('/').filter(Boolean)[0];
  }
}