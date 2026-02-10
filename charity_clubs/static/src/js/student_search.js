/** @odoo-module **/

import publicWidget from "@web/legacy/js/public/public_widget";

publicWidget.registry.StudentSearchWidget = publicWidget.Widget.extend({
    selector: '#searchStudentForm',
    events: {
        'click #searchBtn': '_onSearchClick',
        'input #search_id_number': '_onIdInput',
        'keypress #search_id_number': '_onKeyPress',
    },

    start() {
        console.log('✅ Student Search Widget Started');
        this.clubId = this.el.dataset.clubId;
        this.isArabic = this.el.dataset.lang === 'ar';
        console.log('Club ID:', this.clubId, 'Language:', this.isArabic ? 'Arabic' : 'English');
        return this._super.apply(this, arguments);
    },

    _onIdInput(ev) {
        let value = ev.target.value.replace(/[^\d]/g, '');
        let formatted = '';

        if (value.length <= 3) {
            formatted = value;
        } else if (value.length <= 7) {
            formatted = value.slice(0, 3) + '-' + value.slice(3);
        } else if (value.length <= 14) {
            formatted = value.slice(0, 3) + '-' + value.slice(3, 7) + '-' + value.slice(7);
        } else {
            formatted = value.slice(0, 3) + '-' + value.slice(3, 7) + '-' + value.slice(7, 14) + '-' + value.slice(14, 15);
        }

        ev.target.value = formatted;
        ev.target.classList.remove('is-invalid');

        var idError = document.getElementById('id_error');
        if (idError) idError.textContent = '';
    },

    _onKeyPress(ev) {
        if (ev.which === 13) {
            ev.preventDefault();
            this._onSearchClick(ev);
        }
    },

    _validateEmiratesId(idNumber) {
        if (!idNumber) return false;
        var cleanId = idNumber.replace(/-/g, '').replace(/\s/g, '');
        if (cleanId.length !== 15) return false;
        if (!cleanId.startsWith('784')) return false;
        if (!/^\d+$/.test(cleanId)) return false;
        return true;
    },

    _onSearchClick(ev) {
        ev.preventDefault();
        console.log('🔍 Search clicked');

        var idInput = document.getElementById('search_id_number');
        var idNumber = idInput.value.trim();
        var idError = document.getElementById('id_error');
        var searchBtn = document.getElementById('searchBtn');
        var searchResult = document.getElementById('searchResult');
        var notFoundMessage = document.getElementById('notFoundMessage');

        console.log('ID Number:', idNumber);

        // التحقق
        if (!idNumber) {
            idInput.classList.add('is-invalid');
            if (idError) idError.textContent = 'يجب إدخال رقم الهوية';
            return;
        }

        if (!this._validateEmiratesId(idNumber)) {
            idInput.classList.add('is-invalid');
            if (idError) idError.textContent = 'رقم الهوية غير صحيح (784-YYYY-XXXXXXX-X)';
            return;
        }

        // إظهار التحميل
        searchBtn.disabled = true;
        searchBtn.innerHTML = '<span class="spinner-border spinner-border-sm"></span> جاري البحث...';
        if (searchResult) searchResult.style.display = 'none';
        if (notFoundMessage) notFoundMessage.style.display = 'none';

        // إرسال الطلب
        var self = this;

        fetch('/registration/club/search-student', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                jsonrpc: "2.0",
                method: "call",
                params: {
                    id_number: idNumber,
                    club_id: parseInt(this.clubId)
                },
                id: Date.now()
            })
        })
        .then(function(response) {
            return response.json();
        })
        .then(function(data) {
            console.log('📥 Response:', data);

            searchBtn.disabled = false;
            searchBtn.innerHTML = '<i class="fa fa-search"></i> بحث';

            if (data.error) {
                console.error('Server Error:', data.error);
                idInput.classList.add('is-invalid');
                if (idError) idError.textContent = data.error.data ? data.error.data.message : 'حدث خطأ';
                return;
            }

            var result = data.result;
            console.log('Result:', result);

            if (!result || !result.success) {
                idInput.classList.add('is-invalid');
                if (idError) idError.textContent = result ? result.error : 'حدث خطأ';
                return;
            }

            if (result.found) {
                console.log('✅ Student Found - Showing data');
                self._showStudentFound(result, searchResult);
            } else {
                console.log('❌ Student Not Found');
                self._showNotFound(result.redirect_url, notFoundMessage);
            }
        })
        .catch(function(error) {
            console.error('❌ Fetch Error:', error);
            searchBtn.disabled = false;
            searchBtn.innerHTML = '<i class="fa fa-search"></i> بحث';
            idInput.classList.add('is-invalid');
            if (idError) idError.textContent = 'حدث خطأ في الاتصال';
        });
    },

    _showStudentFound(data, container) {
        console.log('Building HTML for student:', data.student);

        var student = data.student;
        var family = data.family || {};
        var isArabic = this.isArabic;

        // الترجمات
        var t = {
            studentFound: isArabic ? 'تم العثور على الطالب ✨' : 'Student Found ✨',
            studentData: isArabic ? 'بيانات الطالب' : 'Student Data',
            parentData: isArabic ? 'بيانات ولي الأمر' : 'Parent Data',
            name: isArabic ? 'الاسم' : 'Name',
            idNumber: isArabic ? 'رقم الهوية' : 'ID Number',
            birthDate: isArabic ? 'تاريخ الميلاد' : 'Birth Date',
            age: isArabic ? 'العمر' : 'Age',
            years: isArabic ? 'سنة' : 'years',
            gender: isArabic ? 'الجنس' : 'Gender',
            fatherName: isArabic ? 'اسم الأب' : 'Father Name',
            fatherPhone: isArabic ? 'هاتف الأب' : 'Father Phone',
            motherName: isArabic ? 'اسم الأم' : 'Mother Name',
            motherPhone: isArabic ? 'هاتف الأم' : 'Mother Phone',
            continueReg: isArabic ? 'متابعة التسجيل (اختيار الترم فقط)' : 'Continue Registration (Select Term Only)'
        };

        var warningHtml = '';
        if (data.duplicate_warning) {
            warningHtml = `
                <div class="duplicate-warning">
                    <div class="warning-icon">
                        <i class="fa fa-exclamation-triangle"></i>
                    </div>
                    <div class="warning-text">${data.duplicate_warning}</div>
                </div>`;
        }

        var dir = isArabic ? 'rtl' : 'ltr';

        var html = `
            <style>
                .student-result-card {
                    background: white;
                    border-radius: 20px;
                    overflow: hidden;
                    box-shadow: 0 10px 40px rgba(0,0,0,0.1);
                    animation: slideUp 0.5s ease-out;
                }

                @keyframes slideUp {
                    from {
                        opacity: 0;
                        transform: translateY(20px);
                    }
                    to {
                        opacity: 1;
                        transform: translateY(0);
                    }
                }

                .result-header {
                    background: linear-gradient(135deg, #10b981 0%, #059669 100%);
                    color: white;
                    padding: 20px 25px;
                    display: flex;
                    align-items: center;
                    gap: 15px;
                }

                .result-header-icon {
                    width: 50px;
                    height: 50px;
                    background: rgba(255,255,255,0.2);
                    border-radius: 50%;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    font-size: 24px;
                }

                .result-header h3 {
                    margin: 0;
                    font-size: 20px;
                    font-weight: 600;
                }

                .result-body {
                    padding: 25px;
                }

                .info-cards-grid {
                    display: grid;
                    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
                    gap: 25px;
                    margin-bottom: 25px;
                }

                .info-card {
                    background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%);
                    border-radius: 16px;
                    overflow: hidden;
                    border: 1px solid #e2e8f0;
                }

                .info-card-header {
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    padding: 15px 20px;
                    display: flex;
                    align-items: center;
                    gap: 10px;
                }

                .info-card-header.parent-header {
                    background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
                }

                .info-card-header i {
                    font-size: 18px;
                }

                .info-card-header h4 {
                    margin: 0;
                    font-size: 16px;
                    font-weight: 600;
                }

                .info-card-body {
                    padding: 5px;
                }

                .info-item-row {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    padding: 12px 15px;
                    margin: 5px;
                    background: white;
                    border-radius: 10px;
                    transition: all 0.3s ease;
                    border: 1px solid transparent;
                }

                .info-item-row:hover {
                    border-color: #667eea;
                    box-shadow: 0 2px 8px rgba(102, 126, 234, 0.15);
                    transform: translateX(-3px);
                }

                .info-item-label {
                    color: #64748b;
                    font-size: 13px;
                    display: flex;
                    align-items: center;
                    gap: 8px;
                }

                .info-item-label i {
                    color: #667eea;
                    width: 16px;
                }

                .info-item-value {
                    color: #1e293b;
                    font-weight: 600;
                    font-size: 14px;
                }

                .info-item-value.id-number {
                    font-family: 'Courier New', monospace;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    padding: 4px 10px;
                    border-radius: 6px;
                    font-size: 13px;
                }

                .duplicate-warning {
                    background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%);
                    border-right: 4px solid #f59e0b;
                    border-radius: 12px;
                    padding: 15px 20px;
                    display: flex;
                    align-items: center;
                    gap: 15px;
                    margin-bottom: 20px;
                }

                .warning-icon {
                    width: 40px;
                    height: 40px;
                    background: #f59e0b;
                    color: white;
                    border-radius: 50%;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    font-size: 18px;
                    flex-shrink: 0;
                }

                .warning-text {
                    color: #92400e;
                    font-size: 14px;
                    font-weight: 500;
                }

                .continue-btn-container {
                    text-align: center;
                    padding-top: 10px;
                }

                .continue-btn {
                    display: inline-flex;
                    align-items: center;
                    gap: 12px;
                    padding: 16px 40px;
                    background: linear-gradient(135deg, #10b981 0%, #059669 100%);
                    color: white;
                    border: none;
                    border-radius: 14px;
                    font-size: 16px;
                    font-weight: 600;
                    text-decoration: none;
                    transition: all 0.3s ease;
                    box-shadow: 0 4px 15px rgba(16, 185, 129, 0.3);
                }

                .continue-btn:hover {
                    transform: translateY(-3px);
                    box-shadow: 0 8px 25px rgba(16, 185, 129, 0.4);
                    color: white;
                }

                .continue-btn i {
                    font-size: 18px;
                }

                @media (max-width: 576px) {
                    .info-cards-grid {
                        grid-template-columns: 1fr;
                    }

                    .info-item-row {
                        flex-direction: column;
                        align-items: flex-start;
                        gap: 5px;
                    }

                    .continue-btn {
                        width: 100%;
                        justify-content: center;
                    }
                }
            </style>

            <div class="student-result-card" dir="${dir}">
                <div class="result-header">
                    <div class="result-header-icon">
                        <i class="fa fa-check"></i>
                    </div>
                    <h3>${t.studentFound}</h3>
                </div>

                <div class="result-body">
                    <div class="info-cards-grid">
                        <!-- بطاقة بيانات الطالب -->
                        <div class="info-card">
                            <div class="info-card-header">
                                <i class="fa fa-user-circle"></i>
                                <h4>${t.studentData}</h4>
                            </div>
                            <div class="info-card-body">
                                <div class="info-item-row">
                                    <span class="info-item-label">
                                        <i class="fa fa-user"></i>
                                        ${t.name}
                                    </span>
                                    <span class="info-item-value">${student.full_name}</span>
                                </div>
                                <div class="info-item-row">
                                    <span class="info-item-label">
                                        <i class="fa fa-id-card"></i>
                                        ${t.idNumber}
                                    </span>
                                    <span class="info-item-value id-number">${student.id_number}</span>
                                </div>
                                <div class="info-item-row">
                                    <span class="info-item-label">
                                        <i class="fa fa-calendar"></i>
                                        ${t.birthDate}
                                    </span>
                                    <span class="info-item-value">${student.birth_date}</span>
                                </div>
                                <div class="info-item-row">
                                    <span class="info-item-label">
                                        <i class="fa fa-hourglass-half"></i>
                                        ${t.age}
                                    </span>
                                    <span class="info-item-value">${student.age} ${t.years}</span>
                                </div>
                                <div class="info-item-row">
                                    <span class="info-item-label">
                                        <i class="fa fa-venus-mars"></i>
                                        ${t.gender}
                                    </span>
                                    <span class="info-item-value">${student.gender_display}</span>
                                </div>
                            </div>
                        </div>

                        <!-- بطاقة بيانات ولي الأمر -->
                        <div class="info-card">
                            <div class="info-card-header parent-header">
                                <i class="fa fa-users"></i>
                                <h4>${t.parentData}</h4>
                            </div>
                            <div class="info-card-body">
                                <div class="info-item-row">
                                    <span class="info-item-label">
                                        <i class="fa fa-male"></i>
                                        ${t.fatherName}
                                    </span>
                                    <span class="info-item-value">${family.father_name || '-'}</span>
                                </div>
                                <div class="info-item-row">
                                    <span class="info-item-label">
                                        <i class="fa fa-phone"></i>
                                        ${t.fatherPhone}
                                    </span>
                                    <span class="info-item-value" dir="ltr">${family.father_mobile || '-'}</span>
                                </div>
                                <div class="info-item-row">
                                    <span class="info-item-label">
                                        <i class="fa fa-female"></i>
                                        ${t.motherName}
                                    </span>
                                    <span class="info-item-value">${family.mother_name || '-'}</span>
                                </div>
                                <div class="info-item-row">
                                    <span class="info-item-label">
                                        <i class="fa fa-phone"></i>
                                        ${t.motherPhone}
                                    </span>
                                    <span class="info-item-value" dir="ltr">${family.mother_mobile || '-'}</span>
                                </div>
                            </div>
                        </div>
                    </div>

                    ${warningHtml}

                    <div class="continue-btn-container">
                        <a href="${data.redirect_url}" class="continue-btn">
                            ${t.continueReg}
                            <i class="fa fa-arrow-${isArabic ? 'left' : 'right'}"></i>
                        </a>
                    </div>
                </div>
            </div>`;

        console.log('Setting HTML to container');

        if (container) {
            container.innerHTML = html;
            container.style.display = 'block';
            console.log('✅ HTML displayed successfully');
        } else {
            console.error('❌ Container not found!');
        }
    },

    _showNotFound(redirectUrl, container) {
        var isArabic = this.isArabic;
        var t = {
            newStudent: isArabic ? 'طالب جديد 🌟' : 'New Student 🌟',
            notFoundMsg: isArabic ? 'لم يتم العثور على بيانات مسجلة لرقم الهوية هذا' : 'No registered data found for this ID number',
            registerNew: isArabic ? 'تسجيل طالب جديد' : 'Register New Student'
        };
        var dir = isArabic ? 'rtl' : 'ltr';

        var html = `
            <style>
                .new-student-card {
                    background: white;
                    border-radius: 20px;
                    overflow: hidden;
                    box-shadow: 0 10px 40px rgba(0,0,0,0.1);
                    animation: slideUp 0.5s ease-out;
                    text-align: center;
                }

                .new-student-header {
                    background: linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%);
                    color: white;
                    padding: 40px 25px;
                }

                .new-student-icon {
                    width: 80px;
                    height: 80px;
                    background: rgba(255,255,255,0.2);
                    border-radius: 50%;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    margin: 0 auto 20px;
                    font-size: 35px;
                }

                .new-student-header h3 {
                    margin: 0;
                    font-size: 24px;
                    font-weight: 600;
                }

                .new-student-body {
                    padding: 35px 25px;
                }

                .new-student-message {
                    background: linear-gradient(135deg, #eff6ff 0%, #dbeafe 100%);
                    border-radius: 12px;
                    padding: 20px;
                    margin-bottom: 25px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    gap: 12px;
                }

                .new-student-message i {
                    font-size: 24px;
                    color: #3b82f6;
                }

                .new-student-message p {
                    margin: 0;
                    color: #1e40af;
                    font-size: 15px;
                }

                .register-new-btn {
                    display: inline-flex;
                    align-items: center;
                    gap: 12px;
                    padding: 16px 45px;
                    background: linear-gradient(135deg, #10b981 0%, #059669 100%);
                    color: white;
                    border: none;
                    border-radius: 14px;
                    font-size: 17px;
                    font-weight: 600;
                    text-decoration: none;
                    transition: all 0.3s ease;
                    box-shadow: 0 4px 15px rgba(16, 185, 129, 0.3);
                }

                .register-new-btn:hover {
                    transform: translateY(-3px);
                    box-shadow: 0 8px 25px rgba(16, 185, 129, 0.4);
                    color: white;
                }

                .register-new-btn i {
                    font-size: 20px;
                }
            </style>

            <div class="new-student-card" dir="${dir}">
                <div class="new-student-header">
                    <div class="new-student-icon">
                        <i class="fa fa-user-plus"></i>
                    </div>
                    <h3>${t.newStudent}</h3>
                </div>

                <div class="new-student-body">
                    <div class="new-student-message">
                        <i class="fa fa-info-circle"></i>
                        <p>${t.notFoundMsg}</p>
                    </div>

                    <a href="${redirectUrl}" class="register-new-btn">
                        <i class="fa fa-plus-circle"></i>
                        ${t.registerNew}
                    </a>
                </div>
            </div>`;

        if (container) {
            container.innerHTML = html;
            container.style.display = 'block';
        }
    },
});

export default publicWidget.registry.StudentSearchWidget;