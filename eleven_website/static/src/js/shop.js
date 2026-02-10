/**
 * Eleven Website Shop Functionality
 * All features: View Toggle, Search (Server-side), Sort, Filters, Wishlist
 */

(function() {
    'use strict';

    console.log('Eleven Shop JS Loading...');

    // Wait for DOM to be ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initShop);
    } else {
        initShop();
    }

    function initShop() {
        console.log('=== Eleven Shop Initialized ===');

        // Get elements
        const viewBtns = document.querySelectorAll('.eleven_view_btn');
        const productsGrid = document.getElementById('eleven_products_grid');
        const searchInput = document.getElementById('eleven_search_input');
        const searchBtn = document.querySelector('.eleven_search_btn');
        const sortSelect = document.getElementById('eleven_sort_select');
        const filterCheckboxes = document.querySelectorAll('.filter-checkbox');
        const wishlistBtns = document.querySelectorAll('.eleven_wishlist_btn');
        const productCards = document.querySelectorAll('.eleven_product_card');

        console.log('Found elements:');
        console.log('- View buttons:', viewBtns.length);
        console.log('- Product cards:', productCards.length);
        console.log('- Filter checkboxes:', filterCheckboxes.length);

        // ===================================
        // VIEW TOGGLE (Grid/List)
        // ===================================
        if (viewBtns.length > 0 && productsGrid) {
            viewBtns.forEach(function(btn) {
                btn.addEventListener('click', function(e) {
                    e.preventDefault();
                    const view = this.getAttribute('data-view');
                    console.log('View Toggle:', view);

                    // Remove active from all buttons
                    viewBtns.forEach(function(b) {
                        b.classList.remove('active');
                    });

                    // Add active to clicked button
                    this.classList.add('active');

                    // Toggle grid class
                    if (view === 'list') {
                        productsGrid.classList.add('eleven_products_list');
                        console.log('✓ Switched to LIST view');
                    } else {
                        productsGrid.classList.remove('eleven_products_list');
                        console.log('✓ Switched to GRID view');
                    }
                });
            });
            console.log('✓ View toggle initialized');
        } else {
            console.warn('⚠ View toggle not found');
        }

        // ===================================
        // SEARCH FUNCTIONALITY - SERVER SIDE
        // ===================================
        function performSearch() {
            const searchTerm = searchInput.value.trim();

            // Get current URL parameters
            const urlParams = new URLSearchParams(window.location.search);

            if (searchTerm) {
                // Set search parameter
                urlParams.set('search', searchTerm);
                // Reset to page 1 when searching
                urlParams.delete('page');
            } else {
                // Remove search parameter if empty
                urlParams.delete('search');
            }

            // Keep category if exists
            // urlParams already has category if it was in the URL

            // Redirect to server with search parameter
            const queryString = urlParams.toString();
            const newUrl = '/products' + (queryString ? '?' + queryString : '');
            window.location.href = newUrl;
        }

        if (searchBtn) {
            searchBtn.addEventListener('click', function(e) {
                e.preventDefault();
                performSearch();
            });
            console.log('✓ Search button initialized (Server-side)');
        }

        if (searchInput) {
            // Search on Enter key
            searchInput.addEventListener('keyup', function(e) {
                if (e.key === 'Enter') {
                    performSearch();
                }
            });

            // Also add a clear button functionality
            searchInput.addEventListener('keyup', function(e) {
                if (e.key === 'Escape') {
                    this.value = '';
                    // Optionally redirect to clear search
                    // performSearch();
                }
            });

            console.log('✓ Search input initialized (Server-side)');
        }

        // ===================================
        // SORT FUNCTIONALITY - SERVER SIDE
        // ===================================
        if (sortSelect && productsGrid) {
            sortSelect.addEventListener('change', function() {
                const sortValue = this.value;
                console.log('Sort by:', sortValue);

                // Get current URL parameters
                const urlParams = new URLSearchParams(window.location.search);

                if (sortValue && sortValue !== 'featured') {
                    urlParams.set('sort', sortValue);
                } else {
                    urlParams.delete('sort');
                }

                // Reset to page 1 when sorting
                urlParams.delete('page');

                // Redirect with sort parameter
                const queryString = urlParams.toString();
                const newUrl = '/products' + (queryString ? '?' + queryString : '');
                window.location.href = newUrl;
            });

            // Set the current sort value from URL
            const urlParams = new URLSearchParams(window.location.search);
            const currentSort = urlParams.get('sort');
            if (currentSort) {
                sortSelect.value = currentSort;
            }

            console.log('✓ Sort initialized (Server-side)');
        }

        // ===================================
        // FILTER FUNCTIONALITY (Client-side for now)
        // ===================================
        function applyFilters() {
            const activeFilters = {
                color: [],
                size: [],
                price: [],
                category: []
            };

            // Collect active filters
            filterCheckboxes.forEach(function(checkbox) {
                if (checkbox.checked) {
                    const filterType = checkbox.getAttribute('data-filter-type');
                    const value = checkbox.value;

                    if (filterType && value) {
                        if (!activeFilters[filterType]) {
                            activeFilters[filterType] = [];
                        }
                        activeFilters[filterType].push(value.toLowerCase());
                    }
                }
            });

            console.log('Active filters:', activeFilters);

            // Check if any filter is active
            const hasActiveFilters = Object.values(activeFilters).some(function(arr) {
                return arr.length > 0;
            });

            if (!hasActiveFilters) {
                // Show all products if no filter is active
                productCards.forEach(function(card) {
                    card.style.display = '';
                });
                console.log('✓ No filters active, showing all products');
                showNoResults(false);
                return;
            }

            // Filter products
            let visibleCount = 0;
            productCards.forEach(function(card) {
                let show = true;

                // Category filter (from data-category attribute)
                if (activeFilters.category && activeFilters.category.length > 0) {
                    const cardCategories = card.getAttribute('data-category');
                    if (cardCategories) {
                        const categoryMatch = activeFilters.category.some(function(cat) {
                            return cardCategories.includes(cat);
                        });
                        if (!categoryMatch) show = false;
                    } else {
                        show = false;
                    }
                }

                // Color filter (from product name)
                if (activeFilters.color && activeFilters.color.length > 0) {
                    const productName = card.querySelector('.eleven_product_name a');
                    if (productName) {
                        const name = productName.textContent.toLowerCase();
                        const colorMatch = activeFilters.color.some(function(color) {
                            return name.includes(color);
                        });
                        if (!colorMatch) show = false;
                    } else {
                        show = false;
                    }
                }

                // Size filter (from product name)
                if (activeFilters.size && activeFilters.size.length > 0) {
                    const productName = card.querySelector('.eleven_product_name a');
                    if (productName) {
                        const name = productName.textContent.toLowerCase();
                        const sizeMatch = activeFilters.size.some(function(size) {
                            return name.includes(size.toLowerCase());
                        });
                        if (!sizeMatch) show = false;
                    } else {
                        show = false;
                    }
                }

                // Price filter
                if (activeFilters.price && activeFilters.price.length > 0) {
                    const price = parseFloat(card.getAttribute('data-price')) || 0;
                    let priceMatch = false;

                    activeFilters.price.forEach(function(range) {
                        if (range === '0-500' && price < 500) priceMatch = true;
                        if (range === '500-1000' && price >= 500 && price < 1000) priceMatch = true;
                        if (range === '1000-2000' && price >= 1000 && price < 2000) priceMatch = true;
                        if (range === '2000+' && price >= 2000) priceMatch = true;
                    });

                    if (!priceMatch) show = false;
                }

                // Show/hide card
                if (show) {
                    card.style.display = '';
                    visibleCount++;
                } else {
                    card.style.display = 'none';
                }
            });

            console.log('✓ Visible after filter:', visibleCount);
            showNoResults(visibleCount === 0);
        }

        if (filterCheckboxes.length > 0) {
            filterCheckboxes.forEach(function(checkbox) {
                checkbox.addEventListener('change', function() {
                    console.log('Filter changed:', this.getAttribute('data-filter-type'), this.value, this.checked);
                    applyFilters();
                });
            });
            console.log('✓ Filters initialized');
        } else {
            console.warn('⚠ No filter checkboxes found');
        }

        // ===================================
        // NO RESULTS MESSAGE
        // ===================================
        function showNoResults(show) {
            let noResultsMsg = document.getElementById('eleven_no_results');

            if (show) {
                if (!noResultsMsg) {
                    noResultsMsg = document.createElement('div');
                    noResultsMsg.id = 'eleven_no_results';
                    noResultsMsg.className = 'eleven_no_results';
                    noResultsMsg.innerHTML = '<p><i class="fa fa-search"></i> No products found matching your filters.</p>';
                    productsGrid.appendChild(noResultsMsg);
                }
                noResultsMsg.style.display = 'block';
            } else {
                if (noResultsMsg) {
                    noResultsMsg.style.display = 'none';
                }
            }
        }

        // ===================================
        // WISHLIST FUNCTIONALITY
        // ===================================
        if (wishlistBtns.length > 0) {
            wishlistBtns.forEach(function(btn) {
                btn.addEventListener('click', function(e) {
                    e.preventDefault();
                    const icon = this.querySelector('i');
                    const productId = this.getAttribute('data-product-id');

                    if (icon) {
                        if (icon.classList.contains('fa-heart-o')) {
                            icon.classList.remove('fa-heart-o');
                            icon.classList.add('fa-heart');
                            console.log('✓ Added to wishlist:', productId);
                        } else {
                            icon.classList.remove('fa-heart');
                            icon.classList.add('fa-heart-o');
                            console.log('✓ Removed from wishlist:', productId);
                        }
                    }
                });
            });
            console.log('✓ Wishlist initialized');
        } else {
            console.warn('⚠ No wishlist buttons found');
        }

        // ===================================
        // CLEAR FILTERS BUTTON
        // ===================================
        function addClearFiltersButton() {
            const sidebar = document.querySelector('.eleven_shop_sidebar');
            if (sidebar && !document.getElementById('eleven_clear_filters')) {
                const clearBtn = document.createElement('button');
                clearBtn.id = 'eleven_clear_filters';
                clearBtn.className = 'eleven_btn_clear_filters';
                clearBtn.innerHTML = '<i class="fa fa-times"></i> Clear All Filters';
                clearBtn.style.cssText = 'width: 100%; padding: 10px; background: #e74c3c; color: white; border: none; border-radius: 5px; cursor: pointer; margin-top: 20px; font-weight: bold;';

                clearBtn.addEventListener('click', function() {
                    // Clear checkboxes
                    filterCheckboxes.forEach(function(checkbox) {
                        checkbox.checked = false;
                    });
                    applyFilters();

                    // Also clear URL search if exists
                    const urlParams = new URLSearchParams(window.location.search);
                    if (urlParams.has('search') || urlParams.has('sort')) {
                        window.location.href = '/products';
                    }

                    console.log('✓ All filters cleared');
                });

                sidebar.appendChild(clearBtn);
                console.log('✓ Clear filters button added');
            }
        }

        addClearFiltersButton();

        // ===================================
        // CLEAR SEARCH BUTTON (if search is active)
        // ===================================
        function addClearSearchButton() {
            const urlParams = new URLSearchParams(window.location.search);
            const searchTerm = urlParams.get('search');

            if (searchTerm && searchInput) {
                // Add a clear button next to search
                const searchBox = searchInput.parentElement;

                // Create clear button
                const clearSearchBtn = document.createElement('button');
                clearSearchBtn.type = 'button';
                clearSearchBtn.className = 'eleven_clear_search_btn';
                clearSearchBtn.innerHTML = '<i class="fa fa-times"></i>';
                clearSearchBtn.style.cssText = 'position: absolute; right: 50px; top: 50%; transform: translateY(-50%); background: none; border: none; color: #999; cursor: pointer; padding: 5px;';
                clearSearchBtn.title = 'Clear search';

                clearSearchBtn.addEventListener('click', function() {
                    searchInput.value = '';
                    urlParams.delete('search');
                    const queryString = urlParams.toString();
                    window.location.href = '/products' + (queryString ? '?' + queryString : '');
                });

                // Make search box position relative
                searchBox.style.position = 'relative';
                searchBox.insertBefore(clearSearchBtn, searchBtn);

                console.log('✓ Clear search button added');
            }
        }

        addClearSearchButton();

        // ===================================
        // SHOW SEARCH RESULTS MESSAGE
        // ===================================
        function showSearchResultsMessage() {
            const urlParams = new URLSearchParams(window.location.search);
            const searchTerm = urlParams.get('search');

            if (searchTerm && productsGrid) {
                const resultsCount = productCards.length;

                // Create message element
                const searchMessage = document.createElement('div');
                searchMessage.className = 'eleven_search_results_message';
                searchMessage.style.cssText = 'grid-column: 1 / -1; padding: 15px 20px; background: #f8f8f8; border-radius: 8px; margin-bottom: 20px; display: flex; justify-content: space-between; align-items: center;';

                searchMessage.innerHTML = `
                    <span>
                        <i class="fa fa-search" style="color: #e74c3c; margin-right: 10px;"></i>
                        Found <strong>${resultsCount}</strong> result(s) for "<strong>${searchTerm}</strong>"
                    </span>
                    <a href="/products" style="color: #e74c3c; text-decoration: none; font-weight: 600;">
                        <i class="fa fa-times"></i> Clear Search
                    </a>
                `;

                // Insert at the beginning of the grid
                productsGrid.insertBefore(searchMessage, productsGrid.firstChild);

                console.log('✓ Search results message added');
            }
        }

        showSearchResultsMessage();

        // ===================================
        // INITIALIZATION COMPLETE
        // ===================================
        console.log('=== All features initialized successfully! ===');
        console.log('Total products:', productCards.length);
    }

})();