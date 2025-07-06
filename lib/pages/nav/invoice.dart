import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../provider/functions.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({Key? key}) : super(key: key);

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> with TickerProviderStateMixin {
  late final DatabaseHelper _databaseHelper;
  late TabController _tabController;

  final TextEditingController _searchController = TextEditingController();

  List<Sale> _invoices = [];
  List<Sale> _filteredInvoices = [];
  List<Customer> _customers = [];
  List<ProductReturn> _returns = [];

  bool _isLoading = true;
  String _searchQuery = '';
  String _sortBy = 'recent'; // recent, oldest, amount_high, amount_low, customer
  String _statusFilter = 'all'; // all, paid, unpaid, overdue

  DateTime? _startDate;
  DateTime? _endDate;

  // Analytics data
  double _totalRevenue = 0.0;
  double _totalReturns = 0.0;
  double _netRevenue = 0.0;
  double _averageInvoiceValue = 0.0;
  int _totalInvoices = 0;
  int _paidInvoices = 0;
  int _unpaidInvoices = 0;
  Map<String, double> _monthlyRevenue = {};
  Map<String, double> _monthlyReturns = {};
  Map<String, double> _monthlyNetRevenue = {};
  Map<String, int> _customerDemographics = {};

  @override
  void initState() {
    super.initState();
    _databaseHelper = DatabaseHelper();
    _tabController = TabController(length: 3, vsync: this);
    _loadInvoices();
    _searchController.addListener(_onSearchChanged);

    // Set default date range to current month
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterInvoices();
    });
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sales = await _databaseHelper.getAllSales();
      final customers = await _databaseHelper.getAllCustomers();
      final returns = await _databaseHelper.getAllReturns();

      setState(() {
        _invoices = sales;
        _customers = customers;
        _returns = returns;
        _filteredInvoices = List.from(sales);
        _isLoading = false;
      });

      _calculateAnalytics();
      _filterInvoices();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load invoices');
    }
  }

  void _calculateAnalytics() {
    final dateFilteredInvoices = _getDateFilteredInvoices();
    final dateFilteredReturns = _getDateFilteredReturns();

    _totalInvoices = dateFilteredInvoices.length;
    _totalRevenue = dateFilteredInvoices.fold(0.0, (sum, invoice) => sum + invoice.totalAmount);
    _totalReturns = dateFilteredReturns.fold(0.0, (sum, returnItem) => sum + returnItem.totalAmount);
    _netRevenue = _totalRevenue - _totalReturns;
    _averageInvoiceValue = _totalInvoices > 0 ? _netRevenue / _totalInvoices : 0.0;

    // Calculate paid/unpaid (assuming you have a status field)
    _paidInvoices = dateFilteredInvoices.where((inv) => _getInvoiceStatus(inv) == 'Paid').length;
    _unpaidInvoices = _totalInvoices - _paidInvoices;

    // Monthly revenue and returns
    _monthlyRevenue.clear();
    _monthlyReturns.clear();
    _monthlyNetRevenue.clear();

    for (Sale invoice in dateFilteredInvoices) {
      final monthKey = DateFormat('MMM yyyy').format(invoice.saleDate);
      _monthlyRevenue[monthKey] = (_monthlyRevenue[monthKey] ?? 0.0) + invoice.totalAmount;
    }

    for (ProductReturn returnItem in dateFilteredReturns) {
      final monthKey = DateFormat('MMM yyyy').format(returnItem.returnDate);
      _monthlyReturns[monthKey] = (_monthlyReturns[monthKey] ?? 0.0) + returnItem.totalAmount;
    }

    // Calculate net revenue per month
    final allMonths = {..._monthlyRevenue.keys, ..._monthlyReturns.keys};
    for (String month in allMonths) {
      final revenue = _monthlyRevenue[month] ?? 0.0;
      final returns = _monthlyReturns[month] ?? 0.0;
      _monthlyNetRevenue[month] = revenue - returns;
    }

    // Customer demographics
    _customerDemographics.clear();
    for (Sale invoice in dateFilteredInvoices) {
      final customer = _customers.firstWhere(
            (c) => c.id == invoice.customerId,
        orElse: () => Customer(id: 0, name: 'Unknown', createdAt: DateTime.now()),
      );
      final netPurchases = _getCustomerNetPurchases(customer.id);
      final type = _getCustomerType(netPurchases);
      _customerDemographics[type] = (_customerDemographics[type] ?? 0) + 1;
    }
  }

  List<Sale> _getDateFilteredInvoices() {
    if (_startDate == null || _endDate == null) return _invoices;

    return _invoices.where((invoice) {
      return invoice.saleDate.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
          invoice.saleDate.isBefore(_endDate!.add(const Duration(days: 1)));
    }).toList();
  }

  List<ProductReturn> _getDateFilteredReturns() {
    if (_startDate == null || _endDate == null) return _returns;

    return _returns.where((returnItem) {
      return returnItem.returnDate.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
          returnItem.returnDate.isBefore(_endDate!.add(const Duration(days: 1)));
    }).toList();
  }

  double _getCustomerNetPurchases(int? customerId) {
    if (customerId == null) return 0.0;

    final totalPurchases = _invoices
        .where((inv) => inv.customerId == customerId)
        .fold(0.0, (sum, inv) => sum + inv.totalAmount);

    final totalReturns = _returns
        .where((ret) {
      // Find the sale for this return and check if it belongs to this customer
      final sale = _invoices.firstWhere(
              (inv) => inv.id == ret.saleId,
          orElse: () => Sale(totalAmount: 0, saleDate: DateTime.now(), paymentMethod: '')
      );
      return sale.customerId == customerId;
    }).fold(0.0, (sum, ret) => sum + ret.totalAmount);

    return totalPurchases - totalReturns;
  }

  String _getCustomerType(double netPurchases) {
    if (netPurchases >= 1000) return 'VIP';
    if (netPurchases >= 500) return 'Premium';
    if (netPurchases >= 100) return 'Regular';
    return 'New';
  }

  String _getInvoiceStatus(Sale invoice) {
    // Implement your logic here based on your data model
    // For now, random status for demo
    final daysSinceInvoice = DateTime.now().difference(invoice.saleDate).inDays;
    if (daysSinceInvoice > 30) return 'Overdue';
    if (daysSinceInvoice > 15) return 'Unpaid';
    return 'Paid';
  }

  double _getInvoiceNetAmount(Sale invoice) {
    // Calculate net amount after deducting returns for this invoice
    final invoiceReturns = _returns
        .where((ret) => ret.saleId == invoice.id)
        .fold(0.0, (sum, ret) => sum + ret.totalAmount);

    return invoice.totalAmount - invoiceReturns;
  }

  List<ProductReturn> _getInvoiceReturns(int invoiceId) {
    return _returns.where((ret) => ret.saleId == invoiceId).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Paid':
        return Colors.green.shade600;
      case 'Unpaid':
        return Colors.orange.shade600;
      case 'Overdue':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  void _filterInvoices() {
    List<Sale> filtered = _getDateFilteredInvoices();

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((invoice) {
        final customer = _customers.firstWhere(
              (c) => c.id == invoice.customerId,
          orElse: () => Customer(id: 0, name: 'Unknown', createdAt: DateTime.now()),
        );
        return customer.name.toLowerCase().contains(_searchQuery) ||
            invoice.id.toString().contains(_searchQuery) ||
            _formatCurrency(invoice.totalAmount).toLowerCase().contains(_searchQuery) ||
            _formatCurrency(_getInvoiceNetAmount(invoice)).toLowerCase().contains(_searchQuery);
      }).toList();
    }

    // Apply status filter
    if (_statusFilter != 'all') {
      filtered = filtered.where((invoice) {
        final status = _getInvoiceStatus(invoice);
        return status.toLowerCase() == _statusFilter;
      }).toList();
    }

    // Apply sorting
    _sortInvoices(filtered);

    setState(() {
      _filteredInvoices = filtered;
    });
  }

  void _sortInvoices(List<Sale> invoices) {
    switch (_sortBy) {
      case 'recent':
        invoices.sort((a, b) => b.saleDate.compareTo(a.saleDate));
        break;
      case 'oldest':
        invoices.sort((a, b) => a.saleDate.compareTo(b.saleDate));
        break;
      case 'amount_high':
        invoices.sort((a, b) => _getInvoiceNetAmount(b).compareTo(_getInvoiceNetAmount(a)));
        break;
      case 'amount_low':
        invoices.sort((a, b) => _getInvoiceNetAmount(a).compareTo(_getInvoiceNetAmount(b)));
        break;
      case 'customer':
        invoices.sort((a, b) {
          final customerA = _customers.firstWhere(
                (c) => c.id == a.customerId,
            orElse: () => Customer(id: 0, name: 'Unknown', createdAt: DateTime.now()),
          );
          final customerB = _customers.firstWhere(
                (c) => c.id == b.customerId,
            orElse: () => Customer(id: 0, name: 'Unknown', createdAt: DateTime.now()),
          );
          return customerA.name.compareTo(customerB.name);
        });
        break;
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _calculateAnalytics();
      _filterInvoices();
    }
  }

  Future<void> _generateInvoicePDF(Sale invoice) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Generating invoice...'),
            ],
          ),
        ),
      );

      final customer = _customers.firstWhere(
            (c) => c.id == invoice.customerId,
        orElse: () => Customer(id: 0, name: 'Unknown Customer', createdAt: DateTime.now()),
      );

      final saleItems = await _databaseHelper.getSaleItems(invoice.id!);
      final invoiceReturns = _getInvoiceReturns(invoice.id!);

      Navigator.of(context).pop(); // Close loading dialog

      final pdf = await _createInvoicePDF(invoice, customer, saleItems, invoiceReturns);
      await _showInvoiceOptions(invoice, customer, pdf);

    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showErrorSnackBar('Failed to generate invoice: ${e.toString()}');
    }
  }

  Future<pw.Document> _createInvoicePDF(Sale invoice, Customer customer, List<SaleItem> items, List<ProductReturn> returns) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          fontSize: 32,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Invoice #${invoice.id}',
                        style: pw.TextStyle(
                          fontSize: 16,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Your Business Name',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text('123 Business Street', style: const pw.TextStyle(fontSize: 12)),
                      pw.Text('City, State 12345', style: const pw.TextStyle(fontSize: 12)),
                      pw.Text('Phone: (555) 123-4567', style: const pw.TextStyle(fontSize: 12)),
                      pw.Text('Email: info@business.com', style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 40),

              // Invoice Details & Customer Info
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'BILL TO:',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue800,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          customer.name,
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if (customer.address != null) pw.Text(customer.address!, style: const pw.TextStyle(fontSize: 12)),
                        if (customer.phone != null) pw.Text('Phone: ${customer.phone}', style: const pw.TextStyle(fontSize: 12)),
                        if (customer.email != null) pw.Text('Email: ${customer.email}', style: const pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.all(16),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey100,
                            borderRadius: pw.BorderRadius.circular(8),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('Invoice Date:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                                  pw.Text(DateFormat('MMM dd, yyyy').format(invoice.saleDate)),
                                ],
                              ),
                              pw.SizedBox(height: 4),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('Due Date:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                                  pw.Text(DateFormat('MMM dd, yyyy').format(invoice.saleDate.add(const Duration(days: 30)))),
                                ],
                              ),
                              pw.SizedBox(height: 4),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('Status:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                                  pw.Text(_getInvoiceStatus(invoice)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 40),

              // Items Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  // Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Text('Unit Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  // Items
                  ...items.map((item) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Text('Product #${item.productId}'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Text('${item.quantity}', textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Text(_formatCurrency(item.unitPrice), textAlign: pw.TextAlign.right),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Text(_formatCurrency(item.subtotal), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  )).toList(),
                ],
              ),

              pw.SizedBox(height: 20),

              // Returns Section (if any)
              if (returns.isNotEmpty) ...[
                pw.Text(
                  'RETURNS & REFUNDS',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.red800,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.red300),
                  children: [
                    // Header
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.red50),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Return Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Reason', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.right),
                        ),
                      ],
                    ),
                    // Returns
                    ...returns.map((returnItem) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(DateFormat('MMM dd, yyyy').format(returnItem.returnDate), style: const pw.TextStyle(fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('${returnItem.quantity}', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(returnItem.reason, style: const pw.TextStyle(fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('-${_formatCurrency(returnItem.totalAmount)}', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right),
                        ),
                      ],
                    )).toList(),
                  ],
                ),
                pw.SizedBox(height: 20),
              ],

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 250,
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Subtotal:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            pw.Text(_formatCurrency(invoice.totalAmount), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        if (returns.isNotEmpty) ...[
                          pw.SizedBox(height: 4),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Less Returns:', style: pw.TextStyle(color: PdfColors.red800)),
                              pw.Text('-${_formatCurrency(returns.fold(0.0, (sum, ret) => sum + ret.totalAmount))}', style: pw.TextStyle(color: PdfColors.red800)),
                            ],
                          ),
                        ],
                        pw.SizedBox(height: 8),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(12),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blue800,
                            borderRadius: pw.BorderRadius.circular(8),
                          ),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'Net Amount:',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white,
                                  fontSize: 16,
                                ),
                              ),
                              pw.Text(
                                _formatCurrency(_getInvoiceNetAmount(invoice)),
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // Footer
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Payment Terms & Notes:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text('• Payment is due within 30 days of invoice date', style: const pw.TextStyle(fontSize: 12)),
                    pw.Text('• Late payments may incur additional charges', style: const pw.TextStyle(fontSize: 12)),
                    if (returns.isNotEmpty) pw.Text('• Returns have been deducted from the total amount', style: const pw.TextStyle(fontSize: 12)),
                    pw.Text('• Thank you for your business!', style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  Future<void> _showInvoiceOptions(Sale invoice, Customer customer, pw.Document pdf) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.receipt_long, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Text('Invoice #${invoice.id}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose how you want to handle this invoice:',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _printInvoice(pdf);
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
                      await _downloadInvoice(invoice, customer, pdf);
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

  Future<void> _printInvoice(pw.Document pdf) async {
    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Invoice_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      _showErrorSnackBar('Failed to print invoice: ${e.toString()}');
    }
  }

  Future<void> _downloadInvoice(Sale invoice, Customer customer, pw.Document pdf) async {
    try {
      final bytes = await pdf.save();
      final fileName = 'Invoice_${invoice.id}_${customer.name.replaceAll(' ', '_')}.pdf';

      await Printing.sharePdf(
        bytes: bytes,
        filename: fileName,
      );

      _showSuccessSnackBar('Invoice ready for download');
    } catch (e) {
      _showErrorSnackBar('Failed to download invoice: ${e.toString()}');
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

  String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: '₵', decimalDigits: 2).format(amount);
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Invoice Management',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey.shade800,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              Container(
                height: 1,
                color: Colors.grey.shade300,
              ),
              TabBar(
                controller: _tabController,
                labelColor: Colors.blue.shade700,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: Colors.blue.shade700,
                tabs: const [
                  Tab(text: 'All Invoices'),
                  Tab(text: 'Analytics'),
                  Tab(text: 'Demographics'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: _selectDateRange,
            icon: const Icon(Icons.date_range),
            tooltip: 'Select Date Range',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            onSelected: (value) {
              setState(() {
                _sortBy = value;
                _filterInvoices();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'recent',
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 18),
                    SizedBox(width: 8),
                    Text('Most Recent'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'oldest',
                child: Row(
                  children: [
                    Icon(Icons.history, size: 18),
                    SizedBox(width: 8),
                    Text('Oldest First'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'amount_high',
                child: Row(
                  children: [
                    Icon(Icons.trending_up, size: 18),
                    SizedBox(width: 8),
                    Text('Highest Net Amount'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'amount_low',
                child: Row(
                  children: [
                    Icon(Icons.trending_down, size: 18),
                    SizedBox(width: 8),
                    Text('Lowest Net Amount'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'customer',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 18),
                    SizedBox(width: 8),
                    Text('Customer Name'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: _loadInvoices,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInvoicesTab(),
          _buildAnalyticsTab(),
          _buildDemographicsTab(),
        ],
      ),
    );
  }

  Widget _buildInvoicesTab() {
    return Column(
      children: [
        // Search and Filter Bar
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Column(
            children: [
              // Search Bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search invoices by customer, ID, or amount...',
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
              // Filter and Date Range
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade50,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _statusFilter,
                          isExpanded: true,
                          icon: Icon(Icons.filter_list, color: Colors.grey.shade600),
                          onChanged: (value) {
                            setState(() {
                              _statusFilter = value!;
                              _filterInvoices();
                            });
                          },
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All Status')),
                            DropdownMenuItem(value: 'paid', child: Text('Paid')),
                            DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
                            DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _selectDateRange,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue.shade300),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.blue.shade50,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.date_range, color: Colors.blue.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _startDate != null && _endDate != null
                                    ? '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}'
                                    : 'Select Date Range',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Stats Row
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Invoices',
                      '${_filteredInvoices.length}',
                      Icons.receipt_long,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Gross Revenue',
                      _formatCurrency(_filteredInvoices.fold(0.0, (sum, inv) => sum + inv.totalAmount)),
                      Icons.monetization_on,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Net Revenue',
                      _formatCurrency(_filteredInvoices.fold(0.0, (sum, inv) => sum + _getInvoiceNetAmount(inv))),
                      Icons.trending_up,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Total Returns',
                      _formatCurrency(_getDateFilteredReturns().fold(0.0, (sum, ret) => sum + ret.totalAmount)),
                      Icons.keyboard_return,
                      Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Invoice List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredInvoices.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty && _statusFilter == 'all'
                      ? 'No invoices found'
                      : 'No invoices match your filters',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try adjusting your search or filters',
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
            itemCount: _filteredInvoices.length,
            itemBuilder: (context, index) {
              final invoice = _filteredInvoices[index];
              final customer = _customers.firstWhere(
                    (c) => c.id == invoice.customerId,
                orElse: () => Customer(id: 0, name: 'Unknown Customer', createdAt: DateTime.now()),
              );
              final status = _getInvoiceStatus(invoice);
              final netAmount = _getInvoiceNetAmount(invoice);
              final hasReturns = _getInvoiceReturns(invoice.id!).isNotEmpty;

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
                ),
                child: InkWell(
                  onTap: () => _generateInvoicePDF(invoice),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Invoice Icon
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                hasReturns ? Icons.receipt_long_outlined : Icons.receipt_long,
                                color: hasReturns ? Colors.orange.shade700 : Colors.blue.shade700,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Invoice Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Invoice #${invoice.id}',
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
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.keyboard_return, size: 12, color: Colors.orange.shade700),
                                              const SizedBox(width: 2),
                                              Text(
                                                'HAS RETURNS',
                                                style: TextStyle(
                                                  color: Colors.orange.shade700,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(status).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: _getStatusColor(status).withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            color: _getStatusColor(status),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Customer: ${customer.name}',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatDate(invoice.saleDate),
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Due: ${_formatDate(invoice.saleDate.add(const Duration(days: 30)))}',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Amount
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (hasReturns) ...[
                                  Text(
                                    _formatCurrency(invoice.totalAmount),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                ],
                                Text(
                                  _formatCurrency(netAmount),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                    color: hasReturns ? Colors.orange.shade700 : Colors.green.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  hasReturns ? 'Net Amount' : 'Total Amount',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (hasReturns) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Returns: ${_formatCurrency(invoice.totalAmount - netAmount)} deducted from original amount',
                                    style: TextStyle(
                                      color: Colors.orange.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _generateInvoicePDF(invoice),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.blue.shade700,
                                  side: BorderSide(color: Colors.blue.shade300),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.visibility, size: 18),
                                label: const Text('View Invoice'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _generateInvoicePDF(invoice),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.download, size: 18),
                                label: const Text('Download PDF'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Gross Revenue',
                  _formatCurrency(_totalRevenue),
                  Icons.monetization_on,
                  Colors.green,
                  'Before returns',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Total Returns',
                  _formatCurrency(_totalReturns),
                  Icons.keyboard_return,
                  Colors.red,
                  'Refunded amount',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Net Revenue',
                  _formatCurrency(_netRevenue),
                  Icons.trending_up,
                  Colors.blue,
                  'After deducting returns',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Return Rate',
                  '${_totalRevenue > 0 ? ((_totalReturns / _totalRevenue) * 100).toStringAsFixed(1) : 0}%',
                  Icons.assessment,
                  Colors.orange,
                  'Of gross revenue',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Paid Invoices',
                  '$_paidInvoices',
                  Icons.check_circle,
                  Colors.green,
                  '${(_totalInvoices > 0 ? (_paidInvoices / _totalInvoices * 100).toStringAsFixed(1) : 0)}% of total',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Outstanding',
                  '$_unpaidInvoices',
                  Icons.pending,
                  Colors.orange,
                  '${(_totalInvoices > 0 ? (_unpaidInvoices / _totalInvoices * 100).toStringAsFixed(1) : 0)}% of total',
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Revenue vs Returns Chart
          Container(
            padding: const EdgeInsets.all(20),
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
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monthly Revenue vs Returns',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 300,
                  child: _monthlyRevenue.isEmpty
                      ? Center(
                    child: Text(
                      'No data available for selected period',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                      : LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: true),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 60,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                _formatCurrency(value),
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final months = _monthlyRevenue.keys.toList();
                              if (value.toInt() < months.length) {
                                return Text(
                                  months[value.toInt()],
                                  style: const TextStyle(fontSize: 10),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: true),
                      lineBarsData: [
                        // Gross Revenue Line
                        LineChartBarData(
                          spots: _monthlyRevenue.values.toList().asMap().entries.map((entry) {
                            return FlSpot(entry.key.toDouble(), entry.value);
                          }).toList(),
                          isCurved: true,
                          color: Colors.green.shade600,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.green.shade100,
                          ),
                        ),
                        // Returns Line
                        LineChartBarData(
                          spots: _monthlyReturns.values.toList().asMap().entries.map((entry) {
                            return FlSpot(entry.key.toDouble(), entry.value);
                          }).toList(),
                          isCurved: true,
                          color: Colors.red.shade600,
                          barWidth: 2,
                          dotData: const FlDotData(show: true),
                        ),
                        // Net Revenue Line
                        LineChartBarData(
                          spots: _monthlyNetRevenue.values.toList().asMap().entries.map((entry) {
                            return FlSpot(entry.key.toDouble(), entry.value);
                          }).toList(),
                          isCurved: true,
                          color: Colors.blue.shade600,
                          barWidth: 4,
                          dotData: const FlDotData(show: true),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Legend
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildLegendItem('Gross Revenue', Colors.green.shade600),
                    _buildLegendItem('Returns', Colors.red.shade600),
                    _buildLegendItem('Net Revenue', Colors.blue.shade600),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildDemographicsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer Type Distribution
          Container(
            padding: const EdgeInsets.all(20),
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
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer Demographics (Net Purchases)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Based on net purchase amounts after returns',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 250,
                  child: _customerDemographics.isEmpty
                      ? Center(
                    child: Text(
                      'No customer data available',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                      : PieChart(
                    PieChartData(
                      sections: _customerDemographics.entries.map((entry) {
                        final colors = {
                          'VIP': Colors.purple.shade600,
                          'Premium': Colors.orange.shade600,
                          'Regular': Colors.green.shade600,
                          'New': Colors.blue.shade600,
                        };
                        return PieChartSectionData(
                          value: entry.value.toDouble(),
                          title: '${entry.key}\n${entry.value}',
                          color: colors[entry.key] ?? Colors.grey,
                          radius: 80,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Customer Type Criteria
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer Type Criteria (Net Purchases)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text('• VIP: ₵1,000+ net purchases', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                Text('• Premium: ₵500+ net purchases', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                Text('• Regular: ₵100+ net purchases', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                Text('• New: Below ₵100 net purchases', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Demographics Summary
          ...(_customerDemographics.entries.map((entry) {
            final colors = {
              'VIP': Colors.purple.shade600,
              'Premium': Colors.orange.shade600,
              'Regular': Colors.green.shade600,
              'New': Colors.blue.shade600,
            };

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colors[entry.key] ?? Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${entry.key} Customers',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    '${entry.value} invoices',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(_totalInvoices > 0 ? (entry.value / _totalInvoices * 100).toStringAsFixed(1) : 0)}%',
                    style: TextStyle(
                      color: colors[entry.key] ?? Colors.grey,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }).toList()),
        ],
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

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}