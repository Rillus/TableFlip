'use strict';

const tablesEl = document.getElementById('tables');
const emptyEl = document.getElementById('empty');
const form = document.getElementById('add-form');
const errorEl = document.getElementById('form-error');

async function api(path, options) {
  const res = await fetch(path, options);
  if (res.status === 204) return null;
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(body.error || `Request failed (${res.status})`);
  }
  return body;
}

function renderTables(tables) {
  tablesEl.innerHTML = '';
  emptyEl.style.display = tables.length ? 'none' : 'block';

  for (const table of tables) {
    const li = document.createElement('li');
    li.className = 'table';
    li.innerHTML = `
      <div class="table-info">
        <span class="table-name"></span>
        <span class="table-seats"></span>
      </div>
      <span class="badge ${table.status}">${table.status}</span>
      <div class="actions">
        <button class="flip" data-id="${table.id}" data-action="flip">Flip</button>
        <button data-id="${table.id}" data-action="delete">Delete</button>
      </div>
    `;
    li.querySelector('.table-name').textContent = table.name;
    li.querySelector('.table-seats').textContent = `${table.seats} seats`;
    tablesEl.appendChild(li);
  }
}

async function refresh() {
  const tables = await api('/api/tables');
  renderTables(tables);
}

form.addEventListener('submit', async (event) => {
  event.preventDefault();
  errorEl.textContent = '';
  const name = document.getElementById('name').value.trim();
  const seats = Number.parseInt(document.getElementById('seats').value, 10) || 2;
  try {
    await api('/api/tables', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name, seats }),
    });
    form.reset();
    document.getElementById('seats').value = 2;
    await refresh();
  } catch (err) {
    errorEl.textContent = err.message;
  }
});

tablesEl.addEventListener('click', async (event) => {
  const button = event.target.closest('button[data-action]');
  if (!button) return;
  const { id, action } = button.dataset;
  try {
    if (action === 'flip') {
      await api(`/api/tables/${id}/flip`, { method: 'POST' });
    } else if (action === 'delete') {
      await api(`/api/tables/${id}`, { method: 'DELETE' });
    }
    await refresh();
  } catch (err) {
    errorEl.textContent = err.message;
  }
});

refresh().catch((err) => {
  errorEl.textContent = err.message;
});
