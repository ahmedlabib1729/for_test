/**
 * Eleven Product Detail Page Functionality
 */

(function() {
    'use strict';

    console.log('Product Detail JS Loading...');

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initProductDetail);
    } else {
        initProductDetail();
    }

    function initProductDetail() {
        console.log('=== Product Detail Initialized ===');

        // Elements
        const quantityInput = document.getElementById('product_quantity');
        const addQtyInput = document.getElementById('add_qty_input');
        const buyQtyInput = document.getElementById('buy_qty_input');
        const starRatingInputs = document.querySelectorAll('.eleven_star_rating input');

        // ===================================
        // QUANTITY SYNC
        // ===================================
        if (quantityInput && addQtyInput && buyQtyInput) {
            quantityInput.addEventListener('change', function() {
                const qty = parseInt(this.value) || 1;
                addQtyInput.value = qty;
                buyQtyInput.value = qty;
                console.log('Quantity updated:', qty);
            });
            console.log('✓ Quantity sync initialized');
        }

        // ===================================
        // STAR RATING INTERACTION
        // ===================================
        if (starRatingInputs.length > 0) {
            starRatingInputs.forEach(function(input) {
                input.addEventListener('change', function() {
                    console.log('Rating selected:', this.value);
                });
            });
            console.log('✓ Star rating initialized');
        }

        // ===================================
        // SMOOTH SCROLL TO REVIEWS
        // ===================================
        const reviewsSection = document.querySelector('.eleven_reviews_section');

        // Add "See Reviews" button functionality if exists
        const seeReviewsBtn = document.getElementById('see_reviews_btn');
        if (seeReviewsBtn && reviewsSection) {
            seeReviewsBtn.addEventListener('click', function(e) {
                e.preventDefault();
                reviewsSection.scrollIntoView({ behavior: 'smooth', block: 'start' });
            });
        }

        // ===================================
        // IMAGE GALLERY (if multiple images)
        // ===================================
        const thumbnails = document.querySelectorAll('.eleven_thumbnail');
        const mainImage = document.querySelector('.eleven_product_main_img');

        if (thumbnails.length > 0 && mainImage) {
            thumbnails.forEach(function(thumb) {
                thumb.addEventListener('click', function() {
                    const newSrc = this.getAttribute('data-image-src');
                    if (newSrc) {
                        mainImage.src = newSrc;

                        // Remove active class from all thumbnails
                        thumbnails.forEach(function(t) {
                            t.classList.remove('active');
                        });

                        // Add active class to clicked thumbnail
                        this.classList.add('active');

                        console.log('Image changed');
                    }
                });
            });
            console.log('✓ Image gallery initialized');
        }

        // ===================================
        // REVIEW FORM VALIDATION
        // ===================================
        const reviewForm = document.querySelector('.eleven_review_form');

        if (reviewForm) {
            reviewForm.addEventListener('submit', function(e) {
                const ratingSelected = Array.from(starRatingInputs).some(function(input) {
                    return input.checked;
                });

                if (!ratingSelected) {
                    e.preventDefault();
                    alert('Please select a rating before submitting your review.');
                    return false;
                }

                const comment = reviewForm.querySelector('[name="comment"]').value.trim();
                if (comment.length < 10) {
                    e.preventDefault();
                    alert('Please write a review with at least 10 characters.');
                    return false;
                }

                console.log('Review form submitted');
            });
            console.log('✓ Review form validation initialized');
        }

        // ===================================
        // BUY NOW CONFIRMATION
        // ===================================
        const buyNowForm = document.querySelector('.eleven_buy_now_form');

        if (buyNowForm) {
            buyNowForm.addEventListener('submit', function(e) {
                const qty = parseInt(quantityInput ? quantityInput.value : 1);
                const confirmed = confirm(`Add ${qty} item(s) to cart and proceed to checkout?`);

                if (!confirmed) {
                    e.preventDefault();
                    return false;
                }

                console.log('Buy Now clicked');
            });
            console.log('✓ Buy Now confirmation initialized');
        }

        // ===================================
        // HELPFUL REVIEW BUTTON
        // ===================================
        const helpfulBtns = document.querySelectorAll('.eleven_helpful_btn');

        helpfulBtns.forEach(function(btn) {
            btn.addEventListener('click', function(e) {
                e.preventDefault();
                const reviewId = this.getAttribute('data-review-id');

                // You can add AJAX call here to mark as helpful
                this.classList.add('clicked');
                this.disabled = true;

                const count = this.querySelector('.helpful-count');
                if (count) {
                    count.textContent = parseInt(count.textContent) + 1;
                }

                console.log('Review marked as helpful:', reviewId);
            });
        });

        if (helpfulBtns.length > 0) {
            console.log('✓ Helpful buttons initialized');
        }

        // ===================================
        // AUTO-HIDE SUCCESS/ERROR MESSAGES
        // ===================================
        const alerts = document.querySelectorAll('.alert');

        alerts.forEach(function(alert) {
            setTimeout(function() {
                alert.style.transition = 'opacity 0.5s';
                alert.style.opacity = '0';
                setTimeout(function() {
                    alert.remove();
                }, 500);
            }, 5000);
        });

        if (alerts.length > 0) {
            console.log('✓ Alert auto-hide initialized');
        }

        // ===================================
        // SHARE PRODUCT (Optional)
        // ===================================
        const shareBtn = document.getElementById('share_product_btn');

        if (shareBtn) {
            shareBtn.addEventListener('click', function(e) {
                e.preventDefault();

                if (navigator.share) {
                    navigator.share({
                        title: document.querySelector('.eleven_product_detail_name').textContent,
                        text: 'Check out this product!',
                        url: window.location.href
                    }).then(function() {
                        console.log('Product shared successfully');
                    }).catch(function(error) {
                        console.error('Error sharing:', error);
                    });
                } else {
                    // Fallback: Copy link to clipboard
                    const tempInput = document.createElement('input');
                    tempInput.value = window.location.href;
                    document.body.appendChild(tempInput);
                    tempInput.select();
                    document.execCommand('copy');
                    document.body.removeChild(tempInput);

                    alert('Link copied to clipboard!');
                }
            });
            console.log('✓ Share button initialized');
        }

        console.log('=== Product Detail Features Loaded Successfully! ===');
    }

})();