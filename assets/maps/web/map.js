import * as maplibregl from './vendor/maplibre-gl.js';
import { layers, namedFlavor } from './vendor/basemaps.js';

const archiveUrl = `${window.location.origin}/maps/data/north-america.pmtiles`;
const message = document.getElementById('map-message');
const about = document.getElementById('about-dialog');

document.getElementById('about-button').addEventListener('click', () => about.showModal());
document.getElementById('close-about').addEventListener('click', () => about.close());

const showUnavailable = (detail) => {
  message.innerHTML = `<strong>Offline map is not ready yet</strong><span>${detail}</span><span>Keep Ethernet and power connected while the map archive downloads.</span>`;
};

const startMap = () => {
  const protocol = new pmtiles.Protocol();
  maplibregl.addProtocol('pmtiles', protocol.tile);

  const map = new maplibregl.Map({
    container: 'map',
    center: [-98.5, 39.5],
    zoom: 3.4,
    maxZoom: 15,
    hash: true,
    attributionControl: true,
    style: {
      version: 8,
      glyphs: `${window.location.origin}/maps/vendor/fonts/{fontstack}/{range}.pbf`,
      sprite: `${window.location.origin}/maps/vendor/sprites/v4/light`,
      sources: {
        protomaps: {
          type: 'vector',
          url: `pmtiles://${archiveUrl}`,
          attribution: '© OpenStreetMap contributors · © Protomaps',
        },
      },
      layers: layers('protomaps', namedFlavor('light'), { lang: 'en' }),
    },
  });

  map.addControl(new maplibregl.NavigationControl({ showCompass: true }), 'top-right');
  map.addControl(new maplibregl.ScaleControl({ maxWidth: 130, unit: 'imperial' }), 'bottom-right');
  map.on('load', () => message.classList.add('hidden'));
  map.on('error', (event) => {
    if (!map.loaded()) showUnavailable(event?.error?.message || 'The local map archive could not be opened.');
  });

  document.querySelectorAll('[data-center]').forEach((button) => {
    button.addEventListener('click', () => {
      const [longitude, latitude, zoom] = button.dataset.center.split(',').map(Number);
      map.flyTo({ center: [longitude, latitude], zoom, essential: true });
    });
  });

  document.getElementById('coordinate-form').addEventListener('submit', (event) => {
    event.preventDefault();
    const latitude = Number(document.getElementById('latitude').value);
    const longitude = Number(document.getElementById('longitude').value);
    if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90 ||
        !Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
      showUnavailable('Enter a valid latitude from -90 to 90 and longitude from -180 to 180.');
      return;
    }
    message.classList.add('hidden');
    map.flyTo({ center: [longitude, latitude], zoom: 12, essential: true });
  });

  map.on('click', (event) => {
    const coordinates = `${event.lngLat.lat.toFixed(5)}, ${event.lngLat.lng.toFixed(5)}`;
    new maplibregl.Popup().setLngLat(event.lngLat).setText(coordinates).addTo(map);
  });
};

fetch(archiveUrl, { method: 'HEAD', cache: 'no-store' })
  .then((response) => {
    if (!response.ok) throw new Error(`Map archive returned HTTP ${response.status}`);
    startMap();
  })
  .catch((error) => showUnavailable(error.message));
