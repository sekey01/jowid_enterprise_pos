import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../provider/functions.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({Key? key}) : super(key: key);

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  late final DatabaseHelper _databaseHelper;
  final TextEditingController _searchController = TextEditingController();

  List<Customer> _customers = [];
  List<Customer> _filteredCustomers = [];
  List<ProductReturn> _returns = [];

  Map<int, double> _customerPurchases = {};
  Map<int, double> _customerReturns = {};
  Map<int, double> _customerNetPurchases = {};
  Map<int, int> _customerTransactionCount = {};
  Map<int, int> _customerReturnsCount = {};
  Map<int, DateTime?> _customerLastPurchase = {};
  Map<int, DateTime?> _customerLastReturn = {};

  bool _isLoading = true;
  String _searchQuery = '';
  String _sortBy = 'name'; // name, purchases, recent
  String _selectedCurrency = 'GHS';

  @override
  void initState() {
    super.initState();
    _databaseHelper = DatabaseHelper();
    _loadBusinessSettings();
    _loadCustomers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBusinessSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _selectedCurrency = prefs.getString('currency') ?? 'GHS';
      });
    } catch (e) {
      setState(() {
        _selectedCurrency = 'GHS';
      });
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterCustomers();
    });
  }

  void _filterCustomers() {
    if (_searchQuery.isEmpty) {
      _filteredCustomers = List.from(_customers);
    } else {
      _filteredCustomers = _customers.where((customer) {
        return customer.name.toLowerCase().contains(_searchQuery) ||
            (customer.email?.toLowerCase().contains(_searchQuery) ?? false) ||
            (customer.phone?.toLowerCase().contains(_searchQuery) ?? false);
      }).toList();
    }
    _sortCustomers();
  }

  void _sortCustomers() {
    switch (_sortBy) {
      case 'purchases':
        _filteredCustomers.sort((a, b) {
          final aNetPurchases = _customerNetPurchases[a.id] ?? 0.0;
          final bNetPurchases = _customerNetPurchases[b.id] ?? 0.0;
          return bNetPurchases.compareTo(aNetPurchases);
        });
        break;
      case 'recent':
        _filteredCustomers.sort((a, b) {
          final aDate = _customerLastPurchase[a.id] ?? DateTime(1900);
          final bDate = _customerLastPurchase[b.id] ?? DateTime(1900);
          return bDate.compareTo(aDate);
        });
        break;
      default: // name
        _filteredCustomers.sort((a, b) => a.name.compareTo(b.name));
    }
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final customers = await _databaseHelper.getAllCustomers();
      final sales = await _databaseHelper.getAllSales();
      final returns = await _databaseHelper.getAllReturns();

      final Map<int, double> purchases = {};
      final Map<int, double> customerReturns = {};
      final Map<int, double> netPurchases = {};
      final Map<int, int> transactionCount = {};
      final Map<int, int> returnsCount = {};
      final Map<int, DateTime?> lastPurchase = {};
      final Map<int, DateTime?> lastReturn = {};

      // Get purchase data for each customer
      for (Customer customer in customers) {
        if (customer.id != null) {
          final customerSales = sales.where((sale) => sale.customerId == customer.id).toList();

          // Calculate customer returns by finding sales that belong to this customer
          final customerReturnsList = returns.where((returnItem) {
            final relatedSale = sales.firstWhere(
                  (sale) => sale.id == returnItem.saleId,
              orElse: () => Sale(totalAmount: 0, saleDate: DateTime.now(), paymentMethod: ''),
            );
            return relatedSale.customerId == customer.id;
          }).toList();

          double totalPurchases = 0.0;
          double totalReturns = 0.0;
          int totalTransactions = customerSales.length;
          int totalReturnsCount = customerReturnsList.length;
          DateTime? lastPurchaseDate;
          DateTime? lastReturnDate;

          // Calculate purchases
          for (Sale sale in customerSales) {
            totalPurchases += sale.totalAmount;
            if (lastPurchaseDate == null || sale.saleDate.isAfter(lastPurchaseDate)) {
              lastPurchaseDate = sale.saleDate;
            }
          }

          // Calculate returns
          for (ProductReturn returnItem in customerReturnsList) {
            totalReturns += returnItem.totalAmount;
            if (lastReturnDate == null || returnItem.returnDate.isAfter(lastReturnDate)) {
              lastReturnDate = returnItem.returnDate;
            }
          }

          purchases[customer.id!] = totalPurchases;
          customerReturns[customer.id!] = totalReturns;
          netPurchases[customer.id!] = totalPurchases - totalReturns;
          transactionCount[customer.id!] = totalTransactions;
          returnsCount[customer.id!] = totalReturnsCount;
          lastPurchase[customer.id!] = lastPurchaseDate;
          lastReturn[customer.id!] = lastReturnDate;
        }
      }

      setState(() {
        _customers = customers;
        _returns = returns;
        _customerPurchases = purchases;
        _customerReturns = customerReturns;
        _customerNetPurchases = netPurchases;
        _customerTransactionCount = transactionCount;
        _customerReturnsCount = returnsCount;
        _customerLastPurchase = lastPurchase;
        _customerLastReturn = lastReturn;
        _filteredCustomers = List.from(customers);
        _isLoading = false;
      });
      _sortCustomers();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load customers');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _deleteCustomer(Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade600),
            const SizedBox(width: 8),
            const Text('Delete Customer'),
          ],
        ),
        content: Text('Are you sure you want to delete ${customer.name}?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && customer.id != null) {
      try {
        await _databaseHelper.deleteCustomer(customer.id!);
        _showSuccessSnackBar('Customer deleted successfully');
        _loadCustomers();
      } catch (e) {
        _showErrorSnackBar('Failed to delete customer');
      }
    }
  }

  Future<void> _generateCustomerReceipt(Customer customer) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Generating receipt...'),
            ],
          ),
        ),
      );

      // Get customer's sales and returns data
      final sales = await _databaseHelper.getAllSales();
      final customerSales = sales.where((sale) => sale.customerId == customer.id).toList();

      // Get returns for this customer
      final customerReturns = _returns.where((returnItem) {
        final relatedSale = sales.firstWhere(
              (sale) => sale.id == returnItem.saleId,
          orElse: () => Sale(totalAmount: 0, saleDate: DateTime.now(), paymentMethod: ''),
        );
        return relatedSale.customerId == customer.id;
      }).toList();

      // Sort by date (most recent first)
      customerSales.sort((a, b) => b.saleDate.compareTo(a.saleDate));
      customerReturns.sort((a, b) => b.returnDate.compareTo(a.returnDate));

      Navigator.of(context).pop(); // Close loading dialog

      if (customerSales.isEmpty) {
        _showErrorSnackBar('No purchase history found for this customer');
        return;
      }

      // Generate PDF
      final pdf = await _createCustomerReceiptPDF(customer, customerSales, customerReturns);

      // Show print/download options
      await _showReceiptOptions(customer, pdf);

    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog if still open
      _showErrorSnackBar('Failed to generate receipt: ${e.toString()}');
    }
  }

  Future<pw.Document> _createCustomerReceiptPDF(Customer customer, List<Sale> sales, List<ProductReturn> returns) async {
    final pdf = pw.Document();

    final totalPurchases = _customerPurchases[customer.id] ?? 0.0;
    final totalReturns = _customerReturns[customer.id] ?? 0.0;
    final netPurchases = _customerNetPurchases[customer.id] ?? 0.0;
    final transactionCount = _customerTransactionCount[customer.id] ?? 0;
    final returnsCount = _customerReturnsCount[customer.id] ?? 0;

    // Get sale items for each sale if available
    Map<int, List<SaleItem>> saleItemsMap = {};
    for (Sale sale in sales) {
      if (sale.id != null) {
        try {
          final saleItems = await _databaseHelper.getSaleItems(sale.id!);
          saleItemsMap[sale.id!] = saleItems;
        } catch (e) {
          saleItemsMap[sale.id!] = [];
        }
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 20),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 2)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CUSTOMER PURCHASE SUMMARY',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Generated on ${DateFormat('MMMM dd, yyyy \'at\' hh:mm a').format(DateTime.now())}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 24),

          // Customer Information
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CUSTOMER INFORMATION',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Name: ${customer.name}', style: const pw.TextStyle(fontSize: 12)),
                          if (customer.phone != null)
                            pw.Text('Phone: ${customer.phone}', style: const pw.TextStyle(fontSize: 12)),
                          if (customer.email != null)
                            pw.Text('Email: ${customer.email}', style: const pw.TextStyle(fontSize: 12)),
                          if (customer.address != null)
                            pw.Text('Address: ${customer.address}', style: const pw.TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Customer Since: ${DateFormat('MMM dd, yyyy').format(customer.createdAt)}',
                              style: const pw.TextStyle(fontSize: 12)),
                          pw.Text('Customer Type: ${_getCustomerType(netPurchases)}',
                              style: const pw.TextStyle(fontSize: 12)),
                          pw.Text('Total Transactions: $transactionCount',
                              style: const pw.TextStyle(fontSize: 12)),
                          if (returnsCount > 0)
                            pw.Text('Total Returns: $returnsCount',
                                style: pw.TextStyle(fontSize: 12, color: PdfColors.red800)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 24),

          // Financial Summary
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: returnsCount > 0 ? PdfColors.orange50 : PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: returnsCount > 0 ? PdfColors.orange200 : PdfColors.blue200),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'FINANCIAL SUMMARY',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Gross Purchases: ${_formatCurrency(totalPurchases)}',
                              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          if (returnsCount > 0)
                            pw.Text('Less Returns: -${_formatCurrency(totalReturns)}',
                                style: pw.TextStyle(fontSize: 12, color: PdfColors.red800)),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('NET AMOUNT SPENT',
                              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                          pw.Text(
                            _formatCurrency(netPurchases),
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: returnsCount > 0 ? PdfColors.orange800 : PdfColors.blue800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 24),

          // Purchase History Header
          pw.Text(
            'PURCHASE HISTORY',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(height: 12),

          // Table Header
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey200,
            ),
            child: pw.Row(
              children: [
                pw.Expanded(flex: 2, child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                pw.Expanded(flex: 2, child: pw.Text('Sale ID', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                pw.Expanded(flex: 3, child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                pw.Expanded(flex: 1, child: pw.Text('Items', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                pw.Expanded(flex: 2, child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
              ],
            ),
          ),

          // Sales Data
          ...sales.map((sale) {
            final saleItems = saleItemsMap[sale.id] ?? [];
            final itemCount = saleItems.length;
            final totalQuantity = saleItems.fold(0, (sum, item) => sum + item.quantity);

            return pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(flex: 2, child: pw.Text(DateFormat('MMM dd, yyyy').format(sale.saleDate), style: const pw.TextStyle(fontSize: 9))),
                  pw.Expanded(flex: 2, child: pw.Text('#${sale.id ?? 'N/A'}', style: const pw.TextStyle(fontSize: 9))),
                  pw.Expanded(flex: 3, child: pw.Text(
                      itemCount > 0 ? '$itemCount products (Qty: $totalQuantity)' : 'Sale transaction',
                      style: const pw.TextStyle(fontSize: 9)
                  )),
                  pw.Expanded(flex: 1, child: pw.Text('$itemCount', style: const pw.TextStyle(fontSize: 9))),
                  pw.Expanded(flex: 2, child: pw.Text(_formatCurrency(sale.totalAmount), style: const pw.TextStyle(fontSize: 9))),
                ],
              ),
            );
          }).toList(),

          // Returns Section (if any)
          if (returns.isNotEmpty) ...[
            pw.SizedBox(height: 24),
            pw.Text(
              'RETURNS HISTORY',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.red800,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.red50,
                border: pw.Border.all(color: PdfColors.red200),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(flex: 2, child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Expanded(flex: 2, child: pw.Text('Sale ID', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Expanded(flex: 3, child: pw.Text('Reason', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Expanded(flex: 1, child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Expanded(flex: 2, child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                ],
              ),
            ),
            ...returns.map((returnItem) => pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.red300)),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(flex: 2, child: pw.Text(DateFormat('MMM dd, yyyy').format(returnItem.returnDate), style: const pw.TextStyle(fontSize: 9))),
                  pw.Expanded(flex: 2, child: pw.Text('#${returnItem.saleId}', style: const pw.TextStyle(fontSize: 9))),
                  pw.Expanded(flex: 3, child: pw.Text(returnItem.reason, style: const pw.TextStyle(fontSize: 9))),
                  pw.Expanded(flex: 1, child: pw.Text('${returnItem.quantity}', style: const pw.TextStyle(fontSize: 9))),
                  pw.Expanded(flex: 2, child: pw.Text('-${_formatCurrency(returnItem.totalAmount)}', style: pw.TextStyle(fontSize: 9, color: PdfColors.red800))),
                ],
              ),
            )).toList(),
          ],

          pw.SizedBox(height: 32),

          // Footer
          pw.Center(
            child: pw.Text(
              returnsCount > 0
                  ? 'Thank you for your business! We appreciate your continued patronage.'
                  : 'Thank you for your business!',
              style: pw.TextStyle(
                fontSize: 12,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.grey600,
              ),
            ),
          ),
        ],
      ),
    );

    return pdf;
  }

  Future<void> _showReceiptOptions(Customer customer, pw.Document pdf) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.receipt_long, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Text('Receipt for ${customer.name}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose how you want to handle the receipt:',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _printReceipt(pdf);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.print),
                    label: const Text('Print'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _downloadReceipt(customer, pdf);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.download),
                    label: const Text('Download'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _printReceipt(pw.Document pdf) async {
    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Customer_Receipt_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      _showErrorSnackBar('Failed to print receipt: ${e.toString()}');
    }
  }

  Future<void> _downloadReceipt(Customer customer, pw.Document pdf) async {
    try {
      final bytes = await pdf.save();
      final fileName = 'Receipt_${customer.name.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

      await Printing.sharePdf(
        bytes: bytes,
        filename: fileName,
      );

      _showSuccessSnackBar('Receipt ready for download');
    } catch (e) {
      _showErrorSnackBar('Failed to download receipt: ${e.toString()}');
    }
  }

  void _showAddCustomerDialog({Customer? customer}) {
    final nameController = TextEditingController(text: customer?.name ?? '');
    final phoneController = TextEditingController(text: customer?.phone ?? '');
    final emailController = TextEditingController(text: customer?.email ?? '');
    final addressController = TextEditingController(text: customer?.address ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              customer == null ? Icons.person_add : Icons.person_outline,
              color: Colors.blue.shade700,
            ),
            const SizedBox(width: 8),
            Text(
              customer == null ? 'Add New Customer' : 'Edit Customer',
              style: TextStyle(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField(
                    controller: nameController,
                    label: 'Full Name',
                    icon: Icons.person_outline,
                    required: true,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: emailController,
                    label: 'Email Address',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(value)) {
                          return 'Enter a valid email address';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: addressController,
                    label: 'Address',
                    icon: Icons.location_on_outlined,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  final newCustomer = Customer(
                    id: customer?.id,
                    name: nameController.text.trim(),
                    phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                    email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                    address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                    createdAt: customer?.createdAt ?? DateTime.now(),
                  );

                  if (customer == null) {
                    await _databaseHelper.insertCustomer(newCustomer);
                    _showSuccessSnackBar('Customer added successfully');
                  } else {
                    await _databaseHelper.updateCustomer(newCustomer);
                    _showSuccessSnackBar('Customer updated successfully');
                  }

                  Navigator.of(context).pop();
                  _loadCustomers();
                } catch (e) {
                  _showErrorSnackBar('Failed to save customer');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(customer == null ? 'Add Customer' : 'Update Customer'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        prefixIcon: Icon(icon, color: Colors.grey.shade600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
    );
  }

  String _formatCurrency(double amount) {
    String symbol = '₵'; // Default to Ghanaian Cedi
    switch (_selectedCurrency) {
      case 'USD':
        symbol = '\$';
        break;
      case 'EUR':
        symbol = '€';
        break;
      case 'GBP':
        symbol = '£';
        break;
      case 'GHS':
      default:
        symbol = '₵';
        break;
    }
    return NumberFormat.currency(symbol: symbol, decimalDigits: 2).format(amount);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Never';
    return DateFormat('MMM dd, yyyy').format(date);
  }

  Color _getCustomerTypeColor(double netPurchases) {
    if (netPurchases >= 1000) return Colors.purple.shade700;
    if (netPurchases >= 500) return Colors.orange.shade700;
    if (netPurchases >= 100) return Colors.green.shade700;
    return Colors.blue.shade700;
  }

  String _getCustomerType(double netPurchases) {
    if (netPurchases >= 1000) return 'VIP';
    if (netPurchases >= 500) return 'Premium';
    if (netPurchases >= 100) return 'Regular';
    return 'New';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Customer Management',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey.shade800,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.shade300,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            onSelected: (value) {
              setState(() {
                _sortBy = value;
                _sortCustomers();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha, size: 18),
                    SizedBox(width: 8),
                    Text('Sort by Name'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'purchases',
                child: Row(
                  children: [
                    Icon(Icons.monetization_on, size: 18),
                    SizedBox(width: 8),
                    Text('Sort by Net Purchases'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'recent',
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 18),
                    SizedBox(width: 8),
                    Text('Sort by Recent'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () async {
              await _loadBusinessSettings();
              _loadCustomers();
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search Bar & Stats
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search customers by name, email, or phone...',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      onPressed: () => _searchController.clear(),
                      icon: Icon(Icons.clear, color: Colors.grey.shade600),
                    )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
                // Stats Row
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Customers',
                        '${_customers.length}',
                        Icons.people,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Active Customers',
                        '${_customers.where((c) => (_customerNetPurchases[c.id] ?? 0) > 0).length}',
                        Icons.person,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Net Revenue',
                        _formatCurrency(_customerNetPurchases.values.fold(0.0, (a, b) => a + b)),
                        Icons.trending_up,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Customers w/ Returns',
                        '${_customers.where((c) => (_customerReturnsCount[c.id] ?? 0) > 0).length}',
                        Icons.keyboard_return,
                        Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Customer List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCustomers.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty
                        ? 'No customers yet'
                        : 'No customers match your search',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _searchQuery.isEmpty
                        ? 'Add your first customer to get started'
                        : 'Try adjusting your search terms',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _filteredCustomers.length,
              itemBuilder: (context, index) {
                final customer = _filteredCustomers[index];
                final totalPurchases = _customerPurchases[customer.id] ?? 0.0;
                final totalReturns = _customerReturns[customer.id] ?? 0.0;
                final netPurchases = _customerNetPurchases[customer.id] ?? 0.0;
                final transactionCount = _customerTransactionCount[customer.id] ?? 0;
                final returnsCount = _customerReturnsCount[customer.id] ?? 0;
                final lastPurchase = _customerLastPurchase[customer.id];
                final lastReturn = _customerLastReturn[customer.id];
                final hasReturns = returnsCount > 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: hasReturns ? Border.all(color: Colors.orange.shade200, width: 1.5) : null,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(20),
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: _getCustomerTypeColor(netPurchases).withOpacity(0.1),
                          child: Text(
                            customer.name.isNotEmpty
                                ? customer.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: _getCustomerTypeColor(netPurchases),
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getCustomerTypeColor(netPurchases),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _getCustomerType(netPurchases),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        if (hasReturns)
                          Positioned(
                            top: -2,
                            left: -2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade600,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.keyboard_return,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Row(
                      children: [
                        Text(
                          customer.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        if (hasReturns) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'HAS RETURNS',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        if (customer.phone != null || customer.email != null) ...[
                          Row(
                            children: [
                              if (customer.phone != null) ...[
                                Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  customer.phone!,
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                ),
                              ],
                              if (customer.phone != null && customer.email != null)
                                Text(' • ', style: TextStyle(color: Colors.grey.shade500)),
                              if (customer.email != null) ...[
                                Icon(Icons.email, size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    customer.email!,
                                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (customer.address != null) ...[
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  customer.address!,
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        // Purchase Info
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: hasReturns ? Colors.orange.shade50 : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: hasReturns ? Border.all(color: Colors.orange.shade200) : null,
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Gross Purchases',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          _formatCurrency(totalPurchases),
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (hasReturns)
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Returns',
                                            style: TextStyle(
                                              color: Colors.orange.shade700,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            '-${_formatCurrency(totalReturns)}',
                                            style: TextStyle(
                                              color: Colors.orange.shade700,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          hasReturns ? 'Net Purchases' : 'Transactions',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          hasReturns ? _formatCurrency(netPurchases) : '$transactionCount',
                                          style: TextStyle(
                                            color: hasReturns ? _getCustomerTypeColor(netPurchases) : Colors.black87,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (hasReturns) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Transactions',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            '$transactionCount',
                                            style: const TextStyle(
                                              color: Colors.black87,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Returns Count',
                                            style: TextStyle(
                                              color: Colors.orange.shade700,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            '$returnsCount',
                                            style: TextStyle(
                                              color: Colors.orange.shade700,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Last Return',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            _formatDate(lastReturn),
                                            style: const TextStyle(
                                              color: Colors.black87,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Last Purchase',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            _formatDate(lastPurchase),
                                            style: const TextStyle(
                                              color: Colors.black87,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Receipt Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: transactionCount > 0
                                ? () => _generateCustomerReceipt(customer)
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: transactionCount > 0
                                  ? (hasReturns ? Colors.orange.shade600 : Colors.indigo.shade600)
                                  : Colors.grey.shade300,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: Icon(
                              hasReturns ? Icons.receipt_long_outlined : Icons.receipt_long,
                              size: 18,
                              color: transactionCount > 0 ? Colors.white : Colors.grey.shade500,
                            ),
                            label: Text(
                              transactionCount > 0
                                  ? (hasReturns ? 'Generate Receipt (w/ Returns)' : 'Generate Receipt')
                                  : 'No Purchase History',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: transactionCount > 0 ? Colors.white : Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _showAddCustomerDialog(customer: customer);
                            break;
                          case 'delete':
                            _deleteCustomer(customer);
                            break;
                          case 'call':
                            if (customer.phone != null) {
                              Clipboard.setData(ClipboardData(text: customer.phone!));
                              _showSuccessSnackBar('Phone number copied to clipboard');
                            }
                            break;
                          case 'receipt':
                            if (transactionCount > 0) {
                              _generateCustomerReceipt(customer);
                            }
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('Edit Customer'),
                            ],
                          ),
                        ),
                        if (transactionCount > 0)
                          PopupMenuItem(
                            value: 'receipt',
                            child: Row(
                              children: [
                                Icon(hasReturns ? Icons.receipt_long_outlined : Icons.receipt_long, size: 18),
                                const SizedBox(width: 8),
                                Text(hasReturns ? 'Generate Receipt (w/ Returns)' : 'Generate Receipt'),
                              ],
                            ),
                          ),
                        if (customer.phone != null)
                          const PopupMenuItem(
                            value: 'call',
                            child: Row(
                              children: [
                                Icon(Icons.phone, size: 18),
                                SizedBox(width: 8),
                                Text('Copy Phone'),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete Customer', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCustomerDialog(),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text(
          'Add Customer',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}