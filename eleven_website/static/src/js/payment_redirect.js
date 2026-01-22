/** @odoo-module **/

/**
 * Payment Status Redirect
 * Automatically redirects to custom confirmation page after successful payment
 */

(function() {
    'use strict';

    // Only run on payment status page
    if (window.location.pathname === '/payment/status') {

        function checkAndRedirect() {
            // Check for success message
            var successAlert = document.querySelector('.alert-success');
            var skipButton = document.querySelector('a[href*="Skip"], a.btn:contains("Skip")');

            if (successAlert || document.body.textContent.includes('successfully processed')) {
                // Payment successful - redirect to our confirmation page
                window.location.href = '/eleven/checkout/confirmation';
                return true;
            }
            return false;
        }

        // Check immediately
        if (!checkAndRedirect()) {
            // Check after delays
            setTimeout(checkAndRedirect, 500);
            setTimeout(checkAndRedirect, 1000);
            setTimeout(checkAndRedirect, 2000);
            setTimeout(checkAndRedirect, 3000);
        }

        // Also observe DOM changes
        var observer = new MutationObserver(function(mutations) {
            checkAndRedirect();
        });

        observer.observe(document.body, {
            childList: true,
            subtree: true,
            characterData: true
        });

        // Auto redirect after 5 seconds anyway
        setTimeout(function() {
            window.location.href = '/eleven/checkout/confirmation';
        }, 5000);
    }
})();