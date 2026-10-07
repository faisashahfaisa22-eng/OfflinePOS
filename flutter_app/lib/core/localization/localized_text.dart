import 'package:flutter/material.dart' as m;

import 'app_strings.dart';
import 'language_controller.dart';

/// Translates QAMVIO UI strings without touching business data or database values.
/// Source strings stay in English in the codebase; visible UI is resolved here.
String tr(String value) {
  final language = LanguageController.instance.language;
  if (language == AppLanguage.english || value.isEmpty) return value;

  final exact = _ui[value];
  if (exact != null && language.index < exact.length) {
    return exact[language.index];
  }

  // Translate common dynamic labels and multi-word UI phrases while leaving
  // arbitrary business names/data alone. Exact one-word UI keys become a
  // reusable glossary automatically.
  final dynamicPrefix = RegExp(
    r'^(Date|Stock|Reorder|Balance|Total|Due|Customer|Supplier|Salesman|Invoice|'
    r'Opening|Current|Paid|Received|Amount|Note|From|To|Type|Reference|Cash|'
    r'Phone|Status|Product|Qty|Cost|Price|Discount|Recovery|Expense|Payment|'
    r'Account|Loan|Report|Business|Fuel|Tank|Nozzle|Medicine|Section|Record)(\\b|:)',
    caseSensitive: false,
  );

  final words = <String, String>{};
  for (final entry in (_wordMap[language] ?? const <String, String>{}).entries) {
    words[entry.key.toLowerCase()] = entry.value;
  }
  for (final entry in _ui.entries) {
    if (RegExp(r'^[A-Za-z]+
}

/// Drop-in localized replacement for Flutter's Text widget.
/// Feature pages import Material with "hide Text" and this class instead.
class Text extends m.StatelessWidget {
  final String data;
  final m.TextStyle? style;
  final m.StrutStyle? strutStyle;
  final m.TextAlign? textAlign;
  final m.TextDirection? textDirection;
  final m.Locale? locale;
  final bool? softWrap;
  final m.TextOverflow? overflow;
  final m.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final m.TextWidthBasis? textWidthBasis;
  final m.TextHeightBehavior? textHeightBehavior;
  final m.Color? selectionColor;

  const Text(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  @override
  m.Widget build(m.BuildContext context) => m.Text(
        tr(data),
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel == null ? null : tr(semanticsLabel!),
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
}

const Map<String, List<String>> _ui = {
  // [English, Pashto, Dari, Urdu, Arabic, Hindi, Spanish, French, Turkish]
  'Dashboard': ['Dashboard','ډشبورډ','داشبورد','ڈیش بورڈ','لوحة التحكم','डैशबोर्ड','Panel','Tableau de bord','Kontrol Paneli'],
  'Sales': ['Sales','خرڅلاو','فروشات','فروخت','المبيعات','बिक्री','Ventas','Ventes','Satış'],
  'Sales / Cash Report': ['Sales / Cash Report','خرڅلاو / نغدي راپور','فروشات / گزارش نقدی','فروخت / کیش رپورٹ','تقرير المبيعات / النقد','बिक्री / नकद रिपोर्ट','Ventas / Informe de caja','Ventes / Rapport de caisse','Satış / Nakit Raporu'],
  'Fuel / Oil Pump': ['Fuel / Oil Pump','د تېلو پمپ','پمپ سوخت / روغن','فیول / آئل پمپ','مضخة الوقود / الزيت','ईंधन / तेल पंप','Bomba de combustible / aceite','Pompe carburant / huile','Yakıt / Yağ Pompası'],
  'Pharmacy': ['Pharmacy','درملتون','داروخانه','فارمیسی','الصيدلية','फार्मेसी','Farmacia','Pharmacie','Eczane'],
  'Stock': ['Stock','سټاک','موجودی','اسٹاک','المخزون','स्टॉक','Stock','Stock','Stok'],
  'Stock Ledger': ['Stock Ledger','د سټاک لیجر','دفتر موجودی','اسٹاک لیجر','دفتر المخزون','स्टॉक लेजर','Libro de stock','Grand livre de stock','Stok Defteri'],
  'Products': ['Products','توکي','محصولات','مصنوعات','المنتجات','उत्पाद','Productos','Produits','Ürünler'],
  'Purchases': ['Purchases','پېرودونه','خریدها','خریداری','المشتريات','खरीदारी','Compras','Achats','Satın Almalar'],
  'Customers': ['Customers','پېرودونکي','مشتریان','گاہک','العملاء','ग्राहक','Clientes','Clients','Müşteriler'],
  'Suppliers': ['Suppliers','عرضه کوونکي','تأمین‌کنندگان','سپلائرز','الموردون','आपूर्तिकर्ता','Proveedores','Fournisseurs','Tedarikçiler'],
  'Salesmen': ['Salesmen','خرڅوونکي','فروشندگان','سیلز مین','مندوبو المبيعات','सेल्समैन','Vendedores','Vendeurs','Satış Elemanları'],
  'Expenses': ['Expenses','لګښتونه','مصارف','اخراجات','المصروفات','खर्चे','Gastos','Dépenses','Giderler'],
  'Reports': ['Reports','راپورونه','گزارش‌ها','رپورٹس','التقارير','रिपोर्ट','Informes','Rapports','Raporlar'],
  'Cash Book': ['Cash Book','نغدي کتاب','دفتر نقدی','کیش بک','دفتر النقدية','कैश बुक','Libro de caja','Livre de caisse','Kasa Defteri'],
  'Daily Closing': ['Daily Closing','ورځنی تړل','بستن روزانه','ڈیلی کلوزنگ','الإغلاق اليومي','दैनिक समापन','Cierre diario','Clôture quotidienne','Günlük Kapanış'],
  'Customer Loans': ['Customer Loans','د پېرودونکو پورونه','قرض مشتریان','کسٹمر لونز','ديون العملاء','ग्राहक ऋण','Préstamos de clientes','Prêts clients','Müşteri Borçları'],
  'Salesman Loans': ['Salesman Loans','د خرڅوونکو پورونه','قرض فروشندگان','سیلز مین لونز','ديون مندوبي المبيعات','सेल्समैन ऋण','Préstamos de vendedores','Prêts vendeurs','Satış Elemanı Borçları'],
  'Customer Statement / Ledger': ['Customer Statement / Ledger','د پېرودونکي حساب / لیجر','صورت حساب / دفتر مشتری','کسٹمر اسٹیٹمنٹ / لیجر','كشف حساب العميل','ग्राहक स्टेटमेंट / लेजर','Estado / Libro del cliente','Relevé / Grand livre client','Müşteri Ekstresi / Defter'],
  'Supplier Statement / Ledger': ['Supplier Statement / Ledger','د عرضه کوونکي حساب / لیجر','صورت حساب / دفتر تأمین‌کننده','سپلائر اسٹیٹمنٹ / لیجر','كشف حساب المورد','आपूर्तिकर्ता स्टेटमेंट / लेजर','Estado / Libro del proveedor','Relevé / Grand livre fournisseur','Tedarikçi Ekstresi / Defter'],
  'Salesman Statement / Ledger': ['Salesman Statement / Ledger','د خرڅوونکي حساب / لیجر','صورت حساب / دفتر فروشنده','سیلز مین اسٹیٹمنٹ / لیجر','كشف حساب مندوب المبيعات','सेल्समैन स्टेटमेंट / लेजर','Estado / Libro del vendedor','Relevé / Grand livre vendeur','Satış Elemanı Ekstresi / Defter'],
  'Owner / Partner Money': ['Owner / Partner Money','د مالک / شریک پیسې','پول مالک / شریک','مالک / پارٹنر رقم','أموال المالك / الشريك','मालिक / भागीदार धन','Dinero del propietario / socio','Argent propriétaire / associé','Sahip / Ortak Parası'],
  'Backup / Restore': ['Backup / Restore','بیک اپ / بېرته راګرځول','پشتیبان / بازیابی','بیک اپ / ریسٹور','نسخ احتياطي / استعادة','बैकअप / पुनर्स्थापना','Copia / Restaurar','Sauvegarde / Restaurer','Yedekle / Geri Yükle'],
  'Users / Login': ['Users / Login','کاروونکي / ننوتل','کاربران / ورود','یوزرز / لاگ اِن','المستخدمون / تسجيل الدخول','उपयोगकर्ता / लॉगिन','Usuarios / Inicio de sesión','Utilisateurs / Connexion','Kullanıcılar / Giriş'],
  'Safety Center': ['Safety Center','امنیت مرکز','مرکز امنیت','سیفٹی سینٹر','مركز الأمان','सुरक्षा केंद्र','Centro de seguridad','Centre de sécurité','Güvenlik Merkezi'],
  'Recycle Bin': ['Recycle Bin','کثافت دان','سطل بازیافت','ری سائیکل بن','سلة المحذوفات','रीसायकल बिन','Papelera','Corbeille','Geri Dönüşüm Kutusu'],
  'Delete Entry': ['Delete Entry','ریکارډ ړنګول','حذف رکورد','انٹری حذف کریں','حذف السجل','एंट्री हटाएँ','Eliminar entrada','Supprimer l’entrée','Kaydı Sil'],
  'Quick Search': ['Quick Search','چټک لټون','جستجوی سریع','فوری تلاش','بحث سريع','त्वरित खोज','Búsqueda rápida','Recherche rapide','Hızlı Arama'],
  'Discount Report': ['Discount Report','د تخفیف راپور','گزارش تخفیف','ڈسکاؤنٹ رپورٹ','تقرير الخصومات','छूट रिपोर्ट','Informe de descuentos','Rapport des remises','İndirim Raporu'],
  'Language': ['Language','ژبه','زبان','زبان','اللغة','भाषा','Idioma','Langue','Dil'],
  'Save': ['Save','خوندي کول','ذخیره','محفوظ کریں','حفظ','सहेजें','Guardar','Enregistrer','Kaydet'],
  'Cancel': ['Cancel','لغوه','لغو','منسوخ','إلغاء','रद्द करें','Cancelar','Annuler','İptal'],
  'Delete': ['Delete','ړنګول','حذف','حذف کریں','حذف','हटाएँ','Eliminar','Supprimer','Sil'],
  'Edit': ['Edit','سمون','ویرایش','ترمیم','تعديل','संपादित करें','Editar','Modifier','Düzenle'],
  'Continue': ['Continue','دوام','ادامه','جاری رکھیں','متابعة','जारी रखें','Continuar','Continuer','Devam'],
  'Close': ['Close','تړل','بستن','بند کریں','إغلاق','बंद करें','Cerrar','Fermer','Kapat'],
  'Search': ['Search','لټون','جستجو','تلاش','بحث','खोज','Buscar','Rechercher','Ara'],
  'Print': ['Print','چاپ','چاپ','پرنٹ','طباعة','प्रिंट','Imprimir','Imprimer','Yazdır'],
  'Restore': ['Restore','بېرته راګرځول','بازیابی','ریسٹور','استعادة','पुनर्स्थापित करें','Restaurar','Restaurer','Geri Yükle'],
  'Refresh': ['Refresh','تازه کول','تازه‌سازی','ریفریش','تحديث','रीफ्रेश','Actualizar','Actualiser','Yenile'],
  'WhatsApp': ['WhatsApp','واټس‌اپ','واتساپ','واٹس ایپ','واتساب','व्हाट्सऐप','WhatsApp','WhatsApp','WhatsApp'],
  'Copy': ['Copy','کاپي','کپی','کاپی','نسخ','कॉपी','Copiar','Copier','Kopyala'],
  'Not now': ['Not now','اوس نه','فعلاً نه','ابھی نہیں','ليس الآن','अभी नहीं','Ahora no','Pas maintenant','Şimdi değil'],
  'Back to sign in': ['Back to sign in','بېرته ننوتلو ته','بازگشت به ورود','واپس لاگ اِن','العودة لتسجيل الدخول','लॉगिन पर वापस','Volver al inicio','Retour à la connexion','Girişe Dön'],
  'Sign out': ['Sign out','وتل','خروج','سائن آؤٹ','تسجيل الخروج','साइन आउट','Cerrar sesión','Se déconnecter','Çıkış Yap'],
  'Logout': ['Logout','وتل','خروج','لاگ آؤٹ','تسجيل الخروج','लॉग आउट','Cerrar sesión','Déconnexion','Çıkış'],
  'Add': ['Add','زیاتول','افزودن','شامل کریں','إضافة','जोड़ें','Añadir','Ajouter','Ekle'],
  'Add Line': ['Add Line','کرښه زیاتول','افزودن ردیف','لائن شامل کریں','إضافة سطر','पंक्ति जोड़ें','Añadir línea','Ajouter une ligne','Satır Ekle'],
  'Add Entry': ['Add Entry','ریکارډ زیاتول','افزودن رکورد','انٹری شامل کریں','إضافة سجل','एंट्री जोड़ें','Añadir entrada','Ajouter une entrée','Kayıt Ekle'],
  'Create user': ['Create user','کاروونکی جوړول','ایجاد کاربر','یوزر بنائیں','إنشاء مستخدم','उपयोगकर्ता बनाएँ','Crear usuario','Créer un utilisateur','Kullanıcı Oluştur'],
  'Date': ['Date','نېټه','تاریخ','تاریخ','التاريخ','तारीख','Fecha','Date','Tarih'],
  'Invoice': ['Invoice','انوایس','فاکتور','انوائس','فاتورة','चालान','Factura','Facture','Fatura'],
  'Invoice No': ['Invoice No','د انوایس شمېره','شماره فاکتور','انوائس نمبر','رقم الفاتورة','चालान नंबर','N.º factura','N° facture','Fatura No'],
  'Customer': ['Customer','پېرودونکی','مشتری','گاہک','عميل','ग्राहक','Cliente','Client','Müşteri'],
  'Supplier': ['Supplier','عرضه کوونکی','تأمین‌کننده','سپلائر','مورد','आपूर्तिकर्ता','Proveedor','Fournisseur','Tedarikçi'],
  'Salesman': ['Salesman','خرڅوونکی','فروشنده','سیلز مین','مندوب المبيعات','सेल्समैन','Vendedor','Vendeur','Satış Elemanı'],
  'Product': ['Product','توکی','محصول','مصنوع','المنتج','उत्पाद','Producto','Produit','Ürün'],
  'Qty': ['Qty','مقدار','تعداد','مقدار','الكمية','मात्रा','Cant.','Qté','Miktar'],
  'Cost': ['Cost','لګښت','هزینه','لاگت','التكلفة','लागत','Costo','Coût','Maliyet'],
  'Amount': ['Amount','اندازه','مبلغ','رقم','المبلغ','राशि','Importe','Montant','Tutar'],
  'Total': ['Total','ټول','مجموع','کل','الإجمالي','कुल','Total','Total','Toplam'],
  'Paid': ['Paid','ورکړل شوي','پرداخت‌شده','ادا شدہ','مدفوع','भुगतान','Pagado','Payé','Ödendi'],
  'Received': ['Received','ترلاسه شوي','دریافت‌شده','وصول شدہ','مستلم','प्राप्त','Recibido','Reçu','Alındı'],
  'Due': ['Due','پور','باقی','بقایا','مستحق','बकाया','Pendiente','Dû','Borç'],
  'Recovery': ['Recovery','وصول','دریافت','ریکوری','تحصيل','वसूली','Recuperación','Recouvrement','Tahsilat'],
  'Discount': ['Discount','تخفیف','تخفیف','ڈسکاؤنٹ','خصم','छूट','Descuento','Remise','İndirim'],
  'Note': ['Note','یادښت','یادداشت','نوٹ','ملاحظة','नोट','Nota','Note','Not'],
  'Phone': ['Phone','تلیفون','تلفن','فون','الهاتف','फोन','Teléfono','Téléphone','Telefon'],
  'Address': ['Address','پته','آدرس','پتہ','العنوان','पता','Dirección','Adresse','Adres'],
  'Currency': ['Currency','اسعار','واحد پول','کرنسی','العملة','मुद्रा','Moneda','Devise','Para Birimi'],
  'Business Type': ['Business Type','د کاروبار ډول','نوع کسب‌وکار','کاروبار کی قسم','نوع النشاط','व्यवसाय प्रकार','Tipo de negocio','Type d’entreprise','İşletme Türü'],
  'Role': ['Role','رول','نقش','کردار','الدور','भूमिका','Rol','Rôle','Rol'],
  'Password': ['Password','پاسورډ','رمز عبور','پاس ورڈ','كلمة المرور','पासवर्ड','Contraseña','Mot de passe','Şifre'],
  'Confirm password': ['Confirm password','پاسورډ تایید','تأیید رمز عبور','پاس ورڈ کی تصدیق','تأكيد كلمة المرور','पासवर्ड की पुष्टि','Confirmar contraseña','Confirmer le mot de passe','Şifreyi Doğrula'],
  'Email or mobile': ['Email or mobile','برېښنالیک یا موبایل','ایمیل یا موبایل','ای میل یا موبائل','البريد أو الجوال','ईमेल या मोबाइल','Correo o móvil','E-mail ou mobile','E-posta veya Mobil'],
  'Credit Limit': ['Credit Limit','د پور حد','حد اعتبار','کریڈٹ حد','حد الائتمان','क्रेडिट सीमा','Límite de crédito','Limite de crédit','Kredi Limiti'],
  'Opening Balance': ['Opening Balance','پیل بیلانس','موجودی آغازین','اوپننگ بیلنس','الرصيد الافتتاحي','प्रारंभिक शेष','Saldo inicial','Solde initial','Açılış Bakiyesi'],
  'Current Balance': ['Current Balance','اوسنی بیلانس','موجودی فعلی','موجودہ بیلنس','الرصيد الحالي','वर्तमान शेष','Saldo actual','Solde actuel','Güncel Bakiye'],
  'Current Stock': ['Current Stock','اوسنی سټاک','موجودی فعلی','موجودہ اسٹاک','المخزون الحالي','वर्तमान स्टॉक','Stock actual','Stock actuel','Mevcut Stok'],
  'Opening Qty': ['Opening Qty','پیل مقدار','تعداد آغازین','اوپننگ مقدار','الكمية الافتتاحية','प्रारंभिक मात्रा','Cantidad inicial','Qté initiale','Açılış Miktarı'],
  'Reorder Level': ['Reorder Level','د بیا فرمایش کچه','سطح سفارش مجدد','ری آرڈر لیول','حد إعادة الطلب','पुनः ऑर्डर स्तर','Nivel de reposición','Niveau de réapprovisionnement','Yeniden Sipariş Seviyesi'],
  'Sale Price': ['Sale Price','د خرڅلاو بیه','قیمت فروش','فروخت قیمت','سعر البيع','बिक्री मूल्य','Precio de venta','Prix de vente','Satış Fiyatı'],
  'Cost Price': ['Cost Price','د پېر بیه','قیمت خرید','لاگت قیمت','سعر التكلفة','लागत मूल्य','Precio de costo','Prix de revient','Maliyet Fiyatı'],
  'Stock Value': ['Stock Value','د سټاک ارزښت','ارزش موجودی','اسٹاک ویلیو','قيمة المخزون','स्टॉक मूल्य','Valor del stock','Valeur du stock','Stok Değeri'],
  'Status': ['Status','حالت','وضعیت','حالت','الحالة','स्थिति','Estado','Statut','Durum'],
  'Type': ['Type','ډول','نوع','قسم','النوع','प्रकार','Tipo','Type','Tür'],
  'Reference': ['Reference','حواله','مرجع','حوالہ','المرجع','संदर्भ','Referencia','Référence','Referans'],
  'Cash In': ['Cash In','نغدي داخل','ورودی نقدی','کیش اِن','نقد داخل','नकद आवक','Entrada de caja','Encaissement','Nakit Girişi'],
  'Cash Out': ['Cash Out','نغدي خارج','خروجی نقدی','کیش آؤٹ','نقد خارج','नकद निकासी','Salida de caja','Décaissement','Nakit Çıkışı'],
  'Running Balance': ['Running Balance','روان بیلانس','مانده جاری','رننگ بیلنس','الرصيد الجاري','चलता शेष','Saldo acumulado','Solde courant','Cari Bakiye'],
  'From': ['From','له','از','سے','من','से','Desde','De','Başlangıç'],
  'To': ['To','تر','تا','تک','إلى','तक','Hasta','À','Bitiş'],
  'Month': ['Month','میاشت','ماه','مہینہ','الشهر','महीना','Mes','Mois','Ay'],
  'Year': ['Year','کال','سال','سال','السنة','वर्ष','Año','Année','Yıl'],
  'Report Type': ['Report Type','د راپور ډول','نوع گزارش','رپورٹ کی قسم','نوع التقرير','रिपोर्ट प्रकार','Tipo de informe','Type de rapport','Rapor Türü'],
  'Search Product': ['Search Product','توکی ولټوئ','جستجوی محصول','مصنوع تلاش کریں','بحث عن منتج','उत्पाद खोजें','Buscar producto','Rechercher un produit','Ürün Ara'],
  'Today\'s Summary': ['Today\'s Summary','د نن لنډیز','خلاصه امروز','آج کا خلاصہ','ملخص اليوم','आज का सारांश','Resumen de hoy','Résumé du jour','Bugünün Özeti'],
  'Owner Summary': ['Owner Summary','د مالک لنډیز','خلاصه مالک','مالک خلاصہ','ملخص المالك','मालिक सारांश','Resumen del propietario','Résumé du propriétaire','Sahip Özeti'],
  'Business Totals': ['Business Totals','د کاروبار ټولیز','مجموع کسب‌وکار','کاروباری کل','إجماليات النشاط','व्यवसाय कुल','Totales del negocio','Totaux de l’entreprise','İşletme Toplamları'],
  'This Week vs Last Week': ['This Week vs Last Week','دا اوونۍ د تېرې اوونۍ پر وړاندې','این هفته در برابر هفته قبل','یہ ہفتہ بمقابلہ پچھلا ہفتہ','هذا الأسبوع مقابل الأسبوع الماضي','इस सप्ताह बनाम पिछले सप्ताह','Esta semana vs la pasada','Cette semaine vs la précédente','Bu Hafta / Geçen Hafta'],
  'Visual Analytics': ['Visual Analytics','بصري شننه','تحلیل بصری','بصری تجزیہ','تحليلات مرئية','दृश्य विश्लेषण','Analítica visual','Analyse visuelle','Görsel Analiz'],
  'Today\'s Activity': ['Today\'s Activity','د نن فعالیت','فعالیت امروز','آج کی سرگرمی','نشاط اليوم','आज की गतिविधि','Actividad de hoy','Activité du jour','Bugünkü Aktivite'],
  'Recent Activity': ['Recent Activity','وروستی فعالیت','فعالیت اخیر','حالیہ سرگرمی','النشاط الأخير','हाल की गतिविधि','Actividad reciente','Activité récente','Son Aktivite'],
  'Top Customer Dues': ['Top Customer Dues','د پېرودونکو لوی پورونه','بیشترین بدهی مشتریان','سب سے زیادہ کسٹمر بقایا','أعلى مستحقات العملاء','शीर्ष ग्राहक बकाया','Principales deudas de clientes','Principales dettes clients','En Yüksek Müşteri Borçları'],
  'Top Salesman Dues': ['Top Salesman Dues','د خرڅوونکو لوی پورونه','بیشترین بدهی فروشندگان','سب سے زیادہ سیلز مین بقایا','أعلى مستحقات المندوبين','शीर्ष सेल्समैन बकाया','Principales deudas de vendedores','Principales dettes vendeurs','En Yüksek Satış Elemanı Borçları'],
  'Business Position': ['Business Position','د کاروبار حالت','وضعیت کسب‌وکار','کاروباری پوزیشن','وضع النشاط','व्यवसाय स्थिति','Posición del negocio','Situation de l’entreprise','İşletme Durumu'],
  'No data.': ['No data.','معلومات نشته.','داده‌ای نیست.','کوئی ڈیٹا نہیں۔','لا توجد بيانات.','कोई डेटा नहीं।','Sin datos.','Aucune donnée.','Veri yok.'],
  'No activity found.': ['No activity found.','فعالیت ونه موندل شو.','فعالیتی یافت نشد.','کوئی سرگرمی نہیں ملی۔','لم يتم العثور على نشاط.','कोई गतिविधि नहीं मिली।','No se encontró actividad.','Aucune activité trouvée.','Aktivite bulunamadı.'],
  'No outstanding dues.': ['No outstanding dues.','پاتې پور نشته.','بدهی معوق نیست.','کوئی بقایا نہیں۔','لا توجد مستحقات معلقة.','कोई बकाया नहीं।','No hay deudas pendientes.','Aucun impayé.','Bekleyen borç yok.'],
  'Select product.': ['Select product.','توکی وټاکئ.','محصول را انتخاب کنید.','مصنوع منتخب کریں۔','اختر المنتج.','उत्पाद चुनें।','Seleccione producto.','Sélectionnez un produit.','Ürün seçin.'],
  'Product name required.': ['Product name required.','د توکي نوم اړین دی.','نام محصول الزامی است.','مصنوع کا نام ضروری ہے۔','اسم المنتج مطلوب.','उत्पाद नाम आवश्यक है।','El nombre del producto es obligatorio.','Le nom du produit est requis.','Ürün adı gerekli.'],
  'Salesman name required.': ['Salesman name required.','د خرڅوونکي نوم اړین دی.','نام فروشنده الزامی است.','سیلز مین کا نام ضروری ہے۔','اسم مندوب المبيعات مطلوب.','सेल्समैन नाम आवश्यक है।','El nombre del vendedor es obligatorio.','Le nom du vendeur est requis.','Satış elemanı adı gerekli.'],
  'Amount must be greater than zero.': ['Amount must be greater than zero.','اندازه باید له صفر څخه زیاته وي.','مبلغ باید بیشتر از صفر باشد.','رقم صفر سے زیادہ ہونی چاہیے۔','يجب أن يكون المبلغ أكبر من صفر.','राशि शून्य से अधिक होनी चाहिए।','El importe debe ser mayor que cero.','Le montant doit être supérieur à zéro.','Tutar sıfırdan büyük olmalıdır.'],
  'Working… please keep QAMVIO open.': ['Working… please keep QAMVIO open.','کار روان دی… QAMVIO خلاص وساتئ.','در حال کار… QAMVIO را باز نگه دارید.','کام جاری ہے… QAMVIO کھلا رکھیں۔','جارٍ العمل… أبقِ QAMVIO مفتوحًا.','काम जारी है… QAMVIO खुला रखें।','Trabajando… mantenga QAMVIO abierto.','Traitement… gardez QAMVIO ouvert.','Çalışıyor… QAMVIO açık kalsın.'],
  'Cloud & Backup': ['Cloud & Backup','کلاوډ او بیک اپ','ابر و پشتیبان','کلاؤڈ اور بیک اپ','السحابة والنسخ الاحتياطي','क्लाउड और बैकअप','Nube y copia','Cloud et sauvegarde','Bulut ve Yedek'],
  'Backup Now': ['Backup Now','اوس بیک اپ','اکنون پشتیبان‌گیری','ابھی بیک اپ','نسخ احتياطي الآن','अभी बैकअप','Respaldar ahora','Sauvegarder maintenant','Şimdi Yedekle'],
  'Restore Latest Flutter Backup': ['Restore Latest Flutter Backup','وروستی Flutter بیک اپ بېرته راولئ','بازیابی آخرین پشتیبان Flutter','تازہ ترین Flutter بیک اپ ریسٹور کریں','استعادة أحدث نسخة Flutter','नवीनतम Flutter बैकअप पुनर्स्थापित करें','Restaurar última copia Flutter','Restaurer la dernière sauvegarde Flutter','Son Flutter Yedeğini Geri Yükle'],
  'Business Setup': ['Business Setup','د کاروبار تنظیم','تنظیم کسب‌وکار','کاروبار سیٹ اپ','إعداد النشاط','व्यवसाय सेटअप','Configuración del negocio','Configuration de l’entreprise','İşletme Kurulumu'],
  'Choose your business model': ['Choose your business model','د کاروبار ډول وټاکئ','مدل کسب‌وکار را انتخاب کنید','اپنا کاروباری ماڈل منتخب کریں','اختر نموذج نشاطك','अपना व्यवसाय मॉडल चुनें','Elija su modelo de negocio','Choisissez votre modèle d’entreprise','İşletme Modelinizi Seçin'],
  'Business setup requires Admin access': ['Business setup requires Admin access','د کاروبار تنظیم د اډمین لاسرسي ته اړتیا لري','تنظیم کسب‌وکار نیاز به دسترسی ادمین دارد','کاروبار سیٹ اپ کے لیے ایڈمن رسائی ضروری ہے','إعداد النشاط يتطلب صلاحية المدير','व्यवसाय सेटअप के लिए एडमिन एक्सेस चाहिए','La configuración requiere acceso de administrador','La configuration nécessite un accès administrateur','İşletme kurulumu için yönetici erişimi gerekir'],
  'Cloud account': ['Cloud account','کلاوډ حساب','حساب ابری','کلاؤڈ اکاؤنٹ','حساب السحابة','क्लाउड खाता','Cuenta en la nube','Compte cloud','Bulut Hesabı'],
  'Signed-in account': ['Signed-in account','ننوتلی حساب','حساب واردشده','سائن اِن اکاؤنٹ','الحساب المسجل','लॉगिन खाता','Cuenta iniciada','Compte connecté','Giriş Yapılan Hesap'],
  'Create new anyway': ['Create new anyway','بیا هم نوی جوړ کړئ','با این حال جدید بسازید','پھر بھی نیا بنائیں','إنشاء جديد على أي حال','फिर भी नया बनाएँ','Crear nuevo de todos modos','Créer quand même','Yine de Yeni Oluştur'],
  'Already have an account?': ['Already have an account?','حساب لرئ؟','از قبل حساب دارید؟','پہلے سے اکاؤنٹ ہے؟','لديك حساب بالفعل؟','पहले से खाता है?','¿Ya tiene una cuenta?','Vous avez déjà un compte ?','Zaten hesabınız var mı?'],
  'Forgot password? Use recovery code': ['Forgot password? Use recovery code','پاسورډ مو هېر دی؟ د ریکوري کوډ وکاروئ','رمز را فراموش کرده‌اید؟ کد بازیابی را استفاده کنید','پاس ورڈ بھول گئے؟ ریکوری کوڈ استعمال کریں','نسيت كلمة المرور؟ استخدم رمز الاسترداد','पासवर्ड भूल गए? रिकवरी कोड उपयोग करें','¿Olvidó la contraseña? Use el código de recuperación','Mot de passe oublié ? Utilisez le code de récupération','Şifreyi mi unuttunuz? Kurtarma kodunu kullanın'],
  'Save your recovery code': ['Save your recovery code','خپل ریکوري کوډ خوندي کړئ','کد بازیابی خود را ذخیره کنید','اپنا ریکوری کوڈ محفوظ کریں','احفظ رمز الاسترداد','रिकवरी कोड सहेजें','Guarde su código de recuperación','Enregistrez votre code de récupération','Kurtarma Kodunuzu Kaydedin'],
  'Recovery code': ['Recovery code','ریکوري کوډ','کد بازیابی','ریکوری کوڈ','رمز الاسترداد','रिकवरी कोड','Código de recuperación','Code de récupération','Kurtarma Kodu'],
  'New Sale': ['New Sale','نوی خرڅلاو','فروش جدید','نئی فروخت','بيع جديد','नई बिक्री','Nueva venta','Nouvelle vente','Yeni Satış'],
  'Saved Sales': ['Saved Sales','خوندي خرڅلاو','فروش‌های ذخیره‌شده','محفوظ فروخت','المبيعات المحفوظة','सहेजी गई बिक्री','Ventas guardadas','Ventes enregistrées','Kayıtlı Satışlar'],
  'New Purchase': ['New Purchase','نوی پېرود','خرید جدید','نئی خریداری','شراء جديد','नई खरीद','Nueva compra','Nouvel achat','Yeni Satın Alma'],
  'Purchase History': ['Purchase History','د پېرود تاریخچه','تاریخچه خرید','خریداری تاریخچہ','سجل المشتريات','खरीद इतिहास','Historial de compras','Historique des achats','Satın Alma Geçmişi'],
  'Add Medicine': ['Add Medicine','درمل زیاتول','افزودن دوا','دوا شامل کریں','إضافة دواء','दवा जोड़ें','Añadir medicamento','Ajouter un médicament','İlaç Ekle'],
  'Medicine name': ['Medicine name','د درمل نوم','نام دوا','دوا کا نام','اسم الدواء','दवा का नाम','Nombre del medicamento','Nom du médicament','İlaç Adı'],
  'Batch number': ['Batch number','د بچ شمېره','شماره بچ','بیچ نمبر','رقم الدفعة','बैच नंबर','Número de lote','Numéro de lot','Parti Numarası'],
  'Expiry date': ['Expiry date','د ختمېدو نېټه','تاریخ انقضا','میعاد ختم ہونے کی تاریخ','تاريخ الانتهاء','समाप्ति तिथि','Fecha de caducidad','Date d’expiration','Son Kullanma Tarihi'],
  'No products': ['No products','توکي نشته','محصولی نیست','کوئی مصنوعات نہیں','لا توجد منتجات','कोई उत्पाद नहीं','Sin productos','Aucun produit','Ürün yok'],
  'No account available': ['No account available','حساب نشته','حسابی موجود نیست','کوئی اکاؤنٹ دستیاب نہیں','لا يوجد حساب','कोई खाता उपलब्ध नहीं','No hay cuenta disponible','Aucun compte disponible','Kullanılabilir hesap yok'],
  'BUSINESS': ['BUSINESS','کاروبار','کسب‌وکار','کاروبار','النشاط','व्यवसाय','NEGOCIO','ENTREPRISE','İŞLETME'],
  'SALES': ['SALES','خرڅلاو','فروشات','فروخت','المبيعات','बिक्री','VENTAS','VENTES','SATIŞ'],
  'STOCK': ['STOCK','سټاک','موجودی','اسٹاک','المخزون','स्टॉक','STOCK','STOCK','STOK'],
  'PEOPLE': ['PEOPLE','خلک','افراد','لوگ','الأشخاص','लोग','PERSONAS','PERSONNES','KİŞİLER'],
  'MONEY': ['MONEY','پیسې','پول','رقم','المال','पैसा','DINERO','ARGENT','PARA'],
  'REPORTS': ['REPORTS','راپورونه','گزارش‌ها','رپورٹس','التقارير','रिपोर्ट','INFORMES','RAPPORTS','RAPORLAR'],
  'SYSTEM': ['SYSTEM','سیستم','سیستم','سسٹم','النظام','सिस्टम','SISTEMA','SYSTÈME','SİSTEM'],
  'Expense': ['Expense','لګښت','مصرف','خرچ','مصروف','खर्च','Gasto','Dépense','Gider'],
  'Name': ['Name','نوم','نام','نام','الاسم','नाम','Nombre','Nom','Ad'],
  'Category': ['Category','کټګوري','دسته','کیٹیگری','الفئة','श्रेणी','Categoría','Catégorie','Kategori'],
  'Salary': ['Salary','معاش','معاش','تنخواہ','الراتب','वेतन','Salario','Salaire','Maaş'],
  'Oil': ['Oil','تېل','روغن','تیل','الزيت','तेल','Aceite','Huile','Yağ'],
  'Mechanic': ['Mechanic','میخانیک','مکانیک','مکینک','ميكانيكي','मैकेनिक','Mecánico','Mécanicien','Tamirci'],
  'Extra': ['Extra','اضافي','اضافی','اضافی','إضافي','अतिरिक्त','Extra','Supplémentaire','Ek'],
  'Other': ['Other','نور','دیگر','دیگر','أخرى','अन्य','Otro','Autre','Diğer'],
  'Opening': ['Opening','پیل','آغازین','اوپننگ','افتتاحي','प्रारंभिक','Apertura','Ouverture','Açılış'],
  'Closing': ['Closing','تړل','بستن','کلوزنگ','إغلاق','समापन','Cierre','Clôture','Kapanış'],
  'Capacity': ['Capacity','ظرفیت','ظرفیت','گنجائش','السعة','क्षमता','Capacidad','Capacité','Kapasite'],
  'Liters': ['Liters','لیتر','لیتر','لیٹر','لترات','लीटर','Litros','Litres','Litre'],
  'Shift': ['Shift','شفټ','شیفت','شفٹ','الوردية','शिफ्ट','Turno','Équipe','Vardiya'],
  'Tank': ['Tank','ټانک','مخزن','ٹینک','الخزان','टैंक','Tanque','Réservoir','Tank'],
  'Nozzle': ['Nozzle','نوزل','نازل','نوزل','الفوهة','नोज़ल','Boquilla','Pistolet','Nozul'],
  'Payment': ['Payment','تادیه','پرداخت','ادائیگی','الدفع','भुगतान','Pago','Paiement','Ödeme'],
  'Transaction': ['Transaction','معامله','تراکنش','لین دین','المعاملة','लेनदेन','Transacción','Transaction','İşlem'],
  'Account': ['Account','حساب','حساب','اکاؤنٹ','الحساب','खाता','Cuenta','Compte','Hesap'],
  'Loan': ['Loan','پور','قرض','قرض','قرض','ऋण','Préstamo','Prêt','Borç'],
  'Given': ['Given','ورکړل شوی','داده‌شده','دیا گیا','مُعطى','दिया गया','Dado','Donné','Verilen'],
  'Report': ['Report','راپور','گزارش','رپورٹ','تقرير','रिपोर्ट','Informe','Rapport','Rapor'],
  'Daily': ['Daily','ورځنی','روزانه','روزانہ','يومي','दैनिक','Diario','Quotidien','Günlük'],
  'Monthly': ['Monthly','میاشتنی','ماهانه','ماہانہ','شهري','मासिक','Mensual','Mensuel','Aylık'],
  'Yearly': ['Yearly','کلنی','سالانه','سالانہ','سنوي','वार्षिक','Anual','Annuel','Yıllık'],
  'Section': ['Section','برخه','بخش','سیکشن','القسم','अनुभाग','Sección','Section','Bölüm'],
  'Record': ['Record','ریکارډ','رکورد','ریکارڈ','سجل','रिकॉर्ड','Registro','Enregistrement','Kayıt'],
  'Security': ['Security','امنیت','امنیت','سیکیورٹی','الأمان','सुरक्षा','Seguridad','Sécurité','Güvenlik'],
  'Settings': ['Settings','تنظیمات','تنظیمات','سیٹنگز','الإعدادات','सेटिंग्स','Configuración','Paramètres','Ayarlar'],
  'Business': ['Business','کاروبار','کسب‌وکار','کاروبار','النشاط','व्यवसाय','Negocio','Entreprise','İşletme'],
  'Price': ['Price','بیه','قیمت','قیمت','السعر','मूल्य','Precio','Prix','Fiyat'],
  'Balance': ['Balance','بیلانس','موجودی','بیلنس','الرصيد','शेष','Saldo','Solde','Bakiye'],
  'Current': ['Current','اوسنی','فعلی','موجودہ','الحالي','वर्तमान','Actual','Actuel','Güncel'],
  'Purchased': ['Purchased','پېرودل شوی','خریداری‌شده','خریدا گیا','مُشترى','खरीदा गया','Comprado','Acheté','Satın Alınan'],
  'Sold': ['Sold','پلورل شوی','فروخته‌شده','فروخت شدہ','مباع','बेचा गया','Vendido','Vendu','Satılan'],
  'Adjust': ['Adjust','سمون','تنظیم','ایڈجسٹ','تعديل','समायोजन','Ajustar','Ajuster','Ayarla'],
  'Ref': ['Ref','حواله','مرجع','حوالہ','مرجع','संदर्भ','Ref.','Réf.','Ref.'],
  'You': ['You','تاسو','شما','آپ','أنت','आप','Tú','Vous','Siz'],
  'Vehicle': ['Vehicle','موټر','وسیله نقلیه','گاڑی','المركبة','वाहन','Vehículo','Véhicule','Araç'],
  'Medicine': ['Medicine','درمل','دوا','دوا','الدواء','दवा','Medicamento','Médicament','İlaç'],
  'Batch': ['Batch','بچ','بچ','بیچ','الدفعة','बैच','Lote','Lot','Parti'],
  'Expiry': ['Expiry','ختمېدو','انقضا','میعاد','الانتهاء','समाप्ति','Caducidad','Expiration','Son Kullanma'],
  'Fuel': ['Fuel','سون توکي','سوخت','فیول','الوقود','ईंधन','Combustible','Carburant','Yakıt'],
  'Backup': ['Backup','بیک اپ','پشتیبان','بیک اپ','نسخ احتياطي','बैकअप','Copia','Sauvegarde','Yedek'],
  'User': ['User','کاروونکی','کاربر','یوزر','مستخدم','उपयोगकर्ता','Usuario','Utilisateur','Kullanıcı'],
};

final Map<AppLanguage, Map<String, String>> _wordMap = {
  AppLanguage.pashto: const {
    'Date':'نېټه','Stock':'سټاک','Reorder':'بیا فرمایش','Balance':'بیلانس','Total':'ټول',
    'Due':'پور','Customer':'پېرودونکی','Supplier':'عرضه کوونکی','Salesman':'خرڅوونکی',
    'Invoice':'انوایس','Opening':'پیل','Current':'اوسنی','Paid':'ورکړل شوي',
    'Received':'ترلاسه شوي','Amount':'اندازه','Note':'یادښت','From':'له','To':'تر',
    'Type':'ډول','Reference':'حواله','Cash':'نغدي','Phone':'تلیفون','Status':'حالت',
    'Product':'توکی','Qty':'مقدار','Cost':'لګښت','Price':'بیه','Discount':'تخفیف',
    'Recovery':'وصول',
  },
  AppLanguage.dari: const {
    'Date':'تاریخ','Stock':'موجودی','Reorder':'سفارش مجدد','Balance':'موجودی','Total':'مجموع',
    'Due':'باقی','Customer':'مشتری','Supplier':'تأمین‌کننده','Salesman':'فروشنده',
    'Invoice':'فاکتور','Opening':'آغازین','Current':'فعلی','Paid':'پرداخت‌شده',
    'Received':'دریافت‌شده','Amount':'مبلغ','Note':'یادداشت','From':'از','To':'تا',
    'Type':'نوع','Reference':'مرجع','Cash':'نقد','Phone':'تلفن','Status':'وضعیت',
    'Product':'محصول','Qty':'تعداد','Cost':'هزینه','Price':'قیمت','Discount':'تخفیف',
    'Recovery':'دریافت',
  },
  AppLanguage.urdu: const {
    'Date':'تاریخ','Stock':'اسٹاک','Reorder':'ری آرڈر','Balance':'بیلنس','Total':'کل',
    'Due':'بقایا','Customer':'گاہک','Supplier':'سپلائر','Salesman':'سیلز مین',
    'Invoice':'انوائس','Opening':'اوپننگ','Current':'موجودہ','Paid':'ادا شدہ',
    'Received':'وصول شدہ','Amount':'رقم','Note':'نوٹ','From':'سے','To':'تک',
    'Type':'قسم','Reference':'حوالہ','Cash':'کیش','Phone':'فون','Status':'حالت',
    'Product':'مصنوع','Qty':'مقدار','Cost':'لاگت','Price':'قیمت','Discount':'ڈسکاؤنٹ',
    'Recovery':'ریکوری',
  },
  AppLanguage.arabic: const {
    'Date':'التاريخ','Stock':'المخزون','Reorder':'إعادة الطلب','Balance':'الرصيد','Total':'الإجمالي',
    'Due':'المستحق','Customer':'العميل','Supplier':'المورد','Salesman':'مندوب المبيعات',
    'Invoice':'الفاتورة','Opening':'الافتتاحي','Current':'الحالي','Paid':'مدفوع',
    'Received':'مستلم','Amount':'المبلغ','Note':'ملاحظة','From':'من','To':'إلى',
    'Type':'النوع','Reference':'المرجع','Cash':'نقد','Phone':'الهاتف','Status':'الحالة',
    'Product':'المنتج','Qty':'الكمية','Cost':'التكلفة','Price':'السعر','Discount':'الخصم',
    'Recovery':'التحصيل',
  },
  AppLanguage.hindi: const {
    'Date':'तारीख','Stock':'स्टॉक','Reorder':'पुनः ऑर्डर','Balance':'शेष','Total':'कुल',
    'Due':'बकाया','Customer':'ग्राहक','Supplier':'आपूर्तिकर्ता','Salesman':'सेल्समैन',
    'Invoice':'चालान','Opening':'प्रारंभिक','Current':'वर्तमान','Paid':'भुगतान',
    'Received':'प्राप्त','Amount':'राशि','Note':'नोट','From':'से','To':'तक',
    'Type':'प्रकार','Reference':'संदर्भ','Cash':'नकद','Phone':'फोन','Status':'स्थिति',
    'Product':'उत्पाद','Qty':'मात्रा','Cost':'लागत','Price':'मूल्य','Discount':'छूट',
    'Recovery':'वसूली',
  },
  AppLanguage.spanish: const {
    'Date':'Fecha','Stock':'Stock','Reorder':'Reposición','Balance':'Saldo','Total':'Total',
    'Due':'Pendiente','Customer':'Cliente','Supplier':'Proveedor','Salesman':'Vendedor',
    'Invoice':'Factura','Opening':'Inicial','Current':'Actual','Paid':'Pagado',
    'Received':'Recibido','Amount':'Importe','Note':'Nota','From':'Desde','To':'Hasta',
    'Type':'Tipo','Reference':'Referencia','Cash':'Caja','Phone':'Teléfono','Status':'Estado',
    'Product':'Producto','Qty':'Cant.','Cost':'Costo','Price':'Precio','Discount':'Descuento',
    'Recovery':'Recuperación',
  },
  AppLanguage.french: const {
    'Date':'Date','Stock':'Stock','Reorder':'Réapprovisionnement','Balance':'Solde','Total':'Total',
    'Due':'Dû','Customer':'Client','Supplier':'Fournisseur','Salesman':'Vendeur',
    'Invoice':'Facture','Opening':'Initial','Current':'Actuel','Paid':'Payé',
    'Received':'Reçu','Amount':'Montant','Note':'Note','From':'De','To':'À',
    'Type':'Type','Reference':'Référence','Cash':'Caisse','Phone':'Téléphone','Status':'Statut',
    'Product':'Produit','Qty':'Qté','Cost':'Coût','Price':'Prix','Discount':'Remise',
    'Recovery':'Recouvrement',
  },
  AppLanguage.turkish: const {
    'Date':'Tarih','Stock':'Stok','Reorder':'Yeniden Sipariş','Balance':'Bakiye','Total':'Toplam',
    'Due':'Borç','Customer':'Müşteri','Supplier':'Tedarikçi','Salesman':'Satış Elemanı',
    'Invoice':'Fatura','Opening':'Açılış','Current':'Güncel','Paid':'Ödendi',
    'Received':'Alındı','Amount':'Tutar','Note':'Not','From':'Başlangıç','To':'Bitiş',
    'Type':'Tür','Reference':'Referans','Cash':'Nakit','Phone':'Telefon','Status':'Durum',
    'Product':'Ürün','Qty':'Miktar','Cost':'Maliyet','Price':'Fiyat','Discount':'İndirim',
    'Recovery':'Tahsilat',
  },
};
).hasMatch(entry.key) &&
        language.index < entry.value.length) {
      words.putIfAbsent(
        entry.key.toLowerCase(),
        () => entry.value[language.index],
      );
    }
  }

  var matchCount = 0;
  for (final word in words.keys) {
    if (RegExp('\\b' + RegExp.escape(word) + '\\b', caseSensitive: false)
        .hasMatch(value)) {
      matchCount++;
    }
  }

  if (dynamicPrefix.hasMatch(value) || matchCount >= 2) {
    var out = value;
    final ordered = words.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final word in ordered) {
      out = out.replaceAll(
        RegExp('\\b' + RegExp.escape(word) + '\\b', caseSensitive: false),
        words[word]!,
      );
    }
    return out;
  }

  return value;
}

/// Drop-in localized replacement for Flutter's Text widget.
/// Feature pages import Material with "hide Text" and this class instead.
class Text extends m.StatelessWidget {
  final String data;
  final m.TextStyle? style;
  final m.StrutStyle? strutStyle;
  final m.TextAlign? textAlign;
  final m.TextDirection? textDirection;
  final m.Locale? locale;
  final bool? softWrap;
  final m.TextOverflow? overflow;
  final m.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final m.TextWidthBasis? textWidthBasis;
  final m.TextHeightBehavior? textHeightBehavior;
  final m.Color? selectionColor;

  const Text(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  @override
  m.Widget build(m.BuildContext context) => m.Text(
        tr(data),
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel == null ? null : tr(semanticsLabel!),
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
}

const Map<String, List<String>> _ui = {
  // [English, Pashto, Dari, Urdu, Arabic, Hindi, Spanish, French, Turkish]
  'Dashboard': ['Dashboard','ډشبورډ','داشبورد','ڈیش بورڈ','لوحة التحكم','डैशबोर्ड','Panel','Tableau de bord','Kontrol Paneli'],
  'Sales': ['Sales','خرڅلاو','فروشات','فروخت','المبيعات','बिक्री','Ventas','Ventes','Satış'],
  'Sales / Cash Report': ['Sales / Cash Report','خرڅلاو / نغدي راپور','فروشات / گزارش نقدی','فروخت / کیش رپورٹ','تقرير المبيعات / النقد','बिक्री / नकद रिपोर्ट','Ventas / Informe de caja','Ventes / Rapport de caisse','Satış / Nakit Raporu'],
  'Fuel / Oil Pump': ['Fuel / Oil Pump','د تېلو پمپ','پمپ سوخت / روغن','فیول / آئل پمپ','مضخة الوقود / الزيت','ईंधन / तेल पंप','Bomba de combustible / aceite','Pompe carburant / huile','Yakıt / Yağ Pompası'],
  'Pharmacy': ['Pharmacy','درملتون','داروخانه','فارمیسی','الصيدلية','फार्मेसी','Farmacia','Pharmacie','Eczane'],
  'Stock': ['Stock','سټاک','موجودی','اسٹاک','المخزون','स्टॉक','Stock','Stock','Stok'],
  'Stock Ledger': ['Stock Ledger','د سټاک لیجر','دفتر موجودی','اسٹاک لیجر','دفتر المخزون','स्टॉक लेजर','Libro de stock','Grand livre de stock','Stok Defteri'],
  'Products': ['Products','توکي','محصولات','مصنوعات','المنتجات','उत्पाद','Productos','Produits','Ürünler'],
  'Purchases': ['Purchases','پېرودونه','خریدها','خریداری','المشتريات','खरीदारी','Compras','Achats','Satın Almalar'],
  'Customers': ['Customers','پېرودونکي','مشتریان','گاہک','العملاء','ग्राहक','Clientes','Clients','Müşteriler'],
  'Suppliers': ['Suppliers','عرضه کوونکي','تأمین‌کنندگان','سپلائرز','الموردون','आपूर्तिकर्ता','Proveedores','Fournisseurs','Tedarikçiler'],
  'Salesmen': ['Salesmen','خرڅوونکي','فروشندگان','سیلز مین','مندوبو المبيعات','सेल्समैन','Vendedores','Vendeurs','Satış Elemanları'],
  'Expenses': ['Expenses','لګښتونه','مصارف','اخراجات','المصروفات','खर्चे','Gastos','Dépenses','Giderler'],
  'Reports': ['Reports','راپورونه','گزارش‌ها','رپورٹس','التقارير','रिपोर्ट','Informes','Rapports','Raporlar'],
  'Cash Book': ['Cash Book','نغدي کتاب','دفتر نقدی','کیش بک','دفتر النقدية','कैश बुक','Libro de caja','Livre de caisse','Kasa Defteri'],
  'Daily Closing': ['Daily Closing','ورځنی تړل','بستن روزانه','ڈیلی کلوزنگ','الإغلاق اليومي','दैनिक समापन','Cierre diario','Clôture quotidienne','Günlük Kapanış'],
  'Customer Loans': ['Customer Loans','د پېرودونکو پورونه','قرض مشتریان','کسٹمر لونز','ديون العملاء','ग्राहक ऋण','Préstamos de clientes','Prêts clients','Müşteri Borçları'],
  'Salesman Loans': ['Salesman Loans','د خرڅوونکو پورونه','قرض فروشندگان','سیلز مین لونز','ديون مندوبي المبيعات','सेल्समैन ऋण','Préstamos de vendedores','Prêts vendeurs','Satış Elemanı Borçları'],
  'Customer Statement / Ledger': ['Customer Statement / Ledger','د پېرودونکي حساب / لیجر','صورت حساب / دفتر مشتری','کسٹمر اسٹیٹمنٹ / لیجر','كشف حساب العميل','ग्राहक स्टेटमेंट / लेजर','Estado / Libro del cliente','Relevé / Grand livre client','Müşteri Ekstresi / Defter'],
  'Supplier Statement / Ledger': ['Supplier Statement / Ledger','د عرضه کوونکي حساب / لیجر','صورت حساب / دفتر تأمین‌کننده','سپلائر اسٹیٹمنٹ / لیجر','كشف حساب المورد','आपूर्तिकर्ता स्टेटमेंट / लेजर','Estado / Libro del proveedor','Relevé / Grand livre fournisseur','Tedarikçi Ekstresi / Defter'],
  'Salesman Statement / Ledger': ['Salesman Statement / Ledger','د خرڅوونکي حساب / لیجر','صورت حساب / دفتر فروشنده','سیلز مین اسٹیٹمنٹ / لیجر','كشف حساب مندوب المبيعات','सेल्समैन स्टेटमेंट / लेजर','Estado / Libro del vendedor','Relevé / Grand livre vendeur','Satış Elemanı Ekstresi / Defter'],
  'Owner / Partner Money': ['Owner / Partner Money','د مالک / شریک پیسې','پول مالک / شریک','مالک / پارٹنر رقم','أموال المالك / الشريك','मालिक / भागीदार धन','Dinero del propietario / socio','Argent propriétaire / associé','Sahip / Ortak Parası'],
  'Backup / Restore': ['Backup / Restore','بیک اپ / بېرته راګرځول','پشتیبان / بازیابی','بیک اپ / ریسٹور','نسخ احتياطي / استعادة','बैकअप / पुनर्स्थापना','Copia / Restaurar','Sauvegarde / Restaurer','Yedekle / Geri Yükle'],
  'Users / Login': ['Users / Login','کاروونکي / ننوتل','کاربران / ورود','یوزرز / لاگ اِن','المستخدمون / تسجيل الدخول','उपयोगकर्ता / लॉगिन','Usuarios / Inicio de sesión','Utilisateurs / Connexion','Kullanıcılar / Giriş'],
  'Safety Center': ['Safety Center','امنیت مرکز','مرکز امنیت','سیفٹی سینٹر','مركز الأمان','सुरक्षा केंद्र','Centro de seguridad','Centre de sécurité','Güvenlik Merkezi'],
  'Recycle Bin': ['Recycle Bin','کثافت دان','سطل بازیافت','ری سائیکل بن','سلة المحذوفات','रीसायकल बिन','Papelera','Corbeille','Geri Dönüşüm Kutusu'],
  'Delete Entry': ['Delete Entry','ریکارډ ړنګول','حذف رکورد','انٹری حذف کریں','حذف السجل','एंट्री हटाएँ','Eliminar entrada','Supprimer l’entrée','Kaydı Sil'],
  'Quick Search': ['Quick Search','چټک لټون','جستجوی سریع','فوری تلاش','بحث سريع','त्वरित खोज','Búsqueda rápida','Recherche rapide','Hızlı Arama'],
  'Discount Report': ['Discount Report','د تخفیف راپور','گزارش تخفیف','ڈسکاؤنٹ رپورٹ','تقرير الخصومات','छूट रिपोर्ट','Informe de descuentos','Rapport des remises','İndirim Raporu'],
  'Language': ['Language','ژبه','زبان','زبان','اللغة','भाषा','Idioma','Langue','Dil'],
  'Save': ['Save','خوندي کول','ذخیره','محفوظ کریں','حفظ','सहेजें','Guardar','Enregistrer','Kaydet'],
  'Cancel': ['Cancel','لغوه','لغو','منسوخ','إلغاء','रद्द करें','Cancelar','Annuler','İptal'],
  'Delete': ['Delete','ړنګول','حذف','حذف کریں','حذف','हटाएँ','Eliminar','Supprimer','Sil'],
  'Edit': ['Edit','سمون','ویرایش','ترمیم','تعديل','संपादित करें','Editar','Modifier','Düzenle'],
  'Continue': ['Continue','دوام','ادامه','جاری رکھیں','متابعة','जारी रखें','Continuar','Continuer','Devam'],
  'Close': ['Close','تړل','بستن','بند کریں','إغلاق','बंद करें','Cerrar','Fermer','Kapat'],
  'Search': ['Search','لټون','جستجو','تلاش','بحث','खोज','Buscar','Rechercher','Ara'],
  'Print': ['Print','چاپ','چاپ','پرنٹ','طباعة','प्रिंट','Imprimir','Imprimer','Yazdır'],
  'Restore': ['Restore','بېرته راګرځول','بازیابی','ریسٹور','استعادة','पुनर्स्थापित करें','Restaurar','Restaurer','Geri Yükle'],
  'Refresh': ['Refresh','تازه کول','تازه‌سازی','ریفریش','تحديث','रीफ्रेश','Actualizar','Actualiser','Yenile'],
  'WhatsApp': ['WhatsApp','واټس‌اپ','واتساپ','واٹس ایپ','واتساب','व्हाट्सऐप','WhatsApp','WhatsApp','WhatsApp'],
  'Copy': ['Copy','کاپي','کپی','کاپی','نسخ','कॉपी','Copiar','Copier','Kopyala'],
  'Not now': ['Not now','اوس نه','فعلاً نه','ابھی نہیں','ليس الآن','अभी नहीं','Ahora no','Pas maintenant','Şimdi değil'],
  'Back to sign in': ['Back to sign in','بېرته ننوتلو ته','بازگشت به ورود','واپس لاگ اِن','العودة لتسجيل الدخول','लॉगिन पर वापस','Volver al inicio','Retour à la connexion','Girişe Dön'],
  'Sign out': ['Sign out','وتل','خروج','سائن آؤٹ','تسجيل الخروج','साइन आउट','Cerrar sesión','Se déconnecter','Çıkış Yap'],
  'Logout': ['Logout','وتل','خروج','لاگ آؤٹ','تسجيل الخروج','लॉग आउट','Cerrar sesión','Déconnexion','Çıkış'],
  'Add': ['Add','زیاتول','افزودن','شامل کریں','إضافة','जोड़ें','Añadir','Ajouter','Ekle'],
  'Add Line': ['Add Line','کرښه زیاتول','افزودن ردیف','لائن شامل کریں','إضافة سطر','पंक्ति जोड़ें','Añadir línea','Ajouter une ligne','Satır Ekle'],
  'Add Entry': ['Add Entry','ریکارډ زیاتول','افزودن رکورد','انٹری شامل کریں','إضافة سجل','एंट्री जोड़ें','Añadir entrada','Ajouter une entrée','Kayıt Ekle'],
  'Create user': ['Create user','کاروونکی جوړول','ایجاد کاربر','یوزر بنائیں','إنشاء مستخدم','उपयोगकर्ता बनाएँ','Crear usuario','Créer un utilisateur','Kullanıcı Oluştur'],
  'Date': ['Date','نېټه','تاریخ','تاریخ','التاريخ','तारीख','Fecha','Date','Tarih'],
  'Invoice': ['Invoice','انوایس','فاکتور','انوائس','فاتورة','चालान','Factura','Facture','Fatura'],
  'Invoice No': ['Invoice No','د انوایس شمېره','شماره فاکتور','انوائس نمبر','رقم الفاتورة','चालान नंबर','N.º factura','N° facture','Fatura No'],
  'Customer': ['Customer','پېرودونکی','مشتری','گاہک','عميل','ग्राहक','Cliente','Client','Müşteri'],
  'Supplier': ['Supplier','عرضه کوونکی','تأمین‌کننده','سپلائر','مورد','आपूर्तिकर्ता','Proveedor','Fournisseur','Tedarikçi'],
  'Salesman': ['Salesman','خرڅوونکی','فروشنده','سیلز مین','مندوب المبيعات','सेल्समैन','Vendedor','Vendeur','Satış Elemanı'],
  'Product': ['Product','توکی','محصول','مصنوع','المنتج','उत्पाद','Producto','Produit','Ürün'],
  'Qty': ['Qty','مقدار','تعداد','مقدار','الكمية','मात्रा','Cant.','Qté','Miktar'],
  'Cost': ['Cost','لګښت','هزینه','لاگت','التكلفة','लागत','Costo','Coût','Maliyet'],
  'Amount': ['Amount','اندازه','مبلغ','رقم','المبلغ','राशि','Importe','Montant','Tutar'],
  'Total': ['Total','ټول','مجموع','کل','الإجمالي','कुल','Total','Total','Toplam'],
  'Paid': ['Paid','ورکړل شوي','پرداخت‌شده','ادا شدہ','مدفوع','भुगतान','Pagado','Payé','Ödendi'],
  'Received': ['Received','ترلاسه شوي','دریافت‌شده','وصول شدہ','مستلم','प्राप्त','Recibido','Reçu','Alındı'],
  'Due': ['Due','پور','باقی','بقایا','مستحق','बकाया','Pendiente','Dû','Borç'],
  'Recovery': ['Recovery','وصول','دریافت','ریکوری','تحصيل','वसूली','Recuperación','Recouvrement','Tahsilat'],
  'Discount': ['Discount','تخفیف','تخفیف','ڈسکاؤنٹ','خصم','छूट','Descuento','Remise','İndirim'],
  'Note': ['Note','یادښت','یادداشت','نوٹ','ملاحظة','नोट','Nota','Note','Not'],
  'Phone': ['Phone','تلیفون','تلفن','فون','الهاتف','फोन','Teléfono','Téléphone','Telefon'],
  'Address': ['Address','پته','آدرس','پتہ','العنوان','पता','Dirección','Adresse','Adres'],
  'Currency': ['Currency','اسعار','واحد پول','کرنسی','العملة','मुद्रा','Moneda','Devise','Para Birimi'],
  'Business Type': ['Business Type','د کاروبار ډول','نوع کسب‌وکار','کاروبار کی قسم','نوع النشاط','व्यवसाय प्रकार','Tipo de negocio','Type d’entreprise','İşletme Türü'],
  'Role': ['Role','رول','نقش','کردار','الدور','भूमिका','Rol','Rôle','Rol'],
  'Password': ['Password','پاسورډ','رمز عبور','پاس ورڈ','كلمة المرور','पासवर्ड','Contraseña','Mot de passe','Şifre'],
  'Confirm password': ['Confirm password','پاسورډ تایید','تأیید رمز عبور','پاس ورڈ کی تصدیق','تأكيد كلمة المرور','पासवर्ड की पुष्टि','Confirmar contraseña','Confirmer le mot de passe','Şifreyi Doğrula'],
  'Email or mobile': ['Email or mobile','برېښنالیک یا موبایل','ایمیل یا موبایل','ای میل یا موبائل','البريد أو الجوال','ईमेल या मोबाइल','Correo o móvil','E-mail ou mobile','E-posta veya Mobil'],
  'Credit Limit': ['Credit Limit','د پور حد','حد اعتبار','کریڈٹ حد','حد الائتمان','क्रेडिट सीमा','Límite de crédito','Limite de crédit','Kredi Limiti'],
  'Opening Balance': ['Opening Balance','پیل بیلانس','موجودی آغازین','اوپننگ بیلنس','الرصيد الافتتاحي','प्रारंभिक शेष','Saldo inicial','Solde initial','Açılış Bakiyesi'],
  'Current Balance': ['Current Balance','اوسنی بیلانس','موجودی فعلی','موجودہ بیلنس','الرصيد الحالي','वर्तमान शेष','Saldo actual','Solde actuel','Güncel Bakiye'],
  'Current Stock': ['Current Stock','اوسنی سټاک','موجودی فعلی','موجودہ اسٹاک','المخزون الحالي','वर्तमान स्टॉक','Stock actual','Stock actuel','Mevcut Stok'],
  'Opening Qty': ['Opening Qty','پیل مقدار','تعداد آغازین','اوپننگ مقدار','الكمية الافتتاحية','प्रारंभिक मात्रा','Cantidad inicial','Qté initiale','Açılış Miktarı'],
  'Reorder Level': ['Reorder Level','د بیا فرمایش کچه','سطح سفارش مجدد','ری آرڈر لیول','حد إعادة الطلب','पुनः ऑर्डर स्तर','Nivel de reposición','Niveau de réapprovisionnement','Yeniden Sipariş Seviyesi'],
  'Sale Price': ['Sale Price','د خرڅلاو بیه','قیمت فروش','فروخت قیمت','سعر البيع','बिक्री मूल्य','Precio de venta','Prix de vente','Satış Fiyatı'],
  'Cost Price': ['Cost Price','د پېر بیه','قیمت خرید','لاگت قیمت','سعر التكلفة','लागत मूल्य','Precio de costo','Prix de revient','Maliyet Fiyatı'],
  'Stock Value': ['Stock Value','د سټاک ارزښت','ارزش موجودی','اسٹاک ویلیو','قيمة المخزون','स्टॉक मूल्य','Valor del stock','Valeur du stock','Stok Değeri'],
  'Status': ['Status','حالت','وضعیت','حالت','الحالة','स्थिति','Estado','Statut','Durum'],
  'Type': ['Type','ډول','نوع','قسم','النوع','प्रकार','Tipo','Type','Tür'],
  'Reference': ['Reference','حواله','مرجع','حوالہ','المرجع','संदर्भ','Referencia','Référence','Referans'],
  'Cash In': ['Cash In','نغدي داخل','ورودی نقدی','کیش اِن','نقد داخل','नकद आवक','Entrada de caja','Encaissement','Nakit Girişi'],
  'Cash Out': ['Cash Out','نغدي خارج','خروجی نقدی','کیش آؤٹ','نقد خارج','नकद निकासी','Salida de caja','Décaissement','Nakit Çıkışı'],
  'Running Balance': ['Running Balance','روان بیلانس','مانده جاری','رننگ بیلنس','الرصيد الجاري','चलता शेष','Saldo acumulado','Solde courant','Cari Bakiye'],
  'From': ['From','له','از','سے','من','से','Desde','De','Başlangıç'],
  'To': ['To','تر','تا','تک','إلى','तक','Hasta','À','Bitiş'],
  'Month': ['Month','میاشت','ماه','مہینہ','الشهر','महीना','Mes','Mois','Ay'],
  'Year': ['Year','کال','سال','سال','السنة','वर्ष','Año','Année','Yıl'],
  'Report Type': ['Report Type','د راپور ډول','نوع گزارش','رپورٹ کی قسم','نوع التقرير','रिपोर्ट प्रकार','Tipo de informe','Type de rapport','Rapor Türü'],
  'Search Product': ['Search Product','توکی ولټوئ','جستجوی محصول','مصنوع تلاش کریں','بحث عن منتج','उत्पाद खोजें','Buscar producto','Rechercher un produit','Ürün Ara'],
  'Today\'s Summary': ['Today\'s Summary','د نن لنډیز','خلاصه امروز','آج کا خلاصہ','ملخص اليوم','आज का सारांश','Resumen de hoy','Résumé du jour','Bugünün Özeti'],
  'Owner Summary': ['Owner Summary','د مالک لنډیز','خلاصه مالک','مالک خلاصہ','ملخص المالك','मालिक सारांश','Resumen del propietario','Résumé du propriétaire','Sahip Özeti'],
  'Business Totals': ['Business Totals','د کاروبار ټولیز','مجموع کسب‌وکار','کاروباری کل','إجماليات النشاط','व्यवसाय कुल','Totales del negocio','Totaux de l’entreprise','İşletme Toplamları'],
  'This Week vs Last Week': ['This Week vs Last Week','دا اوونۍ د تېرې اوونۍ پر وړاندې','این هفته در برابر هفته قبل','یہ ہفتہ بمقابلہ پچھلا ہفتہ','هذا الأسبوع مقابل الأسبوع الماضي','इस सप्ताह बनाम पिछले सप्ताह','Esta semana vs la pasada','Cette semaine vs la précédente','Bu Hafta / Geçen Hafta'],
  'Visual Analytics': ['Visual Analytics','بصري شننه','تحلیل بصری','بصری تجزیہ','تحليلات مرئية','दृश्य विश्लेषण','Analítica visual','Analyse visuelle','Görsel Analiz'],
  'Today\'s Activity': ['Today\'s Activity','د نن فعالیت','فعالیت امروز','آج کی سرگرمی','نشاط اليوم','आज की गतिविधि','Actividad de hoy','Activité du jour','Bugünkü Aktivite'],
  'Recent Activity': ['Recent Activity','وروستی فعالیت','فعالیت اخیر','حالیہ سرگرمی','النشاط الأخير','हाल की गतिविधि','Actividad reciente','Activité récente','Son Aktivite'],
  'Top Customer Dues': ['Top Customer Dues','د پېرودونکو لوی پورونه','بیشترین بدهی مشتریان','سب سے زیادہ کسٹمر بقایا','أعلى مستحقات العملاء','शीर्ष ग्राहक बकाया','Principales deudas de clientes','Principales dettes clients','En Yüksek Müşteri Borçları'],
  'Top Salesman Dues': ['Top Salesman Dues','د خرڅوونکو لوی پورونه','بیشترین بدهی فروشندگان','سب سے زیادہ سیلز مین بقایا','أعلى مستحقات المندوبين','शीर्ष सेल्समैन बकाया','Principales deudas de vendedores','Principales dettes vendeurs','En Yüksek Satış Elemanı Borçları'],
  'Business Position': ['Business Position','د کاروبار حالت','وضعیت کسب‌وکار','کاروباری پوزیشن','وضع النشاط','व्यवसाय स्थिति','Posición del negocio','Situation de l’entreprise','İşletme Durumu'],
  'No data.': ['No data.','معلومات نشته.','داده‌ای نیست.','کوئی ڈیٹا نہیں۔','لا توجد بيانات.','कोई डेटा नहीं।','Sin datos.','Aucune donnée.','Veri yok.'],
  'No activity found.': ['No activity found.','فعالیت ونه موندل شو.','فعالیتی یافت نشد.','کوئی سرگرمی نہیں ملی۔','لم يتم العثور على نشاط.','कोई गतिविधि नहीं मिली।','No se encontró actividad.','Aucune activité trouvée.','Aktivite bulunamadı.'],
  'No outstanding dues.': ['No outstanding dues.','پاتې پور نشته.','بدهی معوق نیست.','کوئی بقایا نہیں۔','لا توجد مستحقات معلقة.','कोई बकाया नहीं।','No hay deudas pendientes.','Aucun impayé.','Bekleyen borç yok.'],
  'Select product.': ['Select product.','توکی وټاکئ.','محصول را انتخاب کنید.','مصنوع منتخب کریں۔','اختر المنتج.','उत्पाद चुनें।','Seleccione producto.','Sélectionnez un produit.','Ürün seçin.'],
  'Product name required.': ['Product name required.','د توکي نوم اړین دی.','نام محصول الزامی است.','مصنوع کا نام ضروری ہے۔','اسم المنتج مطلوب.','उत्पाद नाम आवश्यक है।','El nombre del producto es obligatorio.','Le nom du produit est requis.','Ürün adı gerekli.'],
  'Salesman name required.': ['Salesman name required.','د خرڅوونکي نوم اړین دی.','نام فروشنده الزامی است.','سیلز مین کا نام ضروری ہے۔','اسم مندوب المبيعات مطلوب.','सेल्समैन नाम आवश्यक है।','El nombre del vendedor es obligatorio.','Le nom du vendeur est requis.','Satış elemanı adı gerekli.'],
  'Amount must be greater than zero.': ['Amount must be greater than zero.','اندازه باید له صفر څخه زیاته وي.','مبلغ باید بیشتر از صفر باشد.','رقم صفر سے زیادہ ہونی چاہیے۔','يجب أن يكون المبلغ أكبر من صفر.','राशि शून्य से अधिक होनी चाहिए।','El importe debe ser mayor que cero.','Le montant doit être supérieur à zéro.','Tutar sıfırdan büyük olmalıdır.'],
  'Working… please keep QAMVIO open.': ['Working… please keep QAMVIO open.','کار روان دی… QAMVIO خلاص وساتئ.','در حال کار… QAMVIO را باز نگه دارید.','کام جاری ہے… QAMVIO کھلا رکھیں۔','جارٍ العمل… أبقِ QAMVIO مفتوحًا.','काम जारी है… QAMVIO खुला रखें।','Trabajando… mantenga QAMVIO abierto.','Traitement… gardez QAMVIO ouvert.','Çalışıyor… QAMVIO açık kalsın.'],
  'Cloud & Backup': ['Cloud & Backup','کلاوډ او بیک اپ','ابر و پشتیبان','کلاؤڈ اور بیک اپ','السحابة والنسخ الاحتياطي','क्लाउड और बैकअप','Nube y copia','Cloud et sauvegarde','Bulut ve Yedek'],
  'Backup Now': ['Backup Now','اوس بیک اپ','اکنون پشتیبان‌گیری','ابھی بیک اپ','نسخ احتياطي الآن','अभी बैकअप','Respaldar ahora','Sauvegarder maintenant','Şimdi Yedekle'],
  'Restore Latest Flutter Backup': ['Restore Latest Flutter Backup','وروستی Flutter بیک اپ بېرته راولئ','بازیابی آخرین پشتیبان Flutter','تازہ ترین Flutter بیک اپ ریسٹور کریں','استعادة أحدث نسخة Flutter','नवीनतम Flutter बैकअप पुनर्स्थापित करें','Restaurar última copia Flutter','Restaurer la dernière sauvegarde Flutter','Son Flutter Yedeğini Geri Yükle'],
  'Business Setup': ['Business Setup','د کاروبار تنظیم','تنظیم کسب‌وکار','کاروبار سیٹ اپ','إعداد النشاط','व्यवसाय सेटअप','Configuración del negocio','Configuration de l’entreprise','İşletme Kurulumu'],
  'Choose your business model': ['Choose your business model','د کاروبار ډول وټاکئ','مدل کسب‌وکار را انتخاب کنید','اپنا کاروباری ماڈل منتخب کریں','اختر نموذج نشاطك','अपना व्यवसाय मॉडल चुनें','Elija su modelo de negocio','Choisissez votre modèle d’entreprise','İşletme Modelinizi Seçin'],
  'Business setup requires Admin access': ['Business setup requires Admin access','د کاروبار تنظیم د اډمین لاسرسي ته اړتیا لري','تنظیم کسب‌وکار نیاز به دسترسی ادمین دارد','کاروبار سیٹ اپ کے لیے ایڈمن رسائی ضروری ہے','إعداد النشاط يتطلب صلاحية المدير','व्यवसाय सेटअप के लिए एडमिन एक्सेस चाहिए','La configuración requiere acceso de administrador','La configuration nécessite un accès administrateur','İşletme kurulumu için yönetici erişimi gerekir'],
  'Cloud account': ['Cloud account','کلاوډ حساب','حساب ابری','کلاؤڈ اکاؤنٹ','حساب السحابة','क्लाउड खाता','Cuenta en la nube','Compte cloud','Bulut Hesabı'],
  'Signed-in account': ['Signed-in account','ننوتلی حساب','حساب واردشده','سائن اِن اکاؤنٹ','الحساب المسجل','लॉगिन खाता','Cuenta iniciada','Compte connecté','Giriş Yapılan Hesap'],
  'Create new anyway': ['Create new anyway','بیا هم نوی جوړ کړئ','با این حال جدید بسازید','پھر بھی نیا بنائیں','إنشاء جديد على أي حال','फिर भी नया बनाएँ','Crear nuevo de todos modos','Créer quand même','Yine de Yeni Oluştur'],
  'Already have an account?': ['Already have an account?','حساب لرئ؟','از قبل حساب دارید؟','پہلے سے اکاؤنٹ ہے؟','لديك حساب بالفعل؟','पहले से खाता है?','¿Ya tiene una cuenta?','Vous avez déjà un compte ?','Zaten hesabınız var mı?'],
  'Forgot password? Use recovery code': ['Forgot password? Use recovery code','پاسورډ مو هېر دی؟ د ریکوري کوډ وکاروئ','رمز را فراموش کرده‌اید؟ کد بازیابی را استفاده کنید','پاس ورڈ بھول گئے؟ ریکوری کوڈ استعمال کریں','نسيت كلمة المرور؟ استخدم رمز الاسترداد','पासवर्ड भूल गए? रिकवरी कोड उपयोग करें','¿Olvidó la contraseña? Use el código de recuperación','Mot de passe oublié ? Utilisez le code de récupération','Şifreyi mi unuttunuz? Kurtarma kodunu kullanın'],
  'Save your recovery code': ['Save your recovery code','خپل ریکوري کوډ خوندي کړئ','کد بازیابی خود را ذخیره کنید','اپنا ریکوری کوڈ محفوظ کریں','احفظ رمز الاسترداد','रिकवरी कोड सहेजें','Guarde su código de recuperación','Enregistrez votre code de récupération','Kurtarma Kodunuzu Kaydedin'],
  'Recovery code': ['Recovery code','ریکوري کوډ','کد بازیابی','ریکوری کوڈ','رمز الاسترداد','रिकवरी कोड','Código de recuperación','Code de récupération','Kurtarma Kodu'],
  'New Sale': ['New Sale','نوی خرڅلاو','فروش جدید','نئی فروخت','بيع جديد','नई बिक्री','Nueva venta','Nouvelle vente','Yeni Satış'],
  'Saved Sales': ['Saved Sales','خوندي خرڅلاو','فروش‌های ذخیره‌شده','محفوظ فروخت','المبيعات المحفوظة','सहेजी गई बिक्री','Ventas guardadas','Ventes enregistrées','Kayıtlı Satışlar'],
  'New Purchase': ['New Purchase','نوی پېرود','خرید جدید','نئی خریداری','شراء جديد','नई खरीद','Nueva compra','Nouvel achat','Yeni Satın Alma'],
  'Purchase History': ['Purchase History','د پېرود تاریخچه','تاریخچه خرید','خریداری تاریخچہ','سجل المشتريات','खरीद इतिहास','Historial de compras','Historique des achats','Satın Alma Geçmişi'],
  'Add Medicine': ['Add Medicine','درمل زیاتول','افزودن دوا','دوا شامل کریں','إضافة دواء','दवा जोड़ें','Añadir medicamento','Ajouter un médicament','İlaç Ekle'],
  'Medicine name': ['Medicine name','د درمل نوم','نام دوا','دوا کا نام','اسم الدواء','दवा का नाम','Nombre del medicamento','Nom du médicament','İlaç Adı'],
  'Batch number': ['Batch number','د بچ شمېره','شماره بچ','بیچ نمبر','رقم الدفعة','बैच नंबर','Número de lote','Numéro de lot','Parti Numarası'],
  'Expiry date': ['Expiry date','د ختمېدو نېټه','تاریخ انقضا','میعاد ختم ہونے کی تاریخ','تاريخ الانتهاء','समाप्ति तिथि','Fecha de caducidad','Date d’expiration','Son Kullanma Tarihi'],
  'No products': ['No products','توکي نشته','محصولی نیست','کوئی مصنوعات نہیں','لا توجد منتجات','कोई उत्पाद नहीं','Sin productos','Aucun produit','Ürün yok'],
  'No account available': ['No account available','حساب نشته','حسابی موجود نیست','کوئی اکاؤنٹ دستیاب نہیں','لا يوجد حساب','कोई खाता उपलब्ध नहीं','No hay cuenta disponible','Aucun compte disponible','Kullanılabilir hesap yok'],
};

final Map<AppLanguage, Map<String, String>> _wordMap = {
  AppLanguage.pashto: const {
    'Date':'نېټه','Stock':'سټاک','Reorder':'بیا فرمایش','Balance':'بیلانس','Total':'ټول',
    'Due':'پور','Customer':'پېرودونکی','Supplier':'عرضه کوونکی','Salesman':'خرڅوونکی',
    'Invoice':'انوایس','Opening':'پیل','Current':'اوسنی','Paid':'ورکړل شوي',
    'Received':'ترلاسه شوي','Amount':'اندازه','Note':'یادښت','From':'له','To':'تر',
    'Type':'ډول','Reference':'حواله','Cash':'نغدي','Phone':'تلیفون','Status':'حالت',
    'Product':'توکی','Qty':'مقدار','Cost':'لګښت','Price':'بیه','Discount':'تخفیف',
    'Recovery':'وصول',
  },
  AppLanguage.dari: const {
    'Date':'تاریخ','Stock':'موجودی','Reorder':'سفارش مجدد','Balance':'موجودی','Total':'مجموع',
    'Due':'باقی','Customer':'مشتری','Supplier':'تأمین‌کننده','Salesman':'فروشنده',
    'Invoice':'فاکتور','Opening':'آغازین','Current':'فعلی','Paid':'پرداخت‌شده',
    'Received':'دریافت‌شده','Amount':'مبلغ','Note':'یادداشت','From':'از','To':'تا',
    'Type':'نوع','Reference':'مرجع','Cash':'نقد','Phone':'تلفن','Status':'وضعیت',
    'Product':'محصول','Qty':'تعداد','Cost':'هزینه','Price':'قیمت','Discount':'تخفیف',
    'Recovery':'دریافت',
  },
  AppLanguage.urdu: const {
    'Date':'تاریخ','Stock':'اسٹاک','Reorder':'ری آرڈر','Balance':'بیلنس','Total':'کل',
    'Due':'بقایا','Customer':'گاہک','Supplier':'سپلائر','Salesman':'سیلز مین',
    'Invoice':'انوائس','Opening':'اوپننگ','Current':'موجودہ','Paid':'ادا شدہ',
    'Received':'وصول شدہ','Amount':'رقم','Note':'نوٹ','From':'سے','To':'تک',
    'Type':'قسم','Reference':'حوالہ','Cash':'کیش','Phone':'فون','Status':'حالت',
    'Product':'مصنوع','Qty':'مقدار','Cost':'لاگت','Price':'قیمت','Discount':'ڈسکاؤنٹ',
    'Recovery':'ریکوری',
  },
  AppLanguage.arabic: const {
    'Date':'التاريخ','Stock':'المخزون','Reorder':'إعادة الطلب','Balance':'الرصيد','Total':'الإجمالي',
    'Due':'المستحق','Customer':'العميل','Supplier':'المورد','Salesman':'مندوب المبيعات',
    'Invoice':'الفاتورة','Opening':'الافتتاحي','Current':'الحالي','Paid':'مدفوع',
    'Received':'مستلم','Amount':'المبلغ','Note':'ملاحظة','From':'من','To':'إلى',
    'Type':'النوع','Reference':'المرجع','Cash':'نقد','Phone':'الهاتف','Status':'الحالة',
    'Product':'المنتج','Qty':'الكمية','Cost':'التكلفة','Price':'السعر','Discount':'الخصم',
    'Recovery':'التحصيل',
  },
  AppLanguage.hindi: const {
    'Date':'तारीख','Stock':'स्टॉक','Reorder':'पुनः ऑर्डर','Balance':'शेष','Total':'कुल',
    'Due':'बकाया','Customer':'ग्राहक','Supplier':'आपूर्तिकर्ता','Salesman':'सेल्समैन',
    'Invoice':'चालान','Opening':'प्रारंभिक','Current':'वर्तमान','Paid':'भुगतान',
    'Received':'प्राप्त','Amount':'राशि','Note':'नोट','From':'से','To':'तक',
    'Type':'प्रकार','Reference':'संदर्भ','Cash':'नकद','Phone':'फोन','Status':'स्थिति',
    'Product':'उत्पाद','Qty':'मात्रा','Cost':'लागत','Price':'मूल्य','Discount':'छूट',
    'Recovery':'वसूली',
  },
  AppLanguage.spanish: const {
    'Date':'Fecha','Stock':'Stock','Reorder':'Reposición','Balance':'Saldo','Total':'Total',
    'Due':'Pendiente','Customer':'Cliente','Supplier':'Proveedor','Salesman':'Vendedor',
    'Invoice':'Factura','Opening':'Inicial','Current':'Actual','Paid':'Pagado',
    'Received':'Recibido','Amount':'Importe','Note':'Nota','From':'Desde','To':'Hasta',
    'Type':'Tipo','Reference':'Referencia','Cash':'Caja','Phone':'Teléfono','Status':'Estado',
    'Product':'Producto','Qty':'Cant.','Cost':'Costo','Price':'Precio','Discount':'Descuento',
    'Recovery':'Recuperación',
  },
  AppLanguage.french: const {
    'Date':'Date','Stock':'Stock','Reorder':'Réapprovisionnement','Balance':'Solde','Total':'Total',
    'Due':'Dû','Customer':'Client','Supplier':'Fournisseur','Salesman':'Vendeur',
    'Invoice':'Facture','Opening':'Initial','Current':'Actuel','Paid':'Payé',
    'Received':'Reçu','Amount':'Montant','Note':'Note','From':'De','To':'À',
    'Type':'Type','Reference':'Référence','Cash':'Caisse','Phone':'Téléphone','Status':'Statut',
    'Product':'Produit','Qty':'Qté','Cost':'Coût','Price':'Prix','Discount':'Remise',
    'Recovery':'Recouvrement',
  },
  AppLanguage.turkish: const {
    'Date':'Tarih','Stock':'Stok','Reorder':'Yeniden Sipariş','Balance':'Bakiye','Total':'Toplam',
    'Due':'Borç','Customer':'Müşteri','Supplier':'Tedarikçi','Salesman':'Satış Elemanı',
    'Invoice':'Fatura','Opening':'Açılış','Current':'Güncel','Paid':'Ödendi',
    'Received':'Alındı','Amount':'Tutar','Note':'Not','From':'Başlangıç','To':'Bitiş',
    'Type':'Tür','Reference':'Referans','Cash':'Nakit','Phone':'Telefon','Status':'Durum',
    'Product':'Ürün','Qty':'Miktar','Cost':'Maliyet','Price':'Fiyat','Discount':'İndirim',
    'Recovery':'Tahsilat',
  },
};
