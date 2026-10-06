import 'package:flutter/material.dart';

enum AppLanguage { english, pashto, dari, urdu }

class AppStrings {
  final AppLanguage language;
  const AppStrings(this.language);

  bool get rtl => language != AppLanguage.english;
  TextDirection get direction => rtl ? TextDirection.rtl : TextDirection.ltr;

  static const _v = <String, List<String>>{
    'dashboard': ['Dashboard','ډشبورډ','داشبورد','ڈیش بورڈ'],
    'businessDashboard': ['Business Dashboard','د کاروبار ډشبورډ','داشبورد تجارت','کاروباری ڈیش بورڈ'],
    'offlineFirst': ['Native Flutter • SQLite offline-first','اصلي Flutter • SQLite افلاین-لومړی','Flutter اصلی • SQLite آفلاین-اول','نیٹو Flutter • SQLite آف لائن فرسٹ'],
    'sales': ['Sales','خرڅلاو','فروشات','فروخت'],
    'expenses': ['Expenses','مصارف','مصارف','اخراجات'],
    'products': ['Products','جنسونه','اجناس','مصنوعات'],
    'customers': ['Customers','مشتریان','مشتریان','گاہک'],
    'suppliers': ['Suppliers','عرضه کوونکي','تأمین‌کنندگان','سپلائرز'],
    'due': ['Due','باقي','باقی','بقایا'],
    'inventory': ['Products & Inventory','جنسونه او سټاک','اجناس و موجودی','مصنوعات اور اسٹاک'],
    'salesInvoice': ['Sales & Invoices','خرڅلاو او انوایس','فروشات و فاکتورها','فروخت اور انوائس'],
    'addProduct': ['Add Product','جنس اضافه کړئ','افزودن جنس','مصنوع شامل کریں'],
    'productName': ['Product name','د جنس نوم','نام جنس','مصنوع کا نام'],
    'salePrice': ['Sale price','د خرڅ بیه','قیمت فروش','فروخت قیمت'],
    'openingStock': ['Opening stock','لومړنی سټاک','موجودی ابتدایی','ابتدائی اسٹاک'],
    'save': ['Save','ثبت','ذخیره','محفوظ کریں'],
    'cancel': ['Cancel','لغوه','لغو','منسوخ'],
    'noProducts': ['No products yet. Add your first product.','تر اوسه جنس نشته. لومړی جنس اضافه کړئ.','هنوز جنسی نیست. اولین جنس را اضافه کنید.','ابھی کوئی مصنوع نہیں۔ پہلی مصنوع شامل کریں۔'],
    'stock': ['Stock','سټاک','موجودی','اسٹاک'],
    'newInvoice': ['New Invoice','نوی انوایس','فاکتور جدید','نیا انوائس'],
    'newSalesInvoice': ['New Sales Invoice','نوی د خرڅلاو انوایس','فاکتور فروش جدید','نیا سیلز انوائس'],
    'addItemsHint': ['Add items — invoice table will appear here.','جنسونه اضافه کړئ — د انوایس جدول به دلته ښکاره شي.','اجناس را اضافه کنید — جدول فاکتور اینجا ظاهر می‌شود.','اشیاء شامل کریں — انوائس جدول یہاں ظاہر ہوگا۔'],
    'product': ['Product','جنس','جنس','مصنوع'],
    'qty': ['Qty','تعداد','تعداد','تعداد'],
    'price': ['Price','بیه','قیمت','قیمت'],
    'total': ['Total','ټول','مجموع','کل'],
    'discount': ['Discount','تخفیف','تخفیف','رعایت'],
    'paid': ['Paid','ورکړل شوي','پرداخت‌شده','ادا شدہ'],
    'noSales': ['No sales yet.','تر اوسه خرڅلاو نشته.','هنوز فروشی نیست.','ابھی کوئی فروخت نہیں۔'],
    'addCustomer': ['Add Customer','مشتري اضافه کړئ','افزودن مشتری','گاہک شامل کریں'],
    'addSupplier': ['Add Supplier','عرضه کوونکی اضافه کړئ','افزودن تأمین‌کننده','سپلائر شامل کریں'],
    'name': ['Name','نوم','نام','نام'],
    'phone': ['Phone','موبایل','تلفن','فون'],
    'address': ['Address','پته','آدرس','پتہ'],
    'noCustomers': ['No customers yet.','تر اوسه مشتری نشته.','هنوز مشتری نیست.','ابھی کوئی گاہک نہیں۔'],
    'noSuppliers': ['No suppliers yet.','تر اوسه عرضه کوونکی نشته.','هنوز تأمین‌کننده نیست.','ابھی کوئی سپلائر نہیں۔'],
    'balance': ['Balance','بیلانس','بیلانس','بیلنس'],
    'addExpense': ['Add Expense','مصرف اضافه کړئ','افزودن مصرف','خرچ شامل کریں'],
    'expenseName': ['Expense Name','د مصرف نوم','نام مصرف','خرچ کا نام'],
    'category': ['Category','کټګوري','دسته‌بندی','کیٹیگری'],
    'amount': ['Amount','مبلغ','مبلغ','رقم'],
    'note': ['Note','یادښت','یادداشت','نوٹ'],
    'noExpenses': ['No expenses yet.','تر اوسه مصرف نشته.','هنوز مصرفی نیست.','ابھی کوئی خرچ نہیں۔'],
    'oil': ['Oil / Fuel Pump','د تیلو پمپ','پمپ تیل','آئل / فیول پمپ'],
    'pharmacy': ['Pharmacy','درملتون','داروخانه','فارمیسی'],
    'reports': ['Reports','راپورونه','گزارش‌ها','رپورٹس'],
    'cloud': ['Cloud & Backup','کلاوډ او بیک اپ','کلاود و پشتیبان','کلاؤڈ اور بیک اپ'],
    'language': ['Language','ژبه','زبان','زبان'],
    'sarafi': ['Sarafi / Hawala','صرافي / حواله','صرافی / حواله','صرافی / حوالہ'],
  };

  String t(String key) {
    final values = _v[key] ?? <String>[key,key,key,key];
    return values[language.index];
  }
}
