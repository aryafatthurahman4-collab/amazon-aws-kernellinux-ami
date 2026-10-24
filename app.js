/* ═══════════════════════════════════════════════════════════
   Amazon Linux Reference Hub — Interactive JavaScript
   ═══════════════════════════════════════════════════════════ */

document.addEventListener('DOMContentLoaded', () => {
    initThemeToggle();
    initNavbar();
    initMobileMenu();
    initIaCTabs();
    initCopyButtons();
    initScrollAnimations();
    initCountUpAnimation();
    initActiveNavHighlight();
});

/* ─── Theme Toggle ──────────────────────────────────────── */
function initThemeToggle() {
    const toggle = document.getElementById('themeToggle');
    const stored = localStorage.getItem('al-hub-theme');

    if (stored) {
        document.documentElement.setAttribute('data-theme', stored);
    }

    toggle.addEventListener('click', () => {
        const current = document.documentElement.getAttribute('data-theme');
        const next = current === 'light' ? 'dark' : 'light';
        document.documentElement.setAttribute('data-theme', next);
        localStorage.setItem('al-hub-theme', next);
    });
}

/* ─── Navbar Scroll Effect ──────────────────────────────── */
function initNavbar() {
    const navbar = document.getElementById('navbar');
    let ticking = false;

    window.addEventListener('scroll', () => {
        if (!ticking) {
            requestAnimationFrame(() => {
                navbar.classList.toggle('scrolled', window.scrollY > 20);
                ticking = false;
            });
            ticking = true;
        }
    });
}

/* ─── Mobile Menu ───────────────────────────────────────── */
function initMobileMenu() {
    const btn = document.getElementById('mobileMenuBtn');
    const links = document.getElementById('navLinks');

    btn.addEventListener('click', () => {
        links.classList.toggle('open');
        btn.classList.toggle('active');
    });

    // Close menu when clicking a link
    links.querySelectorAll('.nav-link').forEach(link => {
        link.addEventListener('click', () => {
            links.classList.remove('open');
            btn.classList.remove('active');
        });
    });
}

/* ─── IaC Tab Switching ─────────────────────────────────── */
function initIaCTabs() {
    const tabs = document.querySelectorAll('.iac-tab');
    const panels = document.querySelectorAll('.iac-panel');

    tabs.forEach(tab => {
        tab.addEventListener('click', () => {
            const target = tab.dataset.tab;

            tabs.forEach(t => t.classList.remove('active'));
            panels.forEach(p => p.classList.remove('active'));

            tab.classList.add('active');
            document.getElementById(`tab-${target}`).classList.add('active');
        });
    });
}

/* ─── Copy to Clipboard ─────────────────────────────────── */
function initCopyButtons() {
    document.querySelectorAll('.copy-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            // Find the nearest code block's text content
            const codeBlock = btn.closest('.code-block');
            const codeEl = codeBlock.querySelector('code');
            const text = codeEl.textContent
                .replace(/^\$\s*/gm, '')  // Remove prompt characters
                .replace(/^#.*$/gm, '')   // Remove comment-only lines
                .split('\n')
                .filter(line => line.trim() !== '')
                .join('\n');

            navigator.clipboard.writeText(text).then(() => {
                const original = btn.textContent;
                btn.textContent = '✓ Copied!';
                btn.classList.add('copied');
                setTimeout(() => {
                    btn.textContent = original;
                    btn.classList.remove('copied');
                }, 2000);
            }).catch(() => {
                btn.textContent = 'Failed';
                setTimeout(() => { btn.textContent = 'Copy'; }, 2000);
            });
        });
    });
}

/* ─── Scroll Animations ─────────────────────────────────── */
function initScrollAnimations() {
    // Add animation class to sections
    const animatable = document.querySelectorAll(
        '.version-card, .kernel-card, .script-card, .cheat-card, ' +
        '.comparison-table-wrapper, .warning-card, .network-card'
    );

    animatable.forEach(el => el.classList.add('animate-on-scroll'));

    const observer = new IntersectionObserver((entries) => {
        entries.forEach((entry, index) => {
            if (entry.isIntersecting) {
                // Stagger the animation
                setTimeout(() => {
                    entry.target.classList.add('visible');
                }, index * 80);
                observer.unobserve(entry.target);
            }
        });
    }, {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
    });

    animatable.forEach(el => observer.observe(el));
}

/* ─── Count-Up Animation ────────────────────────────────── */
function initCountUpAnimation() {
    const numbers = document.querySelectorAll('.stat-number[data-target]');

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const el = entry.target;
                const target = parseInt(el.dataset.target);
                animateCount(el, 0, target, 1500);
                observer.unobserve(el);
            }
        });
    }, { threshold: 0.5 });

    numbers.forEach(num => observer.observe(num));
}

function animateCount(el, start, end, duration) {
    const startTime = performance.now();

    function update(currentTime) {
        const elapsed = currentTime - startTime;
        const progress = Math.min(elapsed / duration, 1);

        // Ease-out cubic
        const eased = 1 - Math.pow(1 - progress, 3);
        const current = Math.round(start + (end - start) * eased);

        el.textContent = current;

        if (progress < 1) {
            requestAnimationFrame(update);
        }
    }

    requestAnimationFrame(update);
}

/* ─── Active Nav Highlight on Scroll ────────────────────── */
function initActiveNavHighlight() {
    const sections = document.querySelectorAll('section[id], header[id]');
    const navLinks = document.querySelectorAll('.nav-link');
    let ticking = false;

    window.addEventListener('scroll', () => {
        if (!ticking) {
            requestAnimationFrame(() => {
                let current = '';
                const scrollY = window.scrollY + 100;

                sections.forEach(section => {
                    const top = section.offsetTop;
                    const height = section.offsetHeight;

                    if (scrollY >= top && scrollY < top + height) {
                        current = section.getAttribute('id');
                    }
                });

                navLinks.forEach(link => {
                    link.classList.remove('active');
                    if (link.getAttribute('href') === `#${current}`) {
                        link.classList.add('active');
                    }
                });

                ticking = false;
            });
            ticking = true;
        }
    });
}
