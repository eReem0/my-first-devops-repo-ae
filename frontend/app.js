// Фронтенд берёт данные из того же API, что проверяют тесты в CI.
async function load() {
  const list = document.getElementById('items');
  const count = document.getElementById('count');
  const error = document.getElementById('error');
  try {
    const res = await fetch('/api/items');
    if (!res.ok) throw new Error('HTTP ' + res.status);
    const items = await res.json();
    count.textContent = items.length;
    list.innerHTML = '';
    for (const it of items) {
      const li = document.createElement('li');
      li.className = 'item';
      li.dataset.id = it.id;
      li.textContent = it.name;
      list.appendChild(li);
    }
  } catch (e) {
    error.hidden = false;
    error.textContent = 'Не удалось загрузить данные: ' + e.message;
  }
}

load();
