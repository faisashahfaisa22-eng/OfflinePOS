import 'package:flutter/material.dart';

enum AppLanguage { english, pashto, dari, urdu, arabic, hindi, spanish, french, turkish }

class AppStrings {
  final AppLanguage language;
  const AppStrings(this.language);

  bool get rtl => language == AppLanguage.pashto || language == AppLanguage.dari || language == AppLanguage.urdu || language == AppLanguage.arabic;
  TextDirection get direction => rtl ? TextDirection.rtl : TextDirection.ltr;

  static const _v = <String, List<String>>{
    'dashboard': ['Dashboard','ډشبورډ','داشبورد','ڈیش بورڈ','لوحة التحكم','डैशबोर्ड','Panel','Tableau de bord','Kontrol Paneli'],
    'sales': ['Sales','خرڅلاو','فروشات','فروخت','المبيعات','बिक्री','Ventas','Ventes','Satış'],
    'stock': ['Stock','سټاک','موجودی','اسٹاک','المخزون','स्टॉक','Stock','Stock','Stok'],
    'invoice': ['Invoice','انوایس','فاکتور','انوائس','فاتورة','चालान','Factura','Facture','Fatura'],
    'customer': ['Customer','مشتري','مشتری','گاہک','عميل','ग्राहक','Cliente','Client','Müşteri'],
    'supplier': ['Supplier','عرضه کوونکی','تأمین‌کننده','سپلائر','مورد','आपूर्तिकर्ता','Proveedor','Fournisseur','Tedarikçi'],
    'products': ['Products','جنسونه','اجناس','مصنوعات','المنتجات','उत्पाद','Productos','Produits','Ürünler'],
    'purchase': ['Purchase','پېرود','خرید','خریداری','المشتريات','खरीद','Compra','Achat','Satın Alma'],
    'payment': ['Payment','ادایګي','پرداخت','ادائیگی','الدفع','भुगतान','Pago','Paiement','Ödeme'],
    'language': ['Language','ژبه','زبان','زبان','اللغة','भाषा','Idioma','Langue','Dil'],
    'save': ['Save','ثبت','ذخیره','محفوظ کریں','حفظ','सहेजें','Guardar','Enregistrer','Kaydet'],
    'cancel': ['Cancel','لغوه','لغو','منسوخ','إلغاء','रद्द करें','Cancelar','Annuler','İptal'],
  };

  String t(String key) => (_v[key] ?? [key,key,key,key,key,key,key,key,key])[language.index];
}
