import 'package:flutter/material.dart';

enum AppLang { en, ps, fa, ur }

class AppLanguageController extends ChangeNotifier {
  AppLanguageController._();
  static final instance = AppLanguageController._();

  AppLang _language = AppLang.en;
  AppLang get language => _language;

  TextDirection get direction =>
      _language == AppLang.en ? TextDirection.ltr : TextDirection.rtl;

  void setLanguage(AppLang value) {
    if (_language == value) return;
    _language = value;
    notifyListeners();
  }

  String tr(String key) => _strings[key]?[_language] ?? _strings[key]?[AppLang.en] ?? key;
}

const Map<String, Map<AppLang, String>> _strings = {
  'app_title': {AppLang.en:'QAMVIO POS', AppLang.ps:'QAMVIO POS', AppLang.fa:'QAMVIO POS', AppLang.ur:'QAMVIO POS'},
  'dashboard': {AppLang.en:'Dashboard', AppLang.ps:'ډشبورډ', AppLang.fa:'داشبورد', AppLang.ur:'ڈیش بورڈ'},
  'sales_invoice': {AppLang.en:'Sales & Invoice', AppLang.ps:'خرڅلاو او انوایس', AppLang.fa:'فروش و فاکتور', AppLang.ur:'فروخت اور انوائس'},
  'products_inventory': {AppLang.en:'Products & Inventory', AppLang.ps:'اجناس او سټاک', AppLang.fa:'محصولات و موجودی', AppLang.ur:'مصنوعات اور اسٹاک'},
  'purchases': {AppLang.en:'Purchases', AppLang.ps:'پېرود', AppLang.fa:'خریدها', AppLang.ur:'خریداری'},
  'customers': {AppLang.en:'Customers', AppLang.ps:'مشتریان', AppLang.fa:'مشتریان', AppLang.ur:'گاہک'},
  'suppliers': {AppLang.en:'Suppliers', AppLang.ps:'عرضه کوونکي', AppLang.fa:'تأمین‌کنندگان', AppLang.ur:'سپلائرز'},
  'expenses_accounts': {AppLang.en:'Expenses & Accounts', AppLang.ps:'مصارف او حسابونه', AppLang.fa:'مصارف و حساب‌ها', AppLang.ur:'اخراجات اور اکاؤنٹس'},
  'oil_fuel': {AppLang.en:'Oil / Fuel Pump', AppLang.ps:'د تېلو پمپ', AppLang.fa:'پمپ تیل', AppLang.ur:'فیول پمپ'},
  'pharmacy': {AppLang.en:'Pharmacy', AppLang.ps:'درملتون', AppLang.fa:'داروخانه', AppLang.ur:'فارمیسی'},
  'reports': {AppLang.en:'Reports', AppLang.ps:'راپورونه', AppLang.fa:'گزارش‌ها', AppLang.ur:'رپورٹس'},
  'settings': {AppLang.en:'Business Settings', AppLang.ps:'د کاروبار تنظیمات', AppLang.fa:'تنظیمات کسب‌وکار', AppLang.ur:'کاروباری ترتیبات'},
  'sales': {AppLang.en:'Sales', AppLang.ps:'خرڅلاو', AppLang.fa:'فروش', AppLang.ur:'فروخت'},
  'products': {AppLang.en:'Products', AppLang.ps:'اجناس', AppLang.fa:'محصولات', AppLang.ur:'مصنوعات'},
  'revenue': {AppLang.en:'Revenue', AppLang.ps:'عواید', AppLang.fa:'درآمد', AppLang.ur:'آمدنی'},
  'expenses': {AppLang.en:'Expenses', AppLang.ps:'مصارف', AppLang.fa:'مصارف', AppLang.ur:'اخراجات'},
  'language': {AppLang.en:'Language', AppLang.ps:'ژبه', AppLang.fa:'زبان', AppLang.ur:'زبان'},
  'english': {AppLang.en:'English', AppLang.ps:'English', AppLang.fa:'English', AppLang.ur:'English'},
  'pashto': {AppLang.en:'Pashto', AppLang.ps:'پښتو', AppLang.fa:'پشتو', AppLang.ur:'پشتو'},
  'dari': {AppLang.en:'Dari', AppLang.ps:'دري', AppLang.fa:'دری', AppLang.ur:'دری'},
  'urdu': {AppLang.en:'Urdu', AppLang.ps:'اردو', AppLang.fa:'اردو', AppLang.ur:'اردو'},
};
