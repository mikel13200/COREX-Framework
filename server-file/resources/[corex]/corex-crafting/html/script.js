let craftingState = {
    recipes: [],
    queue: [],
    maxQueue: 3,
    selectedRecipeId: null,
    activeCategory: 'all',
    playerInventory: {},
    workbenchTier: 1
};

let queueTimerInterval = null;

const container = document.getElementById('crafting-container');
const detailsContent = document.getElementById('details-content');
const emptyState = document.getElementById('empty-state');
const craftBtn = document.getElementById('craft-btn');

function GetParentResourceName() {
    if (GetParentResourceName._cached) return GetParentResourceName._cached;
    if (window.location.hostname === '') {
        GetParentResourceName._cached = 'corex-crafting';
    } else {
        GetParentResourceName._cached = window.location.hostname.replace('cfx-nui-', '');
    }
    return GetParentResourceName._cached;
}

function nuiFetch(endpoint, data) {
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        body: JSON.stringify(data || {})
    }).catch(() => {});
}

window.addEventListener('message', (event) => {
    const msg = event.data;
    switch (msg.action) {
        case 'open':
            applyState(msg.data);
            container.classList.remove('hidden');
            startQueueTimers();
            break;
        case 'close':
            closeCrafting();
            break;
        case 'updateState':
            applyState(msg.data);
            break;
        case 'craftComplete':
            handleCraftComplete(msg.recipeId);
            break;
    }
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !container.classList.contains('hidden')) {
        e.preventDefault();
        nuiFetch('close');
    }
});

document.getElementById('close-btn').addEventListener('click', () => {
    nuiFetch('close');
});

craftBtn.addEventListener('click', () => {
    console.log('[CRAFT] Button clicked. disabled:', craftBtn.classList.contains('disabled'), 'selectedId:', craftingState.selectedRecipeId);
    if (craftBtn.classList.contains('disabled') || !craftingState.selectedRecipeId) return;
    console.log('[CRAFT] Sending startCraft for:', craftingState.selectedRecipeId);
    nuiFetch('startCraft', { recipeId: craftingState.selectedRecipeId });
});

document.getElementById('recipe-search').addEventListener('input', () => {
    renderRecipeList(craftingState.activeCategory);
});

function closeCrafting() {
    container.classList.add('hidden');
    craftingState.selectedRecipeId = null;
    document.getElementById('recipe-search').value = '';
    stopQueueTimers();
}

function applyState(data) {
    if (!data) return;

    if (data.recipes !== undefined) craftingState.recipes = data.recipes;
    if (data.queue !== undefined) craftingState.queue = data.queue;
    if (data.maxQueue !== undefined) craftingState.maxQueue = data.maxQueue;
    if (data.playerInventory !== undefined) craftingState.playerInventory = data.playerInventory;
    if (data.workbenchTier !== undefined) craftingState.workbenchTier = data.workbenchTier;

    document.getElementById('workbench-tier').textContent = `TIER ${craftingState.workbenchTier}`;
    document.getElementById('queue-count').textContent = craftingState.queue.length;
    document.getElementById('queue-max').textContent = craftingState.maxQueue;

    renderCategoryTabs();
    renderRecipeList(craftingState.activeCategory, true);
    renderQueue();

    if (craftingState.selectedRecipeId) {
        const exists = craftingState.recipes.find(r => r.id === craftingState.selectedRecipeId);
        if (exists) renderRecipeDetails(craftingState.selectedRecipeId);
        else clearDetails();
    }
}

function getCategories() {
    const cats = new Set();
    craftingState.recipes.forEach(r => {
        if (r.category) cats.add(r.category);
    });
    return Array.from(cats).sort();
}

function renderCategoryTabs() {
    const tabsContainer = document.getElementById('category-tabs');
    const categories = getCategories();
    tabsContainer.innerHTML = '';

    const allTab = document.createElement('button');
    allTab.className = 'nav-tab' + (craftingState.activeCategory === 'all' ? ' active' : '');
    allTab.textContent = 'ALL';
    allTab.addEventListener('click', () => {
        craftingState.activeCategory = 'all';
        renderCategoryTabs();
        renderRecipeList('all');
    });
    tabsContainer.appendChild(allTab);

    categories.forEach(cat => {
        const tab = document.createElement('button');
        tab.className = 'nav-tab' + (craftingState.activeCategory === cat ? ' active' : '');
        tab.textContent = cat.toUpperCase();
        tab.addEventListener('click', () => {
            craftingState.activeCategory = cat;
            renderCategoryTabs();
            renderRecipeList(cat);
        });
        tabsContainer.appendChild(tab);
    });
}

function canCraftRecipe(recipe) {
    if (recipe.locked) return false;
    return recipe.materials.every(mat => (mat.owned || 0) >= (mat.required || mat.count || 0));
}

function renderRecipeList(category, preserveScroll = false) {
    const list = document.getElementById('recipe-list');
    const oldScroll = list.scrollTop;
    list.innerHTML = '';

    let filtered = craftingState.recipes;
    if (category && category !== 'all') {
        filtered = filtered.filter(r => r.category === category);
    }

    const query = document.getElementById('recipe-search').value.trim().toLowerCase();
    if (query) {
        filtered = filtered.filter(r =>
            r.resultName.toLowerCase().includes(query) ||
            (r.category && r.category.toLowerCase().includes(query))
        );
    }

    filtered.sort((a, b) => {
        const aCan = canCraftRecipe(a) ? 0 : 1;
        const bCan = canCraftRecipe(b) ? 0 : 1;
        if (aCan !== bCan) return aCan - bCan;
        if (a.locked && !b.locked) return 1;
        if (!a.locked && b.locked) return -1;
        return (a.resultName || '').localeCompare(b.resultName || '');
    });

    if (filtered.length === 0) {
        list.innerHTML = '<div class="recipe-list-empty"><i class="fa-solid fa-box-open"></i><span>No recipes found</span></div>';
        return;
    }

    const listFrag = document.createDocumentFragment();
    const animateEntry = !preserveScroll;
    // Cap the stagger so huge lists don't spawn dozens of simultaneous animations.
    const MAX_STAGGER = 16;
    filtered.forEach((recipe, index) => {
        const craftable = canCraftRecipe(recipe);
        const card = document.createElement('div');
        let classes = animateEntry && index < MAX_STAGGER ? 'recipe-card fade-in-up' : 'recipe-card';
        if (craftingState.selectedRecipeId === recipe.id) classes += ' selected';
        if (recipe.locked) classes += ' locked';
        else if (craftable) classes += ' craftable';
        else classes += ' not-craftable';

        card.className = classes;
        if (animateEntry && index < MAX_STAGGER) {
            card.style.animationDelay = `${index * 0.035}s`;
        }

        let statusText = recipe.locked ? 'Locked' : (craftable ? 'Ready' : 'Short');
        const materials = Array.isArray(recipe.materials) ? recipe.materials : [];
        const materialDots = materials.slice(0, 6).map(mat => {
            const owned = mat.owned || 0;
            const req = mat.required || mat.count || 0;
            const hasEnough = owned >= req;
            return `<span class="mat-dot${hasEnough ? ' has' : ''}"></span>`;
        }).join('');

        card.innerHTML = `
            <div class="card-main-content">
                <div class="card-icon-wrapper">
                    <img src="${recipe.resultImage || 'images/default.png'}" alt="${recipe.resultName}" onerror="this.src='images/default.png'">
                </div>
                <div class="card-info">
                    <div class="card-name">${recipe.resultName}</div>
                    <div class="card-desc">${recipe.description || 'Essential survival material for crafting and use.'}</div>
                </div>
                <div class="card-status-badge${craftable && !recipe.locked ? ' craftable' : ''}">${statusText}</div>
            </div>
            <div class="card-mats">
                ${materialDots}
            </div>
        `;

        if (!recipe.locked) {
            card.addEventListener('click', () => {
                if (craftingState.selectedRecipeId === recipe.id) return;

                craftingState.selectedRecipeId = recipe.id;

                // Swap the selected class manually without re-rendering the whole DOM
                const oldSelected = document.querySelector('.recipe-card.selected');
                if (oldSelected) {
                    oldSelected.classList.remove('selected');
                }
                card.classList.add('selected');

                renderRecipeDetails(recipe.id);
            });
        }
        listFrag.appendChild(card);
    });
    list.appendChild(listFrag);

    if (preserveScroll) {
        requestAnimationFrame(() => {
            list.scrollTop = oldScroll;
        });
    }
}

function renderRecipeDetails(recipeId) {
    const recipe = craftingState.recipes.find(r => r.id === recipeId);
    if (!recipe) {
        clearDetails();
        return;
    }

    emptyState.classList.add('hidden');
    detailsContent.classList.remove('hidden');

    const img = document.getElementById('result-image');
    img.src = recipe.resultImage || 'images/default.png';
    img.onerror = function() { this.src = 'images/default.png'; };

    document.getElementById('result-name').textContent = recipe.resultName;
    document.getElementById('result-desc').textContent = recipe.description || 'No description available.';
    document.getElementById('result-category').textContent = (recipe.category || 'misc').toUpperCase();
    document.getElementById('result-rarity').textContent = (recipe.rarity || 'common').toUpperCase();

    const grid = document.getElementById('materials-grid');
    grid.innerHTML = '';

    let haveCount = 0;
    const totalMats = recipe.materials.length;
    const matFrag = document.createDocumentFragment();

    recipe.materials.forEach(mat => {
        const owned = mat.owned || 0;
        const req = mat.required || mat.count || 0;
        const enough = owned >= req;
        const pct = req > 0 ? Math.min(100, (owned / req) * 100) : 0;

        if (enough) haveCount++;

        const card = document.createElement('div');
        card.className = 'mat-item ' + (enough ? 'has-enough' : 'not-enough');
        card.innerHTML = `
            <div class="mat-img">
                <img src="${mat.image || 'images/default.png'}" alt="${mat.label || mat.name}" onerror="this.src='images/default.png'">
            </div>
            <div class="mat-info">
                <div class="mat-name">${mat.label || mat.name}</div>
                <div class="mat-prog">
                    <div class="mat-prog-bg">
                        <div class="mat-prog-fill" style="width: ${pct}%"></div>
                    </div>
                    <div class="mat-count">${owned} / ${req}</div>
                </div>
            </div>
        `;
        matFrag.appendChild(card);
    });
    grid.appendChild(matFrag);

    const queueFull = craftingState.queue.length >= craftingState.maxQueue;
    const canCraft = canCraftRecipe(recipe) && !queueFull;

    if (canCraft) {
        craftBtn.classList.remove('disabled');
    } else {
        craftBtn.classList.add('disabled');
    }

    document.getElementById('duration-text').textContent = formatDuration(recipe.duration);
}

function clearDetails() {
    emptyState.classList.remove('hidden');
    detailsContent.classList.add('hidden');
    craftingState.selectedRecipeId = null;
}

function renderQueue() {
    const qList = document.getElementById('queue-items');
    qList.innerHTML = '';
    document.getElementById('queue-count').textContent = craftingState.queue.length;

    if (craftingState.queue.length === 0) {
        qList.innerHTML = '<div class="queue-empty">Queue is empty</div>';
        return;
    }

    const qFrag = document.createDocumentFragment();
    craftingState.queue.forEach((item, index) => {
        const card = document.createElement('div');
        card.className = 'queue-item' + (item.completed ? ' completed' : '');

        if (item.completed) {
            card.innerHTML = `
                <div class="queue-item-header">
                    <span class="q-name">${item.resultName}</span>
                    <div class="q-controls">
                        <span class="q-time">Done</span>
                        <button class="q-take" data-index="${index}">Collect</button>
                    </div>
                </div>
                <div class="q-bar-bg">
                    <div class="q-bar-fill" style="width: 100%"></div>
                </div>
            `;
            card.querySelector('.q-take').addEventListener('click', () => {
                nuiFetch('takeCraft', { queueIndex: index + 1 });
            });
        } else {
            const rem = Math.max(0, item.duration - item.elapsed);
            const pct = Math.min(100, (item.elapsed / item.duration) * 100);

            card.innerHTML = `
                <div class="queue-item-header">
                    <span class="q-name">${item.resultName}</span>
                    <div class="q-controls">
                        <span class="q-time q-rem" data-index="${index}">${formatDuration(rem)}</span>
                        <button class="q-cancel" data-index="${index}" title="Cancel">
                            <i class="fa-solid fa-xmark"></i>
                        </button>
                    </div>
                </div>
                <div class="q-bar-bg">
                    <div class="q-bar-fill q-prog" data-index="${index}" style="width: ${pct}%"></div>
                </div>
            `;
            card.querySelector('.q-cancel').addEventListener('click', () => {
                nuiFetch('cancelCraft', { queueIndex: index + 1 });
            });
        }
        qFrag.appendChild(card);
    });
    qList.appendChild(qFrag);
}

const QUEUE_TICK_MS = 250;

function startQueueTimers() {
    stopQueueTimers();
    queueTimerInterval = setInterval(() => {
        // Skip entirely when the UI is hidden — Lua still authoritative on completion
        if (container.classList.contains('hidden')) return;
        if (!craftingState.queue || craftingState.queue.length === 0) return;

        let rerender = false;
        const qList = document.getElementById('queue-items');
        craftingState.queue.forEach((item, index) => {
            if (item.completed) return;
            item.elapsed += QUEUE_TICK_MS;
            if (item.elapsed >= item.duration) {
                item.elapsed = item.duration;
                item.completed = true;
                rerender = true;
            } else {
                const rem = Math.max(0, item.duration - item.elapsed);
                const pct = Math.min(100, (item.elapsed / item.duration) * 100);
                // Scoped query from qList — cheaper than whole-document querySelector
                const bar = qList && qList.querySelector(`.q-prog[data-index="${index}"]`);
                const timeEl = qList && qList.querySelector(`.q-rem[data-index="${index}"]`);
                if (bar) bar.style.width = pct.toFixed(1) + '%';
                if (timeEl) timeEl.textContent = formatDuration(rem);
            }
        });
        if (rerender) {
            renderQueue();
            if (craftingState.selectedRecipeId) renderRecipeDetails(craftingState.selectedRecipeId);
        }
    }, QUEUE_TICK_MS);
}

function stopQueueTimers() {
    if (queueTimerInterval) {
        clearInterval(queueTimerInterval);
        queueTimerInterval = null;
    }
}

function handleCraftComplete(recipeId) {
    const item = craftingState.queue.find(q => q.recipeId === recipeId && !q.completed);
    if (item) {
        item.completed = true;
        item.elapsed = item.duration;
        renderQueue();
    }
}

function formatDuration(ms) {
    if (ms <= 0) return '0s';
    const totalSeconds = Math.ceil(ms / 1000);
    const m = Math.floor(totalSeconds / 60);
    const s = totalSeconds % 60;
    if (m > 0) return s > 0 ? `${m}m ${s}s` : `${m}m`;
    return `${s}s`;
}
