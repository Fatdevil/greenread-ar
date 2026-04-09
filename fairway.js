// ============================================
// GreenRead AR — 2.5D Fairway / GPS Engine
// Drivs av Open-Source MapLibre + ESRI Satellite
// ============================================

const teeBoX = [-81.3935, 30.2010];    // OBS: Lng, Lat i MapLibre/GeoJSON
const greenCenter = [-81.3920, 30.2005];

function initFairwayMap() {
    // Esri World Imagery (Högkvalitativ, gratis satellit, ingen nyckel krävs)
    const esriSatelliteTiles = 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

    const map = new maplibregl.Map({
        container: 'mapContainer',
        style: {
            version: 8,
            sources: {
                'satellite-source': {
                    type: 'raster',
                    tiles: [esriSatelliteTiles],
                    tileSize: 256,
                    maxzoom: 18 // Fixar inzoomningsbuggen! Tillåter digital inzoomning istället för fel.
                }
            },
            layers: [{
                id: 'satellite-layer',
                type: 'raster',
                source: 'satellite-source',
                minzoom: 0,
                maxzoom: 22
            }]
        },
        center: teeBoX,
        zoom: 17,
        pitch: 60, // Detta ger oss 2.5D-effekten!
        bearing: 105 // Vänder upp oss mot greenen
    });

    map.on('load', () => {
        // 1. Rita en premium "Putt-linje" (Fairway tracer)
        map.addSource('route', {
            'type': 'geojson',
            'data': {
                'type': 'Feature',
                'properties': {},
                'geometry': {
                    'type': 'LineString',
                    'coordinates': [teeBoX, greenCenter]
                }
            }
        });

        map.addLayer({
            'id': 'route-line',
            'type': 'line',
            'source': 'route',
            'layout': {
                'line-join': 'round',
                'line-cap': 'round'
            },
            'paint': {
                'line-color': '#22C55E', // Grön
                'line-width': 4,
                'line-dasharray': [2, 2] // Streckad linje ser mer golf-aktigt ut
            }
        });

        // 2. Simulera "Du är här" på fairway
        const playerLng = teeBoX[0] + (greenCenter[0] - teeBoX[0]) * 0.4;
        const playerLat = teeBoX[1] + (greenCenter[1] - teeBoX[1]) * 0.4;
        
        // Markör: Du är här (Blå)
        const elPlayer = document.createElement('div');
        elPlayer.style.width = '16px';
        elPlayer.style.height = '16px';
        elPlayer.style.backgroundColor = '#3B82F6';
        elPlayer.style.border = '3px solid white';
        elPlayer.style.borderRadius = '50%';
        elPlayer.style.boxShadow = '0 0 10px rgba(59, 130, 246, 0.8)';
        
        new maplibregl.Marker(elPlayer)
            .setLngLat([playerLng, playerLat])
            .addTo(map);

        // Markör: Flaggan på Green (Röd)
        const elFlag = document.createElement('div');
        elFlag.innerHTML = '⛳';
        elFlag.style.fontSize = '24px';
        elFlag.style.filter = 'drop-shadow(0px 4px 4px rgba(0,0,0,0.5))';
        
        new maplibregl.Marker(elFlag)
            .setLngLat(greenCenter)
            .addTo(map);

        // 3. Panorera kameran över fairway till spelarens position
        setTimeout(() => {
            map.flyTo({
                center: [playerLng, playerLat],
                zoom: 18.5,
                pitch: 55,
                bearing: 105,
                duration: 4000, // 4 sekunders smidig åktur in mot bollen
                essential: true
            });
            document.getElementById("live-distance").innerText = "65 m till Green";
        }, 1500);
    });
}

document.addEventListener("DOMContentLoaded", () => {
    initFairwayMap();

    const btnAr = document.getElementById("btn-ar");
    btnAr.addEventListener('click', () => {
        document.body.style.transition = "opacity 0.5s ease";
        document.body.style.opacity = "0";
        setTimeout(() => {
            window.location.href = "index.html";
        }, 500);
    });
});
