import { ref, computed } from "vue"
import { defineStore } from "pinia"
import {lua, useBridge } from "@/bridge"

export const useMinimapStore = defineStore("minimap", () => {
    const { events } = useBridge()

    const nodes = ref({})
    const zoomFactor = ref(3)
    const viewBox = ref('0 0 1000 1000')
    const camRotation = ref(0)
    const isFreeCam = ref(false)
    const playerPos = ref({ x: 0, y: 0 })
    const playerId = ref(0)

    const svgLayers = ref({
        terrain: document.createElementNS("http://www.w3.org/2000/svg", "svg"),
        vehicles: document.createElementNS("http://www.w3.org/2000/svg", "svg"),
        aux: document.createElementNS("http://www.w3.org/2000/svg", "svg")
    })

    function processMapData(data) {
        if (data.terrainTiles) {
            data.terrainTiles.forEach(tile => {
                const image = document.createElementNS(svgLayers.value.terrain.namespaceURI, "image");
                image.setAttribute("x", tile.offset[0]);
                image.setAttribute("y", -tile.offset[1]);
                image.setAttribute("width", tile.size[0]);
                image.setAttribute("height", tile.size[1]);
                image.setAttribute("transform", "scale(-1,-1)");
                
                const correctedPath = tile.file.startsWith('levels/') ? `/${tile.file}` : tile.file;
                image.setAttributeNS("http://www.w3.org/1999/xlink", "href", correctedPath);
                
                svgLayers.value.terrain.appendChild(image);
            });
        }

        if (data.nodes) {
            nodes.value = data.nodes;
            drawRoadNetwork();
        }
    }

    function processMapUpdate(data) {
        isFreeCam.value = data.isFreeCam;
        camRotation.value = data.camRotationZ;
        playerId.value = data.controlID;

        // Clear previous vehicles
        while (svgLayers.value.vehicles.firstChild) {
            svgLayers.value.vehicles.removeChild(svgLayers.value.vehicles.firstChild);
        }

        // Update all objects
        Object.entries(data.objects).forEach(([id, obj]) => {
            playerPos.value = { x: obj.posX, y: obj.posY };
            updateVehicleMarkers(data.objects);
        });

        updateViewBox(data);
    }

    function drawRoadNetwork() {
        const drawRoads = (min, max, color) => {
            Object.values(nodes.value).forEach(node => {
                Object.entries(node.links).forEach(([targetId, link]) => {
                    if (link.drivability >= min && link.drivability <= max) {
                        const targetNode = nodes.value[targetId];
                        const line = document.createElementNS(svgLayers.value.terrain.namespaceURI, "line");
                        line.setAttribute("x1", -node.pos[0]);
                        line.setAttribute("y1", node.pos[1]);
                        line.setAttribute("x2", -targetNode.pos[0]);
                        line.setAttribute("y2", targetNode.pos[1]);
                        line.setAttribute("stroke", getDrivabilityColor(link.drivability));
                        line.setAttribute("stroke-width", Math.max(node.radius, targetNode.radius));
                        svgLayers.value.terrain.appendChild(line);
                    }
                });
            });
        };

        drawRoads(0, 0.1, '#967864');
        drawRoads(0.1, 0.9, '#969678');
        drawRoads(0.9, 1, '#DCDCDC');
    }

    function getDrivabilityColor(d) {
        if (d <= 0.1) return '#967864';
        if (d < 0.9) return '#969678';
        return '#DCDCDC';
    }

    function updateViewBox(data) {
        let parts;
        const zoomFactorValue = zoomFactor.value;

        if (data.isFreeCam) {
            const zoom = 50 * zoomFactorValue;
            parts = [
                data.camPosition.x - zoom,
                data.camPosition.y - zoom,
                zoom * 2,
                zoom * 2
            ];
        } else {
            const baseZoom = Math.min(50 + (data.objects[playerId.value]?.speed * 3.6) * 1.5, 250);
            const zoom = baseZoom * zoomFactorValue;
            parts = [
                playerPos.value.x - zoom,
                playerPos.value.y - zoom,
                zoom * 2,
                zoom * 2
            ];
        }

        viewBox.value = parts.join(' ');
        [svgLayers.value.terrain, svgLayers.value.vehicles, svgLayers.value.aux].forEach(layer => {
            layer.setAttribute('viewBox', viewBox.value);
        });
    }

    function updateVehicleMarkers(objects) {
        Object.entries(objects).forEach(([id, obj]) => {
            const marker = document.createElementNS(svgLayers.value.vehicles.namespaceURI, "polygon");
            marker.setAttribute("points", "0,-10 -8,10 0,7 8,10");
            marker.style.fill = obj.isPlayer ? '#FF6600' : '#607d8b';
            marker.style.stroke = '#ffffff';
            marker.style.strokeWidth = '1.5px';
            marker.setAttribute("transform",
                `translate(${obj.posX},${obj.posY}) 
                 scale(${Math.min(3, 1 + obj.speed * 0.5)}) 
                 rotate(${obj.rot})`
            );
            svgLayers.value.vehicles.appendChild(marker);
        });
    }

    function init() {
        // Handle map data updates
        events.on('PhoneMinimapData', (data) => {
            processMapData(data)
        })

        // Handle real-time updates
        events.on('PhoneMinimapUpdate', (data) => {
            processMapUpdate(data)
        })

        // Load Lua extension
        lua.extensions.load("ui_phoneMinimap")
    }

    function cleanup() {
        events.off('PhoneMinimapData')
        events.off('PhoneMinimapUpdate')
        lua.extensions.unload("ui_phoneMinimap")
    }

    return {
        svgLayers,
        viewBox,
        zoomFactor,
        processMapData,
        processMapUpdate,
        init,
        cleanup
    }
});