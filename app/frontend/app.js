const statusLine = document.querySelector('#status');
const buttons = [...document.querySelectorAll('[data-choice]')];

async function results() {
  const response = await fetch('/api/results', { cache: 'no-store' });
  if (!response.ok) throw new Error('Results are temporarily unavailable. Please retry.');
  const totals = await response.json();
  for (const choice of ['cats', 'dogs']) {
    document.getElementById(choice).textContent = totals[choice];
  }
}

for (const button of buttons) {
  button.addEventListener('click', async () => {
    buttons.forEach(item => { item.disabled = true; });
    statusLine.textContent = 'Submitting your vote…';
    try {
      const response = await fetch('/api/vote', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ choice: button.dataset.choice }),
      });
      if (!response.ok) throw new Error('Could not save your vote. Please retry.');
      statusLine.textContent = 'Vote saved. Thank you!';
      try { await results(); }
      catch { statusLine.textContent = 'Vote saved; results could not refresh. Reload to see totals.'; }
    } catch (error) {
      statusLine.textContent = error.message;
    } finally {
      buttons.forEach(item => { item.disabled = false; });
    }
  });
}
results().then(() => { statusLine.textContent = 'Ready when you are.'; })
  .catch(error => { statusLine.textContent = error.message; });
