let currentCode = null;

document.getElementById('shortenBtn').addEventListener('click', async () => {
  const url = document.getElementById('urlInput').value.trim();
  if (!url) return;

  const res = await fetch('/api/shorten', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ url })
  });

  if (!res.ok) {
    alert('Ошибка при сокращении ссылки');
    return;
  }

  const data = await res.json();
  currentCode = data.short_code;

  const shortLink = document.getElementById('shortLink');
  shortLink.href = data.short_url;
  shortLink.textContent = window.location.origin + data.short_url;

  document.getElementById('clickCount').textContent = '0';
  document.getElementById('result').style.display = 'block';
});

document.getElementById('refreshBtn').addEventListener('click', async () => {
  if (!currentCode) return;
  const res = await fetch(`/api/stats/${currentCode}`);
  if (!res.ok) return;
  const data = await res.json();
  document.getElementById('clickCount').textContent = data.click_count;
});
