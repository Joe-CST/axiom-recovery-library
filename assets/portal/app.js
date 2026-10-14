(() => {
  'use strict';

  const kiwixBase = `${window.location.protocol}//${window.location.hostname}:8080/`;

  document.querySelectorAll('[data-kiwix]').forEach((link) => {
    link.href = kiwixBase;
  });

  document.querySelectorAll('[data-kiwix-query]').forEach((link) => {
    const query = link.dataset.kiwixQuery || '';
    const url = new URL('search', kiwixBase);
    url.searchParams.set('pattern', query);
    link.href = url.toString();
  });

  const statusGrid = document.getElementById('status-grid');
  if (!statusGrid) return;

  const formatBytes = (bytes) => {
    if (!Number.isFinite(bytes)) return 'Unknown';
    const gib = bytes / (1024 ** 3);
    return `${gib.toFixed(gib >= 100 ? 0 : 1)} GiB`;
  };

  const metric = (value, label, wide = false) => {
    const item = document.createElement('div');
    item.className = `metric${wide ? ' wide' : ''}`;
    const strong = document.createElement('strong');
    const caption = document.createElement('span');
    strong.textContent = value;
    caption.textContent = label;
    item.append(strong, caption);
    return item;
  };

  const countText = (available, expected, legacy) => {
    if (Number.isFinite(available) && Number.isFinite(expected) && expected > 0) {
      return `${available} of ${expected}`;
    }
    return String(Number.isFinite(legacy) ? legacy : 0);
  };

  fetch('/status.json', { cache: 'no-store' })
    .then((response) => {
      if (!response.ok) throw new Error('No status file');
      return response.json();
    })
    .then((status) => {
      const items = [
        metric(status.kiwix === 'ok' ? 'Online' : 'Check', 'Search server'),
        metric(countText(status.zimCount, status.expectedZimCount, status.zimCount), 'Knowledge archives'),
        metric(countText(status.documentCount, status.expectedDocumentCount, status.documentCount), 'Local documents'),
        metric(status.mapState === 'ready' ? 'Ready' : (status.mapState === 'downloading' ? 'Downloading' : 'Not ready'), 'Offline map'),
        metric(formatBytes(status.freeBytes), 'Storage free'),
        metric(status.hotspot === 'ok' ? 'Online' : 'Check', 'Axiom Wi-Fi'),
      ];

      if (status.downloadState && !['complete', 'ready', 'idle'].includes(status.downloadState)) {
        const position = Number(status.currentIndex) > 0 && Number(status.currentTotal) > 0
          ? ` · item ${status.currentIndex} of ${status.currentTotal}`
          : '';
        const bytes = Number(status.currentBytes) > 0 && Number(status.currentTotalBytes) > 0
          ? ` · ${formatBytes(status.currentBytes)} of ${formatBytes(status.currentTotalBytes)}`
          : '';
        const detail = status.currentItem
          ? `${status.downloadState}: ${status.currentItem}${position}${bytes}`
          : status.downloadState;
        items.push(metric(detail, 'Library installation in progress', true));
      }

      statusGrid.replaceChildren(...items);
      statusGrid.setAttribute('aria-busy', 'false');

      const hostLabel = document.getElementById('host-label');
      if (hostLabel) {
        const generated = status.generated ? ` · Updated ${status.generated}` : '';
        hostLabel.textContent = `${status.hostname || 'box'}${generated}`;
      }
    })
    .catch(() => {
      statusGrid.replaceChildren(metric('Starting', 'Status will update shortly', true));
      statusGrid.setAttribute('aria-busy', 'false');
    });
})();
