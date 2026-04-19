(function () {
    'use strict';

    const SVG_SIZE = 48;
    const STATUS_TYPES = ['infection', 'poison', 'bleeding', 'sick', 'cold'];

    const elements = {
        container: null,
        content: null,
        healthBar: null,
        healthContainer: null,
        armorBar: null,
        armorContainer: null,
        hungerBar: null,
        hungerContainer: null,
        thirstBar: null,
        thirstContainer: null,
        playerName: null,
        playerId: null,
        statusRow: null,
        statusIcons: {},
        statusFills: {}
    };

    let initialized = false;

    function init() {
        elements.container = document.getElementById('hud-container');
        elements.content = document.getElementById('hud-content');
        elements.healthBar = document.getElementById('health-bar-wrapper');
        elements.healthContainer = document.getElementById('health-bar-container');
        elements.armorBar = document.getElementById('armor-bar-wrapper');
        elements.armorContainer = document.getElementById('armor-bar-container');
        elements.hungerBar = document.getElementById('hunger-bar-wrapper');
        elements.hungerContainer = document.getElementById('hunger-bar-container');
        elements.thirstBar = document.getElementById('thirst-bar-wrapper');
        elements.thirstContainer = document.getElementById('thirst-bar-container');
        elements.playerName = document.getElementById('player-name');
        elements.playerId = document.getElementById('player-id');
        elements.statusRow = document.getElementById('status-row');

        elements.statusIcons = {};
        elements.statusFills = {};

        STATUS_TYPES.forEach(function (type) {
            const icon = document.querySelector('.status-icon[data-status="' + type + '"]');
            if (icon) {
                elements.statusIcons[type] = icon;
                elements.statusFills[type] = icon.querySelector('.status-fill');
            }
        });

        initialized = true;
    }

    function ensureInit() {
        if (!initialized || !elements.container) {
            init();
        }
    }

    function applyConfig(config) {
        if (!config) return;
        ensureInit();

        applyContainerLayout(config);

        if (elements.content) {
            if (config.enable3D === false) {
                elements.content.classList.add('flat');
            } else {
                elements.content.classList.remove('flat');
                if (typeof config.tiltAngle === 'number') {
                    elements.content.style.transform = 'rotateY(' + config.tiltAngle + 'deg)';
                }
            }
        }

        toggleElement(elements.healthContainer, config.showHealth !== false);
        toggleElement(elements.armorContainer, config.showArmor !== false);
        toggleElement(elements.hungerContainer, config.showHunger !== false);
        toggleElement(elements.thirstContainer, config.showThirst !== false);
        toggleElement(elements.playerName, config.showPlayerName !== false);
    }

    function applyContainerLayout(config) {
        if (!elements.container) return;

        const position = config.position || {};
        const minimap = config.minimap || {};
        const anchorY = String(position.y || 'bottom').toLowerCase();
        const minimapAlignY = String(minimap.alignY || 'T').toUpperCase();
        const margin = Number(position.margin);
        const baseMargin = Number.isFinite(margin) ? margin : 12;
        const left = Number(position.x);
        const leftPx = Number.isFinite(left) ? left : 20;
        const spacing = Number(position.minimapSpacing);
        const minimapSpacing = Number.isFinite(spacing) ? spacing : 12;

        elements.container.style.left = leftPx + 'px';
        elements.container.style.right = 'auto';
        elements.container.style.top = 'auto';
        elements.container.style.bottom = 'auto';

        const avoidMinimap = position.avoidMinimap !== false;
        const showMinimap = config.showMinimap !== false;
        const minimapHeight = Number(minimap.h);
        const minimapOffset = Number(minimap.y);
        const minimapAnchorBottom = Number(minimap.hudAnchorBottom);

        if (anchorY === 'top') {
            let topValue = baseMargin + 'px';

            if (avoidMinimap && showMinimap && minimapAlignY === 'T' && (Number.isFinite(minimapHeight) || Number.isFinite(minimapAnchorBottom))) {
                const safeZoneVh = Number.isFinite(minimapAnchorBottom)
                    ? minimapAnchorBottom * 100
                    : ((Number.isFinite(minimapOffset) ? minimapOffset : 0) + minimapHeight) * 100;
                topValue = 'calc(' + safeZoneVh.toFixed(3) + 'vh + ' + minimapSpacing + 'px)';
            }

            elements.container.style.top = topValue;
            return;
        }

        let bottomValue = baseMargin + 'px';

        if (avoidMinimap && showMinimap) {
            if (minimapAlignY === 'B' && Number.isFinite(minimapHeight)) {
                const safeZoneVh = ((Number.isFinite(minimapOffset) ? minimapOffset : 0) + minimapHeight) * 100;
                bottomValue = 'calc(' + safeZoneVh.toFixed(3) + 'vh + ' + minimapSpacing + 'px)';
            }
        }

        elements.container.style.bottom = bottomValue;
    }

    function toggleElement(el, visible) {
        if (!el) return;
        el.style.display = visible ? '' : 'none';
    }

    function updateBar(barEl, containerEl, value, type) {
        if (!barEl) return;

        const v = Math.max(0, Math.min(100, value));
        barEl.style.width = v + '%';

        if (type === 'health' && containerEl) {
            containerEl.classList.toggle('low', v <= 25);
        }

        if (type === 'hunger' && containerEl) {
            containerEl.classList.toggle('hunger-low', v <= 20);
        }

        if (type === 'thirst' && containerEl) {
            containerEl.classList.toggle('thirst-low', v <= 20);
        }
    }

    function updateStatus(type, value) {
        const icon = elements.statusIcons[type];
        const fill = elements.statusFills[type];
        if (!icon || !fill) return;

        const v = Math.max(0, Math.min(100, Number(value) || 0));

        if (v <= 0) {
            icon.classList.remove('visible');
            fill.setAttribute('y', SVG_SIZE);
            fill.setAttribute('height', 0);
            return;
        }

        icon.classList.add('visible');

        const height = SVG_SIZE * (v / 100);
        const y = SVG_SIZE - height;
        fill.setAttribute('y', y.toFixed(3));
        fill.setAttribute('height', height.toFixed(3));
    }

    function updateHud(data) {
        ensureInit();

        if (data.health !== undefined && elements.healthBar) {
            updateBar(elements.healthBar, elements.healthContainer, data.health, 'health');
        }

        if (data.armor !== undefined && elements.armorBar) {
            updateBar(elements.armorBar, elements.armorContainer, data.armor, 'armor');
        }

        if (data.hunger !== undefined && elements.hungerBar) {
            updateBar(elements.hungerBar, elements.hungerContainer, data.hunger, 'hunger');
        }

        if (data.thirst !== undefined && elements.thirstBar) {
            updateBar(elements.thirstBar, elements.thirstContainer, data.thirst, 'thirst');
        }

        if (data.status && typeof data.status === 'object') {
            STATUS_TYPES.forEach(function (type) {
                if (data.status[type] !== undefined) {
                    updateStatus(type, data.status[type]);
                }
            });
        }

        if (data.playerName && elements.playerName) {
            elements.playerName.textContent = data.playerName;
        }

        if (data.playerId !== undefined && elements.playerId) {
            elements.playerId.textContent = '#' + data.playerId;
        }

        if (data.talking !== undefined) {
            const header = document.querySelector('.hud-header');
            if (header) header.classList.toggle('talking', !!data.talking);
        }
    }

    function setVisible(visible) {
        ensureInit();
        if (!elements.container) return;

        if (visible) {
            elements.container.classList.remove('hidden');
        } else {
            elements.container.classList.add('hidden');
        }
    }

    window.addEventListener('message', function (event) {
        const data = event.data;
        if (!data || !data.action) return;

        switch (data.action) {
            case 'init':
                init();
                if (data.config) applyConfig(data.config);
                break;

            case 'updateHud':
                updateHud(data);
                break;

            case 'setVisible':
                setVisible(data.visible);
                break;

            case 'applyConfig':
                applyConfig(data.config);
                break;
        }
    });

    document.addEventListener('DOMContentLoaded', init);

    setTimeout(init, 100);
})();
