(function () {
    'use strict';

    const ICONS = {
        check:   '<svg viewBox="0 0 24 24"><path d="M9 16.2 4.8 12l-1.4 1.4L9 19 21 7l-1.4-1.4z"/></svg>',
        error:   '<svg viewBox="0 0 24 24"><path d="M12 2 1 21h22L12 2zm1 15h-2v-2h2v2zm0-4h-2V9h2v4z"/></svg>',
        warning: '<svg viewBox="0 0 24 24"><path d="M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z"/></svg>',
        info:    '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" fill="none" stroke="currentColor" stroke-width="2"/><rect x="11" y="10" width="2" height="7" rx="1"/><circle cx="12" cy="7.5" r="1.2"/></svg>',
        money:   '<svg viewBox="0 0 24 24"><path d="M11.8 10.9c-2.3-.6-3-1.2-3-2.1 0-1 1-1.8 2.5-1.8 1.6 0 2.2.8 2.3 1.9h2c-.1-1.6-1.1-3-3-3.4V3h-2.7v2.5c-1.8.4-3.2 1.5-3.2 3.4 0 2.2 1.8 3.3 4.5 3.9 2.4.6 2.9 1.4 2.9 2.3 0 .7-.5 1.7-2.5 1.7-1.9 0-2.6-.8-2.7-1.9h-2c.1 2 1.6 3.2 3.4 3.5V21h2.7v-2.5c1.8-.3 3.3-1.4 3.3-3.4 0-2.6-2.3-3.5-4.5-4.2z"/></svg>',
        zone:    '<svg viewBox="0 0 24 24"><path d="M12 2C8 2 5 5 5 9c0 5 7 13 7 13s7-8 7-13c0-4-3-7-7-7zm0 9a2 2 0 110-4 2 2 0 010 4z"/></svg>',
        item:    '<svg viewBox="0 0 24 24"><path d="M20 6h-4V4l-2-2h-4L8 4v2H4c-1.1 0-2 .9-2 2v11c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-10-2h4v2h-4V4zm10 15H4V8h16v11z"/></svg>',
        combat:  '<svg viewBox="0 0 24 24"><path d="M6.9 2.9l-4 4 3 3L3 15.8 8.2 21l6-6 3 3 4-4L6.9 2.9zm-.7 5.4L8 6.5 12.8 11.3l-1.8 1.8L6.2 8.3z"/></svg>'
    };

    const DEFAULT_TYPES = {
        success: { color: '#22c55e', glyph: 'check',   label: 'SUCCESS' },
        error:   { color: '#ef4444', glyph: 'error',   label: 'ERROR'   },
        warning: { color: '#f59e0b', glyph: 'warning', label: 'WARNING' },
        info:    { color: '#3b82f6', glyph: 'info',    label: 'INFO'    },
        money:   { color: '#10b981', glyph: 'money',   label: 'MONEY'   },
        zone:    { color: '#8b5cf6', glyph: 'zone',    label: 'ZONE'    },
        item:    { color: '#06b6d4', glyph: 'item',    label: 'ITEM'    },
        combat:  { color: '#dc2626', glyph: 'combat',  label: 'COMBAT'  }
    };

    const state = {
        container: null,
        active: new Map(),
        queue: [],
        config: {
            maxVisible: 5,
            animationDuration: 250,
            types: DEFAULT_TYPES
        }
    };

    function init() {
        state.container = document.getElementById('notify-stack');
    }

    function getType(name) {
        return state.config.types[name] || state.config.types.info || DEFAULT_TYPES.info;
    }

    function createElement(data) {
        const typeDef = getType(data.type);
        const glyphName = data.icon || typeDef.glyph || 'info';
        const iconSvg = ICONS[glyphName] || ICONS.info;
        const title = data.title || typeDef.label;
        const duration = Math.max(500, Number(data.duration) || 5000);

        const el = document.createElement('div');
        el.className = 'notify';
        el.dataset.id = data.id;
        el.style.setProperty('--accent-color', typeDef.color);

        el.innerHTML = [
            '<div class="notify-accent"></div>',
            '<div class="notify-icon">', iconSvg, '</div>',
            '<div class="notify-body">',
                '<div class="notify-title">', escapeHtml(title), '</div>',
                '<div class="notify-message">', escapeHtml(data.message), '</div>',
            '</div>',
            '<button class="notify-close" type="button" aria-label="Dismiss">×</button>',
            '<div class="notify-progress" style="animation-duration:', duration, 'ms"></div>'
        ].join('');

        el.querySelector('.notify-close').addEventListener('click', function () {
            dismiss(data.id);
        });

        return { el: el, duration: duration };
    }

    function escapeHtml(text) {
        if (text == null) return '';
        return String(text)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    function show(data) {
        if (!data || !data.id) return;
        if (!state.container) init();
        if (!state.container) return;

        if (state.active.size >= state.config.maxVisible) {
            const oldest = state.active.keys().next().value;
            if (oldest) dismiss(oldest);
        }

        const built = createElement(data);
        state.container.appendChild(built.el);

        const timerId = setTimeout(function () {
            dismiss(data.id);
        }, built.duration);

        state.active.set(data.id, { el: built.el, timerId: timerId });

        requestAnimationFrame(function () {
            requestAnimationFrame(function () {
                built.el.classList.add('visible');
            });
        });
    }

    function dismiss(id) {
        const entry = state.active.get(id);
        if (!entry) return;

        clearTimeout(entry.timerId);
        entry.el.classList.remove('visible');
        entry.el.classList.add('leaving');
        state.active.delete(id);

        setTimeout(function () {
            if (entry.el && entry.el.parentNode) {
                entry.el.parentNode.removeChild(entry.el);
            }
        }, state.config.animationDuration + 50);
    }

    function clearAll() {
        const ids = Array.from(state.active.keys());
        ids.forEach(dismiss);
    }

    function applyConfig(config) {
        if (!config) return;
        if (typeof config.maxVisible === 'number') state.config.maxVisible = config.maxVisible;
        if (typeof config.animationDuration === 'number') state.config.animationDuration = config.animationDuration;
        if (config.types) state.config.types = Object.assign({}, DEFAULT_TYPES, config.types);
    }

    window.addEventListener('message', function (event) {
        const data = event.data;
        if (!data || !data.action) return;

        switch (data.action) {
            case 'show':
                show(data.notify);
                break;
            case 'dismiss':
                dismiss(data.id);
                break;
            case 'clear':
                clearAll();
                break;
            case 'config':
                applyConfig(data.config);
                break;
        }
    });

    document.addEventListener('DOMContentLoaded', init);
    setTimeout(init, 50);
})();
