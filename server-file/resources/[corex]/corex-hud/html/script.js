(function () {
    'use strict';

    const STATUS_TYPES = ['infection', 'poison', 'bleeding', 'sick', 'cold'];
    const HEALTH_CLASSES = ['warning', 'danger', 'critical'];
    const elements = {
        container: null,
        frame: null,
        content: null,
        ammoRow: null,
        ammoCount: null,
        weaponCluster: null,
        weaponImage: null,
        weaponFallback: null,
        healthFill: null,
        healthGhost: null,
        healthValue: null,
        healthContainer: null,
        armorFill: null,
        armorContainer: null,
        utilityInfection: null,
        utilityInfectionCount: null,
        utilityPoison: null,
        utilityPoisonCount: null,
        utilityBleeding: null,
        utilityBleedingCount: null,
        utilitySick: null,
        utilitySickCount: null,
        utilityCold: null,
        utilityColdCount: null,
        utilityHunger: null,
        utilityHungerLevel: null,
        utilityThirst: null,
        utilityThirstLevel: null
    };

    const state = {
        health: 100,
        armor: 0,
        hunger: 100,
        thirst: 100,
        ammoTotal: 0,
        ammoClip: 0,
        ammoMaxClip: 0,
        hasWeapon: false,
        weaponImage: null,
        weaponLabel: null,
        weaponVisualKey: null,
        status: {
            infection: 0,
            poison: 0,
            bleeding: 0,
            sick: 0,
            cold: 0
        }
    };

    function setElementVisible(el, visible) {
        if (!el) return;
        el.classList.toggle('hidden', !visible);
    }

    let initialized = false;
    let healthGhostTimer = null;
    let armorPulseTimer = null;
    let ammoPulseTimer = null;

    function clamp(value, min, max) {
        return Math.max(min, Math.min(max, Number(value) || 0));
    }

    function init() {
        if (initialized) {
            return;
        }

        elements.container = document.getElementById('hud-container');
        elements.frame = document.getElementById('hud-frame');
        elements.content = document.getElementById('hud-content');
        elements.ammoRow = document.getElementById('ammo-row');
        elements.ammoCount = document.getElementById('ammo-count');
        elements.weaponCluster = document.getElementById('weapon-cluster');
        elements.weaponImage = document.getElementById('weapon-image');
        elements.weaponFallback = document.getElementById('weapon-fallback');
        elements.healthFill = document.getElementById('health-bar-fill');
        elements.healthGhost = document.getElementById('health-ghost');
        elements.healthValue = document.getElementById('health-value');
        elements.healthContainer = document.getElementById('health-bar-container');
        elements.armorFill = document.getElementById('armor-bar-fill');
        elements.armorContainer = document.getElementById('armor-bar-container');
        elements.utilityInfection = document.getElementById('utility-infection');
        elements.utilityInfectionCount = document.getElementById('utility-infection-count');
        elements.utilityPoison = document.getElementById('utility-poison');
        elements.utilityPoisonCount = document.getElementById('utility-poison-count');
        elements.utilityBleeding = document.getElementById('utility-bleeding');
        elements.utilityBleedingCount = document.getElementById('utility-bleeding-count');
        elements.utilitySick = document.getElementById('utility-sick');
        elements.utilitySickCount = document.getElementById('utility-sick-count');
        elements.utilityCold = document.getElementById('utility-cold');
        elements.utilityColdCount = document.getElementById('utility-cold-count');
        elements.utilityHunger = document.getElementById('utility-hunger');
        elements.utilityHungerLevel = document.getElementById('utility-hunger-level');
        elements.utilityThirst = document.getElementById('utility-thirst');
        elements.utilityThirstLevel = document.getElementById('utility-thirst-level');

        initialized = true;

        if (elements.content) {
            elements.content.addEventListener('animationend', function (event) {
                if (event.animationName === 'hudSlideIn') {
                    elements.content.classList.remove('animate-in');
                }
            });
        }

        updateScale();
        updateHealth(state.health);
        updateArmor(state.armor);
        updateAmmo(state.ammoTotal, state.ammoClip, state.ammoMaxClip, state.hasWeapon, state.weaponImage, state.weaponLabel);
        updateUtilityIndicators();
    }

    function ensureInit() {
        if (!initialized || !elements.container) {
            init();
        }
    }

    function updateScale() {
        if (!elements.container) return;

        const scale = clamp(window.innerWidth / 1920, 0.75, 1.55);
        elements.container.style.transform = 'scale(' + scale.toFixed(3) + ')';
    }

    function applyConfig(config) {
        if (!config) return;
        ensureInit();

        applyContainerLayout(config);

        if (elements.frame) {
            const perspective = typeof config.perspective === 'number' ? config.perspective : 820;
            elements.frame.style.perspective = perspective + 'px';
            elements.frame.style.perspectiveOrigin = typeof config.perspectiveOrigin === 'string' && config.perspectiveOrigin.trim() !== ''
                ? config.perspectiveOrigin
                : '20% 80%';
        }

        if (!elements.content) return;

        const statusEffects = config.statusEffects || {};
        const colors = config.colors || {};
        elements.content.style.setProperty('--infection-color', statusEffects.infection && statusEffects.infection.color ? statusEffects.infection.color : '#22c55e');
        elements.content.style.setProperty('--poison-color', statusEffects.poison && statusEffects.poison.color ? statusEffects.poison.color : '#a855f7');
        elements.content.style.setProperty('--bleeding-color', statusEffects.bleeding && statusEffects.bleeding.color ? statusEffects.bleeding.color : '#ef4444');
        elements.content.style.setProperty('--sick-color', statusEffects.sick && statusEffects.sick.color ? statusEffects.sick.color : '#eab308');
        elements.content.style.setProperty('--cryo-color', statusEffects.cold && statusEffects.cold.color ? statusEffects.cold.color : '#60a5fa');
        elements.content.style.setProperty('--hunger-color', typeof colors.hunger === 'string' && colors.hunger !== '' ? colors.hunger : '#f59e0b');
        elements.content.style.setProperty('--thirst-color', typeof colors.thirst === 'string' && colors.thirst !== '' ? colors.thirst : '#06b6d4');

        const skewEnabled = config.enable3D !== false;

        if (!skewEnabled) {
            elements.content.classList.add('flat');
            elements.content.style.setProperty('--hud-target-transform', 'none');
            elements.content.style.setProperty('--hud-enter-transform', 'translateY(12px)');
            elements.content.style.transform = 'none';
        } else {
            const rotateX = typeof config.rotateX === 'number' ? config.rotateX : 8;
            const rotateY = typeof config.rotateY === 'number' ? config.rotateY : -12;
            const rotateZ = typeof config.rotateZ === 'number' ? config.rotateZ : -1;
            const targetTransform = 'rotateX(' + rotateX + 'deg) rotateY(' + rotateY + 'deg) rotateZ(' + rotateZ + 'deg)';
            const enterTransform =
                'rotateX(' + (rotateX + 12) + 'deg) rotateY(' + (rotateY - 13) + 'deg) rotateZ(' + (rotateZ - 2) + 'deg) translateZ(-50px)';

            elements.content.classList.remove('flat');
            elements.content.style.setProperty('--hud-target-transform', targetTransform);
            elements.content.style.setProperty('--hud-enter-transform', enterTransform);
            elements.content.style.transform = targetTransform;
        }

        toggleElement(elements.healthContainer, config.showHealth !== false);
        toggleElement(elements.armorContainer, config.showArmor !== false);
        toggleElement(elements.utilityInfection, !statusEffects.infection || statusEffects.infection.show !== false);
        toggleElement(elements.utilityPoison, !statusEffects.poison || statusEffects.poison.show !== false);
        toggleElement(elements.utilityBleeding, !statusEffects.bleeding || statusEffects.bleeding.show !== false);
        toggleElement(elements.utilitySick, !statusEffects.sick || statusEffects.sick.show !== false);
        toggleElement(elements.utilityCold, !statusEffects.cold || statusEffects.cold.show !== false);
        toggleElement(elements.utilityHunger, config.showHunger !== false);
        toggleElement(elements.utilityThirst, config.showThirst !== false);
    }

    function applyContainerLayout(config) {
        if (!elements.container) return;

        const position = config.position || {};
        const minimap = config.minimap || {};
        const anchorY = String(position.y || 'bottom').toLowerCase();
        const minimapAlignY = String(minimap.alignY || 'T').toUpperCase();
        const margin = Number(position.margin);
        const baseMargin = Number.isFinite(margin) ? margin : 24;
        const left = Number(position.x);
        const leftPx = Number.isFinite(left) ? left : 24;
        const spacing = Number(position.minimapSpacing);
        const minimapSpacing = Number.isFinite(spacing) ? spacing : 24;

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

            if (avoidMinimap && showMinimap && (Number.isFinite(minimapHeight) || Number.isFinite(minimapAnchorBottom))) {
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
            if (Number.isFinite(minimapAnchorBottom)) {
                const viewportBottomGap = (1 - minimapAnchorBottom) * 100;
                bottomValue = 'calc(' + viewportBottomGap.toFixed(3) + 'vh + ' + minimapSpacing + 'px)';
            } else if (minimapAlignY === 'B' && Number.isFinite(minimapHeight)) {
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

    function triggerClassOnce(el, className, timerKey, duration) {
        if (!el) return;

        if (timerKey === 'ammo' && ammoPulseTimer) clearTimeout(ammoPulseTimer);
        if (timerKey === 'armor' && armorPulseTimer) clearTimeout(armorPulseTimer);

        el.classList.remove(className);
        void el.offsetWidth;
        el.classList.add(className);

        const timer = setTimeout(function () {
            el.classList.remove(className);
        }, duration);

        if (timerKey === 'ammo') ammoPulseTimer = timer;
        if (timerKey === 'armor') armorPulseTimer = timer;
    }

    function setHealthState(value) {
        if (!elements.healthContainer) return;

        HEALTH_CLASSES.forEach(function (className) {
            elements.healthContainer.classList.remove(className);
        });

        if (value <= 14) {
            elements.healthContainer.classList.add('critical');
        } else if (value <= 39) {
            elements.healthContainer.classList.add('danger');
        } else if (value <= 74) {
            elements.healthContainer.classList.add('warning');
        }
    }

    function animateHealthGhost(previous, next) {
        if (!elements.healthGhost) return;

        if (healthGhostTimer) {
            clearTimeout(healthGhostTimer);
            healthGhostTimer = null;
        }

        if (next >= previous) {
            elements.healthGhost.style.width = next + '%';
            return;
        }

        elements.healthGhost.style.transition = 'none';
        elements.healthGhost.style.width = previous + '%';
        void elements.healthGhost.offsetWidth;

        healthGhostTimer = setTimeout(function () {
            if (!elements.healthGhost) return;
            elements.healthGhost.style.transition = 'width 0.8s ease-out 0.2s, opacity 0.8s ease-out';
            elements.healthGhost.style.width = next + '%';
        }, 40);
    }

    function updateHealth(value) {
        const nextValue = clamp(value, 0, 100);
        const previous = state.health;
        state.health = nextValue;

        if (elements.healthFill) {
            elements.healthFill.style.width = nextValue + '%';
        }

        if (elements.healthValue) {
            elements.healthValue.textContent = String(Math.round(nextValue));
        }

        setHealthState(nextValue);
        animateHealthGhost(previous, nextValue);
    }

    function updateArmor(value) {
        const nextValue = clamp(value, 0, 100);
        const previous = state.armor;
        state.armor = nextValue;

        if (elements.armorFill) {
            elements.armorFill.style.width = nextValue + '%';
        }

        if (elements.armorContainer && nextValue > previous) {
            triggerClassOnce(elements.armorContainer, 'recharging', 'armor', 950);
        }
    }

    const LOCAL_WEAPON_IMAGE_BASE = 'https://cfx-nui-corex-hud/html/weapon-icons/';
    const LOCAL_WEAPON_IMAGE_NUI_BASE = 'nui://corex-hud/html/weapon-icons/';

    function normalizeLocalWeaponKey(value) {
        return String(value || '')
            .trim()
            .replace(/\.[a-z0-9]+$/i, '')
            .replace(/^weapon_/i, '')
            .replace(/\bmk\s*ii\b/ig, 'mk2')
            .replace(/\bmk2\b/ig, 'mk2')
            .replace(/[^a-z0-9]+/ig, '_')
            .replace(/^_+|_+$/g, '')
            .toLowerCase();
    }

    function buildLocalWeaponFileNames(imageName, weaponLabel) {
        const fileNames = [];

        function pushFileName(fileName) {
            const normalized = String(fileName || '').trim();
            if (!normalized) return;
            fileNames.push(normalized);
        }

        function pushVariants(value) {
            const key = normalizeLocalWeaponKey(value);
            if (!key) return;

            pushFileName(key + '.png');
            pushFileName(key.replace(/_/g, '') + '.png');
        }

        if (typeof imageName === 'string' && imageName !== '') {
            pushFileName(imageName);
            pushVariants(imageName);
        }

        pushVariants(weaponLabel);

        return fileNames.filter(function (fileName, index, arr) {
            return fileName && arr.indexOf(fileName) === index;
        });
    }

    function buildWeaponImageCandidates(imageName, weaponLabel) {
        const candidates = [];

        buildLocalWeaponFileNames(imageName, weaponLabel).forEach(function (fileName) {
            candidates.push(LOCAL_WEAPON_IMAGE_BASE + fileName);
            candidates.push(LOCAL_WEAPON_IMAGE_NUI_BASE + fileName);
            candidates.push('./weapon-icons/' + fileName);
            candidates.push('weapon-icons/' + fileName);
        });

        return candidates.filter(function (candidate, index, arr) {
            return candidate && arr.indexOf(candidate) === index;
        });
    }

    function loadWeaponImageCandidate(candidates, index) {
        if (!elements.weaponImage || !elements.weaponFallback) return;

        if (!Array.isArray(candidates) || index >= candidates.length) {
            elements.weaponImage.onload = null;
            elements.weaponImage.onerror = null;
            elements.weaponImage.classList.add('hidden');
            elements.weaponFallback.classList.remove('hidden');
            elements.weaponImage.removeAttribute('src');
            delete elements.weaponImage.dataset.src;
            return;
        }

        const src = candidates[index];
        elements.weaponImage.dataset.src = src;
        elements.weaponImage.onload = function () {
            if (elements.weaponImage.dataset.src !== src) return;
            elements.weaponImage.classList.remove('hidden');
            elements.weaponFallback.classList.add('hidden');
        };

        elements.weaponImage.onerror = function () {
            if (elements.weaponImage.dataset.src !== src) return;
            loadWeaponImageCandidate(candidates, index + 1);
        };

        if (/^https?:\/\//i.test(src) && !/^https:\/\/cfx-nui-/i.test(src)) {
            elements.weaponImage.referrerPolicy = 'no-referrer';
            elements.weaponImage.crossOrigin = 'anonymous';
        } else {
            elements.weaponImage.removeAttribute('crossorigin');
            elements.weaponImage.referrerPolicy = '';
        }
        elements.weaponImage.src = src;
    }

    function setWeaponVisual(hasWeapon, imageName, weaponLabel) {
        if (!elements.weaponImage || !elements.weaponFallback || !elements.weaponCluster) return;

        const showCluster = !!hasWeapon;
        const showImage = showCluster && (
            (typeof weaponLabel === 'string' && weaponLabel !== '') ||
            (typeof imageName === 'string' && imageName !== '')
        );
        state.weaponImage = showImage ? imageName : null;
        state.weaponLabel = showImage && typeof weaponLabel === 'string' && weaponLabel !== '' ? weaponLabel : null;
        elements.weaponCluster.classList.toggle('hidden', !showCluster);

        if (showCluster) {
            const visualKey = [state.weaponImage || '', state.weaponLabel || ''].join('|');
            if (state.weaponVisualKey === visualKey) {
                return;
            }

            state.weaponVisualKey = visualKey;

            if (!showImage) {
                elements.weaponImage.classList.add('hidden');
                elements.weaponFallback.classList.remove('hidden');
                elements.weaponImage.removeAttribute('src');
                delete elements.weaponImage.dataset.src;
                return;
            }

            elements.weaponImage.classList.remove('hidden');
            elements.weaponFallback.classList.add('hidden');
            loadWeaponImageCandidate(buildWeaponImageCandidates(imageName, weaponLabel), 0);
            return;
        }

        state.weaponVisualKey = null;
        elements.weaponImage.classList.add('hidden');
        elements.weaponFallback.classList.add('hidden');
        elements.weaponImage.removeAttribute('src');
        delete elements.weaponImage.dataset.src;
    }

    function updateAmmo(total, clip, maxClip, hasWeapon, weaponImage, weaponLabel) {
        const nextTotal = Math.max(0, Math.round(Number(total) || 0));
        const nextClip = Math.max(0, Math.round(Number(clip) || 0));
        const nextMaxClip = Math.max(0, Math.round(Number(maxClip) || 0));
        const armed = !!hasWeapon;
        const previousTotal = state.ammoTotal;

        state.ammoTotal = nextTotal;
        state.ammoClip = nextClip;
        state.ammoMaxClip = nextMaxClip;
        state.hasWeapon = armed;
        state.weaponImage = weaponImage || null;
        state.weaponLabel = weaponLabel || null;

        if (elements.ammoCount) {
            elements.ammoCount.textContent = armed ? String(nextTotal) : '0';
        }

        setWeaponVisual(armed, weaponImage, weaponLabel);

        if (elements.ammoRow) {
            const critical = armed && ((nextMaxClip > 0 && nextClip / nextMaxClip <= 0.2) || (nextMaxClip <= 0 && nextTotal <= 10));
            elements.ammoRow.classList.toggle('critical', critical);

            if (armed && nextTotal < previousTotal) {
                triggerClassOnce(elements.ammoRow, 'ammo-pulse', 'ammo', 140);
            }
        }
    }

    function setUtilitySeverity(el, severity, zeroIsCooldown) {
        if (!el) return;

        el.classList.remove('warning', 'critical', 'cooldown');

        if (zeroIsCooldown && severity <= 0) {
            el.classList.add('cooldown');
            return;
        }

        if (severity <= 0) {
            return;
        }

        if (severity >= 75) {
            el.classList.add('critical');
        } else if (severity >= 40) {
            el.classList.add('warning');
        }
    }

    function updateResourceIndicator(item, fillEl, value) {
        if (!item || !fillEl) return;

        const nextValue = clamp(value, 0, 100);
        fillEl.style.width = nextValue + '%';

        item.classList.remove('warning', 'critical', 'cooldown');

        if (nextValue <= 0) {
            item.classList.add('cooldown');
        } else if (nextValue <= 20) {
            item.classList.add('critical');
        } else if (nextValue <= 40) {
            item.classList.add('warning');
        }
    }

    function updateUtilityIndicators() {
        function updateStatusIndicator(item, countEl, value) {
            const nextValue = clamp(value, 0, 100);

            if (countEl) {
                countEl.textContent = String(nextValue > 0 ? Math.ceil(nextValue / 25) : 0);
            }

            setUtilitySeverity(item, nextValue, true);
        }

        updateStatusIndicator(elements.utilityInfection, elements.utilityInfectionCount, state.status.infection);
        updateStatusIndicator(elements.utilityPoison, elements.utilityPoisonCount, state.status.poison);
        updateStatusIndicator(elements.utilityBleeding, elements.utilityBleedingCount, state.status.bleeding);
        updateStatusIndicator(elements.utilitySick, elements.utilitySickCount, state.status.sick);
        const coldValue = clamp(state.status.cold, 0, 100);

        if (elements.utilityColdCount) {
            elements.utilityColdCount.textContent = String(coldValue > 0 ? Math.ceil(coldValue / 25) : 0);
        }
        setUtilitySeverity(elements.utilityCold, coldValue, true);

        updateResourceIndicator(elements.utilityHunger, elements.utilityHungerLevel, state.hunger);
        updateResourceIndicator(elements.utilityThirst, elements.utilityThirstLevel, state.thirst);
    }

    function playEntranceAnimation() {
        if (!elements.content) return;
        elements.content.classList.remove('animate-in');
        void elements.content.offsetWidth;
        elements.content.classList.add('animate-in');
    }

    function updateHud(data) {
        ensureInit();

        if (data.health !== undefined) {
            updateHealth(data.health);
        }

        if (data.armor !== undefined) {
            updateArmor(data.armor);
        }

        if (data.hunger !== undefined) {
            state.hunger = clamp(data.hunger, 0, 100);
            updateUtilityIndicators();
        }

        if (data.thirst !== undefined) {
            state.thirst = clamp(data.thirst, 0, 100);
            updateUtilityIndicators();
        }

        if (data.status && typeof data.status === 'object') {
            STATUS_TYPES.forEach(function (type) {
                if (data.status[type] !== undefined) {
                    state.status[type] = clamp(data.status[type], 0, 100);
                }
            });
            updateUtilityIndicators();
        }

        if (data.ammoTotal !== undefined || data.ammoClip !== undefined || data.ammoMaxClip !== undefined || data.hasWeapon !== undefined || data.weaponImage !== undefined || data.weaponLabel !== undefined) {
            updateAmmo(
                data.ammoTotal !== undefined ? data.ammoTotal : state.ammoTotal,
                data.ammoClip !== undefined ? data.ammoClip : state.ammoClip,
                data.ammoMaxClip !== undefined ? data.ammoMaxClip : state.ammoMaxClip,
                data.hasWeapon !== undefined ? data.hasWeapon : state.hasWeapon,
                data.weaponImage !== undefined ? data.weaponImage : state.weaponImage,
                data.weaponLabel !== undefined ? data.weaponLabel : state.weaponLabel
            );
        }
    }

    function setVisible(visible) {
        ensureInit();
        if (!elements.container) return;

        setElementVisible(elements.container, visible);

        if (visible) {
            playEntranceAnimation();
        } else if (elements.content) {
            elements.content.classList.remove('animate-in');
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

            case 'hide':
                setVisible(false);
                break;
        }
    });

    window.addEventListener('resize', updateScale);
    document.addEventListener('DOMContentLoaded', init);
    setTimeout(init, 100);
})();
