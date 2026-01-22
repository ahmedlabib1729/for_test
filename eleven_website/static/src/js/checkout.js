/**
 * Eleven Checkout JavaScript
 * Handles address selection, form validation, and submission
 */

document.addEventListener('DOMContentLoaded', function() {
    'use strict';

    const checkoutForm = document.getElementById('checkout_form');
    const newAddressForm = document.getElementById('new_address_form');
    const addressRadios = document.querySelectorAll('input[name="address_id"]');
    const addressCards = document.querySelectorAll('.eleven_address_card');

    // =============================================
    // ADDRESS SELECTION HANDLING
    // =============================================

    function updateAddressSelection() {
        const selectedValue = document.querySelector('input[name="address_id"]:checked')?.value;

        // Update card styling
        addressCards.forEach(function(card) {
            const radio = card.querySelector('input[type="radio"]');
            if (radio && radio.checked) {
                card.classList.add('selected');
            } else {
                card.classList.remove('selected');
            }
        });

        // Show/hide new address form
        if (newAddressForm) {
            if (selectedValue === 'new') {
                newAddressForm.style.display = 'block';
            } else {
                newAddressForm.style.display = 'none';
            }
        }
    }

    // Listen for address selection changes
    addressRadios.forEach(function(radio) {
        radio.addEventListener('change', updateAddressSelection);
    });

    // Also handle click on the card itself
    addressCards.forEach(function(card) {
        card.addEventListener('click', function(e) {
            // Don't trigger if clicking on edit link
            if (e.target.closest('a')) return;

            const radio = card.querySelector('input[type="radio"]');
            if (radio) {
                radio.checked = true;
                radio.dispatchEvent(new Event('change', { bubbles: true }));
            }
        });
    });

    // Initialize on page load
    updateAddressSelection();

    // =============================================
    // FORM SUBMISSION
    // =============================================

    if (checkoutForm) {
        checkoutForm.addEventListener('submit', function(e) {
            const selectedAddress = document.querySelector('input[name="address_id"]:checked');

            // Check if user has selected an address
            if (!selectedAddress) {
                e.preventDefault();
                alert('Please select a shipping address');
                return false;
            }

            const selectedValue = selectedAddress.value;

            // If existing address selected (not 'new'), just submit
            if (selectedValue && selectedValue !== 'new') {
                console.log('Submitting with existing address:', selectedValue);
                return true; // Allow form submission
            }

            // If new address, validate required fields
            if (selectedValue === 'new') {
                const firstName = document.querySelector('input[name="first_name"]');
                const lastName = document.querySelector('input[name="last_name"]');
                const street = document.querySelector('input[name="street"]');
                const city = document.querySelector('input[name="city"]');
                const countryId = document.querySelector('select[name="country_id"]');

                let isValid = true;
                let errorMessage = '';

                if (!firstName?.value?.trim()) {
                    isValid = false;
                    errorMessage = 'Please enter your first name';
                } else if (!lastName?.value?.trim()) {
                    isValid = false;
                    errorMessage = 'Please enter your last name';
                } else if (!street?.value?.trim()) {
                    isValid = false;
                    errorMessage = 'Please enter your street address';
                } else if (!city?.value?.trim()) {
                    isValid = false;
                    errorMessage = 'Please enter your city';
                } else if (!countryId?.value) {
                    isValid = false;
                    errorMessage = 'Please select a country';
                }

                if (!isValid) {
                    e.preventDefault();
                    alert(errorMessage);
                    return false;
                }
            }

            console.log('Form validation passed, submitting...');
            return true;
        });
    }

    // =============================================
    // COUNTRY/STATE DYNAMIC LOADING
    // =============================================

    const countrySelect = document.getElementById('country_id');
    const stateSelect = document.getElementById('state_id');

    if (countrySelect && stateSelect) {
        countrySelect.addEventListener('change', function() {
            const countryId = this.value;

            if (!countryId) {
                stateSelect.innerHTML = '<option value="">Select State</option>';
                return;
            }

            fetch('/eleven/checkout/get-states', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    jsonrpc: '2.0',
                    method: 'call',
                    params: { country_id: countryId },
                    id: Date.now()
                })
            })
            .then(response => response.json())
            .then(data => {
                const states = data.result || [];
                stateSelect.innerHTML = '<option value="">Select State</option>';
                states.forEach(function(state) {
                    const option = document.createElement('option');
                    option.value = state.id;
                    option.textContent = state.name;
                    stateSelect.appendChild(option);
                });
            })
            .catch(error => {
                console.error('Error fetching states:', error);
            });
        });
    }

    console.log('Eleven Checkout JS loaded successfully');
});