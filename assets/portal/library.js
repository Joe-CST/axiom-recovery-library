(() => {
  'use strict';

  const CATEGORY_LABELS = {
    medical: 'Medical & first aid',
    water: 'Water & sanitation',
    agriculture: 'Agriculture & growing',
    food: 'Food & nutrition',
    shelter: 'Shelter & construction',
    energy: 'Power & machinery',
    tools: 'Tools, repair & fabrication',
    communications: 'Communications',
    navigation: 'Navigation & maps',
    community: 'Community & society',
    preparedness: 'Preparedness',
    nuclear: 'Radiation & nuclear safety',
    education: 'Science & education',
  };

  const CATEGORY_ORDER = Object.keys(CATEGORY_LABELS);
  const FALLBACK_SUMMARIES = {
    medical: 'First aid, wound care, illness, medicines, hygiene, maternal health, dental care, and public health.',
    water: 'Water sources, collection, testing, treatment, storage, pumps, sanitation, and waste systems.',
    agriculture: 'Crop planning, soil, seeds, propagation, irrigation, pests, greenhouses, livestock, and harvesting.',
    food: 'Nutrition, cooking, preservation, fermentation, canning, drying, and safe food storage.',
    shelter: 'Emergency shelter, site assessment, carpentry, masonry, roofing, insulation, ventilation, and fire safety.',
    energy: 'Load planning, solar, wind, hydro, batteries, generators, motors, engines, pumps, and electrical safety.',
    tools: 'Hand tools, workshop practice, salvage, metalwork, woodworking, electronics, textiles, and repair.',
    communications: 'Radio, antennas, signaling, networks, information handling, and emergency communication.',
    navigation: 'Maps, compass skills, coordinates, route planning, surveying, and field navigation.',
    community: 'Organization, governance, public health, education, records, logistics, conflict resolution, and trade.',
    preparedness: 'Risk assessment, supplies, evacuation, severe weather, fire, flood, earthquake, and recovery planning.',
    nuclear: 'Radiation fundamentals, monitoring, protection, decontamination, reactor concepts, and legal safety context.',
    education: 'Mathematics, science, engineering, language, teaching, and foundational reference material.',
  };

  const kiwixBase = `${window.location.protocol}//${window.location.hostname}:8080/`;
  const searchForm = document.getElementById('catalog-search');
  const searchInput = document.getElementById('search-input');
  const filterBar = document.getElementById('category-filters');
  const grid = document.getElementById('catalog-grid');
  const summary = document.getElementById('catalog-summary');
  const params = new URLSearchParams(window.location.search);

  let items = [];
  let selectedCategory = CATEGORY_LABELS[params.get('category')] ? params.get('category') : 'all';
  let query = params.get('q') || '';

  searchInput.value = query;

  const normalized = (value) => String(value ?? '').toLocaleLowerCase();
  const formatBytes = (bytes) => {
    if (!Number.isFinite(bytes) || bytes <= 0) return '';
    const mib = bytes / (1024 ** 2);
    return mib >= 1024 ? `${(mib / 1024).toFixed(1)} GiB` : `${Math.round(mib)} MiB`;
  };
  const searchUrl = (terms) => {
    const url = new URL('search', kiwixBase);
    url.searchParams.set('pattern', terms);
    return url.toString();
  };
  const itemSearchText = (item) => normalized([
    item.title,
    item.summary,
    item.source,
    item.license,
    item.category,
    item.categoryLabel,
    ...(Array.isArray(item.searchTerms) ? item.searchTerms : []),
  ].join(' '));

  const fallbackItems = () => CATEGORY_ORDER.map((category) => ({
    type: 'kiwix',
    category,
    categoryLabel: CATEGORY_LABELS[category],
    title: CATEGORY_LABELS[category],
    summary: FALLBACK_SUMMARIES[category],
    source: 'Local knowledge archives',
    license: 'See each source',
    available: true,
    href: '__KIWIX__',
    searchTerms: [CATEGORY_LABELS[category], ...FALLBACK_SUMMARIES[category].split(',').slice(0, 3)],
    fallback: true,
  }));

  const normalizeCatalogItem = (item, type) => ({
    ...item,
    type: item.type || type,
    category: CATEGORY_LABELS[item.category] ? item.category : 'education',
    categoryLabel: item.categoryLabel || CATEGORY_LABELS[item.category] || 'Science & education',
    title: item.title || 'Untitled reference',
    summary: item.summary || 'Local reference material.',
    source: item.source || 'Source information not listed',
    license: item.license || 'See source',
    available: Boolean(item.available),
    searchTerms: Array.isArray(item.searchTerms) ? item.searchTerms : [],
  });

  const updateUrl = () => {
    const next = new URLSearchParams();
    if (selectedCategory !== 'all') next.set('category', selectedCategory);
    if (query) next.set('q', query);
    const suffix = next.toString();
    window.history.replaceState(null, '', `${window.location.pathname}${suffix ? `?${suffix}` : ''}`);
  };

  const makeButton = (id, label) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.textContent = label;
    button.dataset.category = id;
    button.setAttribute('aria-pressed', String(selectedCategory === id));
    button.addEventListener('click', () => {
      selectedCategory = id;
      renderFilters();
      renderItems();
      updateUrl();
    });
    return button;
  };

  const renderFilters = () => {
    const present = new Set(items.map((item) => item.category));
    const buttons = [makeButton('all', 'All topics')];
    CATEGORY_ORDER.filter((id) => present.has(id)).forEach((id) => {
      buttons.push(makeButton(id, CATEGORY_LABELS[id]));
    });
    filterBar.replaceChildren(...buttons);
    filterBar.querySelector('[aria-pressed="true"]')?.scrollIntoView({ inline: 'center', block: 'nearest' });
  };

  const textPair = (list, term, description) => {
    const dt = document.createElement('dt');
    const dd = document.createElement('dd');
    dt.textContent = term;
    dd.textContent = description;
    list.append(dt, dd);
  };

  const makeResourceCard = (item) => {
    const card = document.createElement('article');
    card.className = 'resource-card';

    const header = document.createElement('header');
    const title = document.createElement('h2');
    const badge = document.createElement('span');
    title.textContent = item.title;
    badge.className = `badge${item.available ? '' : ' missing'}`;
    badge.textContent = item.available ? 'Installed' : 'Not installed';
    header.append(title, badge);

    const description = document.createElement('p');
    description.textContent = item.summary;

    const details = document.createElement('dl');
    textPair(details, 'Topic', item.categoryLabel);
    textPair(details, 'Source', item.source);
    if (item.license) textPair(details, 'License', item.license);
    if (item.historical) textPair(details, 'Date note', 'Historical material—verify current guidance');
    const size = formatBytes(item.bytes);
    if (size) textPair(details, 'Size', size);

    const actions = document.createElement('div');
    actions.className = 'resource-actions';
    if (item.available && item.href) {
      const open = document.createElement('a');
      open.className = 'primary-action';
      open.href = item.href === '__KIWIX__' ? kiwixBase : item.href;
      open.textContent = item.type === 'document' ? 'Open document' : 'Open archive';
      actions.append(open);
    }

    const related = document.createElement('a');
    const terms = item.searchTerms[0] || `${item.categoryLabel} ${item.title}`;
    related.href = searchUrl(terms);
    related.textContent = 'Search related knowledge';
    actions.append(related);

    card.append(header, description, details, actions);
    return card;
  };

  const renderItems = () => {
    const words = normalized(query).split(/\s+/).filter(Boolean);
    const matching = items.filter((item) => {
      if (selectedCategory !== 'all' && item.category !== selectedCategory) return false;
      const haystack = itemSearchText(item);
      return words.every((word) => haystack.includes(word));
    });

    if (!matching.length) {
      const empty = document.createElement('section');
      empty.className = 'empty-state';
      const heading = document.createElement('h2');
      const detail = document.createElement('p');
      const link = document.createElement('a');
      heading.textContent = 'No catalog entries match';
      detail.textContent = 'Try fewer words, choose All topics, or search the full-text archives.';
      link.href = searchUrl(query || CATEGORY_LABELS[selectedCategory] || 'preparedness');
      link.textContent = 'Search every archive instead';
      empty.append(heading, detail, link);
      grid.replaceChildren(empty);
    } else {
      grid.replaceChildren(...matching.map(makeResourceCard));
    }

    const installed = matching.filter((item) => item.available).length;
    summary.textContent = `Showing ${matching.length} reference${matching.length === 1 ? '' : 's'} · ${installed} installed`;
    grid.setAttribute('aria-busy', 'false');
  };

  searchForm.addEventListener('submit', (event) => {
    event.preventDefault();
    query = searchInput.value.trim();
    renderItems();
    updateUrl();
    summary.scrollIntoView({ block: 'nearest' });
  });
  searchInput.addEventListener('search', () => {
    query = searchInput.value.trim();
    renderItems();
    updateUrl();
  });

  fetch('/catalog.json', { cache: 'no-store' })
    .then((response) => {
      if (!response.ok) throw new Error(`Catalog returned HTTP ${response.status}`);
      return response.json();
    })
    .then((catalog) => {
      const documents = Array.isArray(catalog.documents) ? catalog.documents : [];
      const collections = Array.isArray(catalog.collections) ? catalog.collections : [];
      items = [
        ...documents.map((item) => normalizeCatalogItem(item, 'document')),
        ...collections.map((item) => normalizeCatalogItem(item, 'kiwix')),
      ];
      if (!items.length) throw new Error('Catalog is empty');
      renderFilters();
      renderItems();
    })
    .catch(() => {
      items = fallbackItems();
      const warning = document.createElement('div');
      warning.className = 'catalog-note';
      warning.innerHTML = '<strong>The detailed catalog is still being prepared.</strong><p>These topic searches and the document browser remain available while installation continues.</p>';
      grid.before(warning);
      renderFilters();
      renderItems();
    });
})();
