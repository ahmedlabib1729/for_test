/**
 * Eleven Website - Product Links Fix
 * JavaScript-only solution - No XML needed
 */

(function() {
    'use strict';

    console.log('🔧 Eleven Product Links Fix Loading...');

    // Configuration
    const CHECK_INTERVAL = 300; // Check every 300ms
    const OLD_PATH = '/shop/product/';
    const NEW_PATH = '/product/';

    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initialize);
    } else {
        initialize();
    }

    function initialize() {
        console.log('✓ Initializing product links fix...');

        // Fix immediately
        fixAllProductLinks();

        // Setup continuous monitoring
        setupContinuousMonitoring();

        // Setup mutation observer
        setupMutationObserver();

        // Fix on popstate (back/forward navigation)
        window.addEventListener('popstate', fixAllProductLinks);

        // Fix on hashchange
        window.addEventListener('hashchange', fixAllProductLinks);

        console.log('✓ Product links fix ready!');
    }

    /**
     * Main function to fix all product links
     */
    function fixAllProductLinks() {
        // Find all links containing old path
        const links = document.querySelectorAll(`a[href*="${OLD_PATH}"]`);

        if (links.length === 0) return;

        let fixedCount = 0;

        links.forEach(function(link) {
            if (fixLink(link)) {
                fixedCount++;
            }
        });

        if (fixedCount > 0) {
            console.log(`✓ Fixed ${fixedCount} product link(s)`);
        }
    }

    /**
     * Fix a single link
     */
    function fixLink(link) {
        const href = link.getAttribute('href');

        // Skip if already fixed
        if (!href || !href.includes(OLD_PATH)) {
            return false;
        }

        // Get product ID using multiple methods
        const productId = getProductId(link, href);

        if (!productId) {
            console.warn('Could not determine product ID for:', href);
            return false;
        }

        // Update href
        const newHref = NEW_PATH + productId;
        link.setAttribute('href', newHref);

        // Also fix data-href if exists
        if (link.hasAttribute('data-href')) {
            link.setAttribute('data-href', newHref);
        }

        return true;
    }

    /**
     * Get product ID using multiple fallback methods
     */
    function getProductId(link, href) {
        // Method 1: data-product-id on link
        let productId = link.getAttribute('data-product-id');
        if (productId) return productId;

        // Method 2: data-product-id on parent
        const parentWithId = link.closest('[data-product-id]');
        if (parentWithId) {
            productId = parentWithId.getAttribute('data-product-id');
            if (productId) return productId;
        }

        // Method 3: Look for product ID in nearby elements
        const row = link.closest('tr, div, li, article');
        if (row) {
            const productEl = row.querySelector('[data-product-id]');
            if (productEl) {
                productId = productEl.getAttribute('data-product-id');
                if (productId) return productId;
            }
        }

        // Method 4: Extract from image src
        const img = link.querySelector('img') || row?.querySelector('img');
        if (img) {
            const src = img.getAttribute('src') || '';
            const match = src.match(/product\.product[\/\[](\d+)/);
            if (match) return match[1];
        }

        // Method 5: Parse from href - pattern: /shop/product/something-123
        let match = href.match(/\/shop\/product\/[^\/]*?-(\d+)(?:\/|\?|#|$)/);
        if (match) return match[1];

        // Method 6: Parse from href - pattern: /shop/product/123
        match = href.match(/\/shop\/product\/(\d+)(?:\/|\?|#|$)/);
        if (match) return match[1];

        // Method 7: Look for product_id in URL parameters
        match = href.match(/[?&]product_id=(\d+)/);
        if (match) return match[1];

        // Method 8: Search in HTML content
        if (row) {
            const html = row.innerHTML;
            match = html.match(/product[_\-]id["\s:=]+(\d+)/i);
            if (match) return match[1];

            // Look for /web/image/product.product/123
            match = html.match(/\/web\/image\/product\.product\/(\d+)/);
            if (match) return match[1];
        }

        // Method 9: Check form inputs
        if (row) {
            const input = row.querySelector('input[name="product_id"]');
            if (input) {
                productId = input.value;
                if (productId) return productId;
            }
        }

        // Method 10: Extract from slug (last resort)
        match = href.match(/\/shop\/product\/([^\/\?#]+)/);
        if (match) {
            const slug = match[1];
            const idMatch = slug.match(/(\d+)$/);
            if (idMatch) return idMatch[1];
        }

        return null;
    }

    /**
     * Setup continuous monitoring
     */
    function setupContinuousMonitoring() {
        setInterval(fixAllProductLinks, CHECK_INTERVAL);
    }

    /**
     * Setup mutation observer for dynamic content
     */
    function setupMutationObserver() {
        const observer = new MutationObserver(function(mutations) {
            let shouldFix = false;

            mutations.forEach(function(mutation) {
                // Check if any nodes were added
                if (mutation.addedNodes.length > 0) {
                    mutation.addedNodes.forEach(function(node) {
                        if (node.nodeType === 1) { // Element node
                            // Check if it's a link or contains links
                            if (node.tagName === 'A' && node.href && node.href.includes(OLD_PATH)) {
                                shouldFix = true;
                            } else if (node.querySelector) {
                                const links = node.querySelectorAll(`a[href*="${OLD_PATH}"]`);
                                if (links.length > 0) {
                                    shouldFix = true;
                                }
                            }
                        }
                    });
                }

                // Check if href attribute changed
                if (mutation.type === 'attributes' && mutation.attributeName === 'href') {
                    const target = mutation.target;
                    if (target.tagName === 'A' && target.href && target.href.includes(OLD_PATH)) {
                        shouldFix = true;
                    }
                }
            });

            if (shouldFix) {
                // Small delay to ensure DOM is updated
                setTimeout(fixAllProductLinks, 50);
            }
        });

        // Observe the entire document
        observer.observe(document.body, {
            childList: true,
            subtree: true,
            attributes: true,
            attributeFilter: ['href']
        });

        console.log('✓ Mutation observer active');
    }

    // Expose function globally for manual testing
    window.fixElevenProductLinks = fixAllProductLinks;

    console.log('🎉 Eleven Product Links Fix Loaded Successfully!');
})();