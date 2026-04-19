/**
 * COREX Outfit - UI Script
 * Handles clothing customization interface
 */

// Resource name constant (used for NUI callbacks)
const RESOURCE_NAME = 'corex-spawn';

// Category configurations
const categories = {
    face: {
        title: 'FACE',
        components: [
            { id: 0, label: 'FACE SHAPE', key: 'face' }
        ]
    },
    mask: {
        title: 'MASKS',
        components: [
            { id: 1, label: 'MASK MODEL', key: 'mask' }
        ]
    },
    hair: {
        title: 'HAIR',
        components: [
            { id: 2, label: 'HAIR STYLE', key: 'hair' }
        ]
    },
    torso: {
        title: 'TORSO & JACKETS',
        components: [
            { id: 3, label: 'TORSO / JACKET', key: 'torso' },
            { id: 8, label: 'UNDERSHIRT', key: 'undershirt' },
            { id: 11, label: 'OVERLAY / DECALS', key: 'overlay' }
        ]
    },
    legs: {
        title: 'LEGS & PANTS',
        components: [
            { id: 4, label: 'PANTS / LEGS', key: 'legs' }
        ]
    },
    shoes: {
        title: 'SHOES & FEET',
        components: [
            { id: 6, label: 'SHOES', key: 'shoes' }
        ]
    },
    accessories: {
        title: 'ACCESSORIES',
        components: [
            { id: 5, label: 'BAGS / PARACHUTE', key: 'bags' },
            { id: 7, label: 'ACCESSORY', key: 'accessory' },
            { id: 9, label: 'BODY ARMOR', key: 'kevlar' },
            { id: 10, label: 'BADGE / EMBLEM', key: 'badge' }
        ],
        props: [
            { id: 0, label: 'HATS / HELMETS', key: 'hats' },
            { id: 1, label: 'GLASSES', key: 'glasses' },
            { id: 2, label: 'EARRINGS', key: 'ears' },
            { id: 6, label: 'WATCHES', key: 'watches' },
            { id: 7, label: 'BRACELETS', key: 'bracelets' }
        ]
    }
};

let currentCategory = 'face';
let clothingData = null;
let currentMode = 'creation';
let allowCancel = false;
let currentSkin = {
    components: {},
    props: {}
};

// DOM Elements
const uiContainer = document.getElementById('ui-container');
const categoryTitle = document.getElementById('category-title');
const itemCount = document.getElementById('item-count');
const controlsContainer = document.getElementById('controls-container');
const cancelButton = document.getElementById('btn-cancel');

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    setupEventListeners();
});

// Setup Event Listeners
function setupEventListeners() {
    // Category buttons
    document.querySelectorAll('.cat-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.cat-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            currentCategory = btn.dataset.category;
            renderControls();
        });
    });

    // Gender buttons
    document.querySelectorAll('.gender-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.gender-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            changeGender(btn.dataset.gender);
        });
    });

    // Rotation buttons
    document.getElementById('rotate-left').addEventListener('click', () => {
        fetch(`https://${RESOURCE_NAME}/rotateCharacter`, {
            method: 'POST',
            body: JSON.stringify({ direction: 'left' })
        });
    });

    document.getElementById('rotate-right').addEventListener('click', () => {
        fetch(`https://${RESOURCE_NAME}/rotateCharacter`, {
            method: 'POST',
            body: JSON.stringify({ direction: 'right' })
        });
    });

    // Action buttons
    cancelButton.addEventListener('click', () => {
        if (!allowCancel) return;
        closeUI();
    });
    document.getElementById('btn-confirm').addEventListener('click', confirmSelection);

    // Keyboard controls - only Escape to close
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && allowCancel) {
            closeUI();
        }
    });

    // Mouse wheel for zoom
    document.addEventListener('wheel', (e) => {
        e.preventDefault();
        const direction = e.deltaY > 0 ? 'out' : 'in';
        fetch(`https://${RESOURCE_NAME}/zoomCamera`, {
            method: 'POST',
            body: JSON.stringify({ direction: direction })
        });
    }, { passive: false });
}

// NUI Message Handler
window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.action) {
        case 'open':
            clothingData = data.clothing;
            currentMode = data.mode || 'creation';
            allowCancel = data.allowCancel === true;
            initializeSkinData();
            syncCancelState();
            showUI();
            renderControls();
            break;
        case 'close':
            hideUI();
            break;
    }
});

// Initialize skin data from clothing data
function initializeSkinData() {
    if (!clothingData) return;

    currentSkin.components = {};
    currentSkin.props = {};

    // Initialize components
    if (clothingData.components) {
        for (const [id, data] of Object.entries(clothingData.components)) {
            currentSkin.components[id] = {
                drawable: data.drawable,
                texture: data.texture,
                maxDrawable: data.maxDrawable,
                maxTexture: data.maxTexture
            };
        }
    }

    // Initialize props
    if (clothingData.props) {
        for (const [id, data] of Object.entries(clothingData.props)) {
            currentSkin.props[id] = {
                drawable: data.drawable,
                texture: data.texture,
                maxDrawable: data.maxDrawable,
                maxTexture: data.maxTexture
            };
        }
    }
}

// Show/Hide UI
function showUI() {
    uiContainer.style.display = 'flex';
}

function hideUI() {
    uiContainer.style.display = 'none';
}

function syncCancelState() {
    cancelButton.classList.toggle('is-hidden', !allowCancel);
    cancelButton.disabled = !allowCancel;
    uiContainer.dataset.mode = currentMode;
}

function clampNumber(value, min, max) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) return min;
    return Math.max(min, Math.min(max, parsed));
}

function getControlData(type, id) {
    const source = type === 'component'
        ? (clothingData?.components?.[id] || {})
        : (clothingData?.props?.[id] || {});
    const current = type === 'component'
        ? (currentSkin.components?.[id] || {})
        : (currentSkin.props?.[id] || {});

    const minDrawable = type === 'prop' ? -1 : 0;
    const maxDrawable = Number(source.maxDrawable ?? current.maxDrawable ?? 0);
    const maxTexture = Number(current.maxTexture ?? source.maxTexture ?? 0);
    const drawable = clampNumber(current.drawable ?? source.drawable ?? minDrawable, minDrawable, maxDrawable);
    const texture = clampNumber(current.texture ?? source.texture ?? 0, 0, maxTexture);

    return {
        drawable,
        texture,
        maxDrawable,
        maxTexture
    };
}

function setCurrentSkinValue(type, id, drawable, texture, maxTexture) {
    const target = type === 'component' ? currentSkin.components : currentSkin.props;
    const existing = target[id] || {};
    target[id] = {
        ...existing,
        drawable,
        texture,
        maxTexture: maxTexture !== undefined ? maxTexture : existing.maxTexture
    };
}

// Render controls for current category
function renderControls() {
    const category = categories[currentCategory];
    if (!category) return;

    categoryTitle.textContent = category.title;

    let totalItems = 0;
    let html = '';

    // Render component controls
    if (category.components) {
        category.components.forEach(comp => {
            const compData = getControlData('component', comp.id);
            totalItems += compData.maxDrawable || 0;

            html += createControlGroup(
                comp.label,
                comp.id,
                'component',
                compData.drawable,
                compData.maxDrawable,
                compData.texture,
                compData.maxTexture
            );
        });
    }

    // Render prop controls
    if (category.props) {
        if (category.components && category.components.length > 0) {
            html += '<div class="divider"></div>';
        }

        category.props.forEach(prop => {
            const propData = getControlData('prop', prop.id);
            totalItems += propData.maxDrawable || 0;

            html += createControlGroup(
                prop.label,
                prop.id,
                'prop',
                propData.drawable,
                propData.maxDrawable,
                propData.texture,
                propData.maxTexture
            );
        });
    }

    itemCount.textContent = `${totalItems} ITEMS`;
    controlsContainer.innerHTML = html;

    // Attach slider events
    attachSliderEvents();
}

// Create control group HTML
function createControlGroup(label, id, type, drawable, maxDrawable, texture, maxTexture) {
    const displayValue = drawable === -1 ? 'OFF' : String(drawable).padStart(2, '0');

    return `
        <div class="control-group" data-id="${id}" data-type="${type}">
            <div class="group-header">
                <span class="group-label">${label}</span>
                <span class="group-value" id="${type}-${id}-value">${displayValue}</span>
            </div>
            <input type="range" 
                   min="${type === 'prop' ? -1 : 0}" 
                   max="${maxDrawable}" 
                   value="${drawable}" 
                   class="cyber-slider drawable-slider"
                   data-id="${id}"
                   data-type="${type}">
            
            <div class="group-header" style="margin-top: 10px;">
                <span class="group-label">TEXTURE</span>
                <span class="group-value" id="${type}-${id}-texture-value">${String(texture).padStart(2, '0')}</span>
            </div>
            <input type="range" 
                   min="0" 
                   max="${maxTexture}" 
                   value="${texture}" 
                   class="cyber-slider texture-slider"
                   data-id="${id}"
                   data-type="${type}">
        </div>
    `;
}

// Attach events to sliders
function attachSliderEvents() {
    // Drawable sliders
    document.querySelectorAll('.drawable-slider').forEach(slider => {
        slider.addEventListener('input', (e) => {
            const id = parseInt(e.target.dataset.id);
            const type = e.target.dataset.type;
            const value = parseInt(e.target.value);

            // Update display
            const displayValue = value === -1 ? 'OFF' : String(value).padStart(2, '0');
            document.getElementById(`${type}-${id}-value`).textContent = displayValue;

            // Get current texture
            const textureSlider = e.target.parentElement.querySelector('.texture-slider');
            const texture = parseInt(textureSlider.value) || 0;
            setCurrentSkinValue(type, id, value, texture);

            // Send update to game
            updateClothing(type, id, value, texture);
        });
    });

    // Texture sliders
    document.querySelectorAll('.texture-slider').forEach(slider => {
        slider.addEventListener('input', (e) => {
            const id = parseInt(e.target.dataset.id);
            const type = e.target.dataset.type;
            const value = parseInt(e.target.value);

            // Update display
            document.getElementById(`${type}-${id}-texture-value`).textContent = String(value).padStart(2, '0');

            // Get current drawable
            const drawableSlider = e.target.parentElement.querySelector('.drawable-slider');
            const drawable = parseInt(drawableSlider.value);
            setCurrentSkinValue(type, id, drawable, value);

            // Send update to game
            updateClothing(type, id, drawable, value);
        });
    });
}

// Update clothing on character
function updateClothing(type, id, drawable, texture) {
    const endpoint = type === 'component' ? 'updateComponent' : 'updateProp';
    const payload = type === 'component'
        ? { component: id, drawable: drawable, texture: texture }
        : { prop: id, drawable: drawable, texture: texture };

    setCurrentSkinValue(type, id, drawable, texture);

    fetch(`https://${RESOURCE_NAME}/${endpoint}`, {
        method: 'POST',
        body: JSON.stringify(payload)
    })
        .then(resp => resp.json())
        .then(data => {
            if (data.success) {
                if (data.maxTexture !== undefined) {
                    const maxTexture = Number(data.maxTexture) || 0;
                    const textureSlider = document.querySelector(`.texture-slider[data-id="${id}"][data-type="${type}"]`);
                    let nextTexture = texture;

                    if (textureSlider) {
                        textureSlider.max = maxTexture;
                        if (parseInt(textureSlider.value) > maxTexture) {
                            nextTexture = 0;
                            textureSlider.value = 0;
                            document.getElementById(`${type}-${id}-texture-value`).textContent = '00';
                        }
                    }

                    setCurrentSkinValue(type, id, drawable, nextTexture, maxTexture);
                }
            }
        });
}

// Change gender
function changeGender(gender) {
    fetch(`https://${RESOURCE_NAME}/changeGender`, {
        method: 'POST',
        body: JSON.stringify({ gender: gender })
    })
        .then(resp => resp.json())
        .then(data => {
            if (data.success && data.clothing) {
                clothingData = data.clothing;
                initializeSkinData();
                renderControls();
            }
        });
}

// Close UI
function closeUI() {
    fetch(`https://${RESOURCE_NAME}/close`, {
        method: 'POST',
        body: JSON.stringify({})
    });
}

// Confirm selection
function confirmSelection() {
    fetch(`https://${RESOURCE_NAME}/confirm`, {
        method: 'POST',
        body: JSON.stringify({ skin: currentSkin })
    });
}
