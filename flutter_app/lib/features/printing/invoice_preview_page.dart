import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/repositories/business_repository.dart';

class InvoicePreviewPage extends StatelessWidget {
 const InvoicePreviewPage({super.key});

 Future<void> printSample() async {
  final settings=await BusinessRepository().settings();
  final doc=pw.Document();
  doc.addPage(pw.Page(pageFormat:PdfPageFormat.a4,build:(context)=>pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
   pw.Text(settings['business_name'] as String? ?? 'QAMVIO POS',style:pw.TextStyle(fontSize:22,fontWeight:pw.FontWeight.bold)),
   pw.Text(settings['address'] as String? ?? ''),
   pw.SizedBox(height:20),
   pw.Text('INVOICE',style:pw.TextStyle(fontSize:18,fontWeight:pw.FontWeight.bold)),
   pw.SizedBox(height:10),
   pw.Table.fromTextArray(headers:['Product','Qty','Price','Total'],data:[['Add Product','—','—','—']]),
   pw.SizedBox(height:14),
   pw.Align(alignment:pw.Alignment.centerRight,child:pw.Text('Grand Total: 0.00')),
   pw.Spacer(),
   pw.Text(settings['invoice_footer'] as String? ?? ''),
  ])));
  await Printing.layoutPdf(onLayout:(_)=>doc.save());
 }

 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Invoice / Printing')),body:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
  Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[
   const Text('QAMVIO POS',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),const Divider(),
   Table(border:TableBorder.all(),children:const [
    TableRow(children:[Padding(padding:EdgeInsets.all(8),child:Text('Product')),Padding(padding:EdgeInsets.all(8),child:Text('Qty')),Padding(padding:EdgeInsets.all(8),child:Text('Price')),Padding(padding:EdgeInsets.all(8),child:Text('Total'))]),
    TableRow(children:[Padding(padding:EdgeInsets.all(8),child:Text('Add Product')),Padding(padding:EdgeInsets.all(8),child:Text('—')),Padding(padding:EdgeInsets.all(8),child:Text('—')),Padding(padding:EdgeInsets.all(8),child:Text('—'))]),
   ]),
  ]))),
  FilledButton.icon(onPressed:printSample,icon:const Icon(Icons.print),label:const Text('Print / Save PDF')),
 ])));
}
