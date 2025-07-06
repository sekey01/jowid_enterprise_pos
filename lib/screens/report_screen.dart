import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:convert';
import 'dart:typed_data';

import '../../provider/functions.dart';

enum ReportType {
  salesSummary,
  customerReport,
  inventoryReport,
  financialReport,
  returnsReport,
  fullBackup,
  customReport
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({Key? key}) : super(key: key);

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late final DatabaseHelper _databaseHelper;

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  ReportType _selectedReportType = ReportType.salesSummary;
  bool _isGenerating = false;
  bool _isLoading = true;

  List<Sale> _sales = [];
  List<Customer> _customers = [];
  List<Product> _products = [];
  List<SaleItem> _saleItems = [];
  List<ProductReturn> _returns = [];

  // Report data
  Map<String, dynamic> _reportData = {};

  // Custom report selections
  Set<String> _selectedDataTypes = {'sales', 'customers'};

  @override
  void initState() {
    super.initState();
    _databaseHelper = DatabaseHelper();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sales = await _databaseHelper.getAllSales();
      final customers = await _databaseHelper.getAllCustomers();
      final returns = await _databaseHelper.getAllReturns();

      // Try to get products, handle if method doesn't exist
      List<Product> products = [];
      try {
        products = await _databaseHelper.getAllProducts();
      } catch (e) {
        print('getAllProducts method not available: $e');
        products = [];
      }

      // Load all sale items
      List<SaleItem> allSaleItems = [];
      for (Sale sale in sales) {
        if (sale.id != null) {
          try {
            final items = await _databaseHelper.getSaleItems(sale.id!);
            allSaleItems.addAll(items);
          } catch (e) {
            print('Could not load sale items for sale ${sale.id}: $e');
          }
        }
      }

      setState(() {
        _sales = sales;
        _customers = customers;
        _products = products;
        _saleItems = allSaleItems;
        _returns = returns;
        _isLoading = false;
      });

      _generateReportData();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load data: ${e.toString()}');
    }
  }

  void _generateReportData() {
    final startDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final endDate = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    final monthSales = _sales.where((sale) =>
    sale.saleDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
        sale.saleDate.isBefore(endDate.add(const Duration(days: 1)))
    ).toList();

    final monthReturns = _returns.where((returnItem) =>
    returnItem.returnDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
        returnItem.returnDate.isBefore(endDate.add(const Duration(days: 1)))
    ).toList();

    final grossRevenue = monthSales.fold(0.0, (sum, sale) => sum + sale.totalAmount);
    final totalReturns = monthReturns.fold(0.0, (sum, returnItem) => sum + returnItem.totalAmount);
    final netRevenue = grossRevenue - totalReturns;

    setState(() {
      _reportData = {
        'period': {
          'month': DateFormat('MMMM yyyy').format(_selectedMonth),
          'startDate': startDate,
          'endDate': endDate,
        },
        'sales': {
          'totalSales': monthSales.length,
          'grossRevenue': grossRevenue,
          'totalReturns': totalReturns,
          'netRevenue': netRevenue,
          'averageOrderValue': monthSales.isNotEmpty ? grossRevenue / monthSales.length : 0.0,
          'netAverageOrderValue': monthSales.isNotEmpty ? netRevenue / monthSales.length : 0.0,
          'returnRate': grossRevenue > 0 ? (totalReturns / grossRevenue) * 100 : 0.0,
          'dailyBreakdown': _getDailyBreakdown(monthSales, monthReturns),
          'topCustomers': _getTopCustomers(monthSales),
        },
        'customers': {
          'totalCustomers': _customers.length,
          'newCustomers': _customers.where((customer) =>
          customer.createdAt.isAfter(startDate.subtract(const Duration(days: 1))) &&
              customer.createdAt.isBefore(endDate.add(const Duration(days: 1)))
          ).length,
          'activeCustomers': _getActiveCustomers(monthSales).length,
          'customerTypes': _getCustomerTypeBreakdown(),
        },
        'products': {
          'totalProducts': _products.length,
          'topSellingProducts': _getTopSellingProducts(monthSales),
          'topReturnedProducts': _getTopReturnedProducts(monthReturns),
          'lowStockItems': _products.where((product) => _getProductStock(product) < 10).toList(),
        },
        'financial': {
          'grossRevenue': grossRevenue,
          'totalReturns': totalReturns,
          'netRevenue': netRevenue,
          'totalTransactions': monthSales.length,
          'totalReturnTransactions': monthReturns.length,
          'returnRate': grossRevenue > 0 ? (totalReturns / grossRevenue) * 100 : 0.0,
          'paymentMethods': _getPaymentMethodBreakdown(monthSales),
        },
        'returns': {
          'totalReturns': monthReturns.length,
          'totalReturnValue': totalReturns,
          'averageReturnValue': monthReturns.isNotEmpty ? totalReturns / monthReturns.length : 0.0,
          'returnsByReason': _getReturnsByReason(monthReturns),
          'returnsByProduct': _getTopReturnedProducts(monthReturns),
          'dailyReturns': _getDailyReturns(monthReturns),
          'returnTrends': _getReturnTrends(monthReturns),
        }
      };
    });
  }

  List<Map<String, dynamic>> _getDailyBreakdown(List<Sale> sales, List<ProductReturn> returns) {
    Map<String, double> dailyGrossRevenue = {};
    Map<String, double> dailyReturns = {};
    Map<String, int> dailySalesCount = {};
    Map<String, int> dailyReturnsCount = {};

    for (Sale sale in sales) {
      String dateKey = DateFormat('yyyy-MM-dd').format(sale.saleDate);
      dailyGrossRevenue[dateKey] = (dailyGrossRevenue[dateKey] ?? 0.0) + sale.totalAmount;
      dailySalesCount[dateKey] = (dailySalesCount[dateKey] ?? 0) + 1;
    }

    for (ProductReturn returnItem in returns) {
      String dateKey = DateFormat('yyyy-MM-dd').format(returnItem.returnDate);
      dailyReturns[dateKey] = (dailyReturns[dateKey] ?? 0.0) + returnItem.totalAmount;
      dailyReturnsCount[dateKey] = (dailyReturnsCount[dateKey] ?? 0) + 1;
    }

    Set<String> allDates = {...dailyGrossRevenue.keys, ...dailyReturns.keys};

    return allDates.map((dateKey) {
      final grossRevenue = dailyGrossRevenue[dateKey] ?? 0.0;
      final returnsAmount = dailyReturns[dateKey] ?? 0.0;
      final netRevenue = grossRevenue - returnsAmount;

      return {
        'date': dateKey,
        'grossRevenue': grossRevenue,
        'returns': returnsAmount,
        'netRevenue': netRevenue,
        'salesCount': dailySalesCount[dateKey] ?? 0,
        'returnsCount': dailyReturnsCount[dateKey] ?? 0,
      };
    }).toList()..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
  }

  List<Map<String, dynamic>> _getDailyReturns(List<ProductReturn> returns) {
    Map<String, double> dailyReturns = {};
    Map<String, int> dailyCount = {};

    for (ProductReturn returnItem in returns) {
      String dateKey = DateFormat('yyyy-MM-dd').format(returnItem.returnDate);
      dailyReturns[dateKey] = (dailyReturns[dateKey] ?? 0.0) + returnItem.totalAmount;
      dailyCount[dateKey] = (dailyCount[dateKey] ?? 0) + 1;
    }

    return dailyReturns.entries.map((entry) => {
      'date': entry.key,
      'amount': entry.value,
      'count': dailyCount[entry.key] ?? 0,
    }).toList()..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
  }

  Map<String, dynamic> _getReturnsByReason(List<ProductReturn> returns) {
    Map<String, int> reasonCount = {};
    Map<String, double> reasonAmount = {};

    for (ProductReturn returnItem in returns) {
      reasonCount[returnItem.reason] = (reasonCount[returnItem.reason] ?? 0) + 1;
      reasonAmount[returnItem.reason] = (reasonAmount[returnItem.reason] ?? 0.0) + returnItem.totalAmount;
    }

    return {
      'count': reasonCount,
      'amount': reasonAmount,
    };
  }

  List<Map<String, dynamic>> _getTopReturnedProducts(List<ProductReturn> returns) {
    Map<int, Map<String, dynamic>> productReturns = {};

    for (ProductReturn returnItem in returns) {
      if (!productReturns.containsKey(returnItem.productId)) {
        final product = _products.firstWhere(
              (p) => p.id == returnItem.productId,
          orElse: () => Product(
            name: 'Unknown Product #${returnItem.productId}',
            description: '',
            price: 0,
            wholesalePrice: 0,
            stockQuantity: 0,
            category: 'Unknown',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        productReturns[returnItem.productId] = {
          'productName': _getProductName(product),
          'returnCount': 0,
          'totalReturnValue': 0.0,
          'totalQuantityReturned': 0,
        };
      }

      productReturns[returnItem.productId]!['returnCount'] += 1;
      productReturns[returnItem.productId]!['totalReturnValue'] += returnItem.totalAmount;
      productReturns[returnItem.productId]!['totalQuantityReturned'] += returnItem.quantity;
    }

    List<Map<String, dynamic>> topReturned = productReturns.values.toList();
    topReturned.sort((a, b) => (b['totalReturnValue'] as double).compareTo(a['totalReturnValue'] as double));

    return topReturned.take(10).toList();
  }

  Map<String, double> _getReturnTrends(List<ProductReturn> returns) {
    Map<String, double> weeklyTrends = {};

    for (ProductReturn returnItem in returns) {
      final weekStart = _getWeekStart(returnItem.returnDate);
      final weekKey = DateFormat('MMM dd').format(weekStart);
      weeklyTrends[weekKey] = (weeklyTrends[weekKey] ?? 0.0) + returnItem.totalAmount;
    }

    return weeklyTrends;
  }

  DateTime _getWeekStart(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    return date.subtract(Duration(days: daysFromMonday));
  }

  List<Map<String, dynamic>> _getTopCustomers(List<Sale> sales) {
    Map<int, double> customerRevenue = {};
    Map<int, int> customerCount = {};

    for (Sale sale in sales) {
      if (sale.customerId != null) {
        customerRevenue[sale.customerId!] = (customerRevenue[sale.customerId!] ?? 0.0) + sale.totalAmount;
        customerCount[sale.customerId!] = (customerCount[sale.customerId!] ?? 0) + 1;
      }
    }

    List<Map<String, dynamic>> topCustomers = customerRevenue.entries.map((entry) {
      final customer = _customers.firstWhere(
            (c) => c.id == entry.key,
        orElse: () => Customer(id: entry.key, name: 'Unknown Customer', createdAt: DateTime.now()),
      );

      // Calculate net revenue for this customer (gross - returns)
      final customerReturns = _returns.where((ret) {
        final sale = _sales.firstWhere(
              (s) => s.id == ret.saleId,
          orElse: () => Sale(totalAmount: 0, saleDate: DateTime.now(), paymentMethod: ''),
        );
        return sale.customerId == entry.key;
      }).fold(0.0, (sum, ret) => sum + ret.totalAmount);

      final netRevenue = entry.value - customerReturns;

      return {
        'customer': customer,
        'grossRevenue': entry.value,
        'returns': customerReturns,
        'netRevenue': netRevenue,
        'orderCount': customerCount[entry.key] ?? 0,
      };
    }).toList();

    topCustomers.sort((a, b) => (b['netRevenue'] as double).compareTo(a['netRevenue'] as double));
    return topCustomers.take(10).toList();
  }

  List<Customer> _getActiveCustomers(List<Sale> sales) {
    Set<int> activeCustomerIds = sales
        .where((sale) => sale.customerId != null)
        .map((sale) => sale.customerId!)
        .toSet();

    return _customers.where((customer) =>
    customer.id != null && activeCustomerIds.contains(customer.id)
    ).toList();
  }

  Map<String, int> _getCustomerTypeBreakdown() {
    Map<String, int> breakdown = {'VIP': 0, 'Premium': 0, 'Regular': 0, 'New': 0};

    for (Customer customer in _customers) {
      if (customer.id != null) {
        double totalPurchases = _sales
            .where((sale) => sale.customerId == customer.id)
            .fold(0.0, (sum, sale) => sum + sale.totalAmount);

        // Subtract returns for net customer value
        double totalReturns = _returns.where((ret) {
          final sale = _sales.firstWhere(
                (s) => s.id == ret.saleId,
            orElse: () => Sale(totalAmount: 0, saleDate: DateTime.now(), paymentMethod: ''),
          );
          return sale.customerId == customer.id;
        }).fold(0.0, (sum, ret) => sum + ret.totalAmount);

        double netPurchases = totalPurchases - totalReturns;
        String type = _getCustomerType(netPurchases);
        breakdown[type] = (breakdown[type] ?? 0) + 1;
      }
    }

    return breakdown;
  }

  // Helper methods to safely access product properties
  String _getProductName(Product product) {
    try {
      return product.name;
    } catch (e) {
      return 'Unknown Product';
    }
  }

  double _getProductPrice(Product product) {
    try {
      return product.price;
    } catch (e) {
      return 0.0;
    }
  }

  int _getProductStock(Product product) {
    try {
      return product.stockQuantity;
    } catch (e) {
      return 0;
    }
  }

  String _getProductCategory(Product product) {
    try {
      return product.category;
    } catch (e) {
      return 'Uncategorized';
    }
  }

  // Helper methods for SaleItem
  String _getSaleItemProductName(SaleItem item) {
    try {
      final product = _products.firstWhere(
            (p) => p.id == item.productId,
        orElse: () => Product(
          name: 'Product #${item.productId}',
          description: '',
          price: 0,
          wholesalePrice: 0,
          stockQuantity: 0,
          category: 'Unknown',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      return _getProductName(product);
    } catch (e) {
      return 'Unknown Product';
    }
  }

  int _getSaleItemQuantity(SaleItem item) {
    try {
      return item.quantity;
    } catch (e) {
      return 0;
    }
  }

  double _getSaleItemUnitPrice(SaleItem item) {
    try {
      return item.unitPrice;
    } catch (e) {
      return 0.0;
    }
  }

  String _getCustomerType(double netPurchases) {
    if (netPurchases >= 1000) return 'VIP';
    if (netPurchases >= 500) return 'Premium';
    if (netPurchases >= 100) return 'Regular';
    return 'New';
  }

  List<Map<String, dynamic>> _getTopSellingProducts(List<Sale> sales) {
    Map<String, Map<String, dynamic>> productStats = {};

    for (Sale sale in sales) {
      if (sale.id != null) {
        final saleItems = _saleItems.where((item) => item.saleId == sale.id).toList();

        for (SaleItem item in saleItems) {
          String productKey = _getSaleItemProductName(item);

          if (!productStats.containsKey(productKey)) {
            productStats[productKey] = {
              'name': productKey,
              'quantity': 0,
              'revenue': 0.0,
              'sales': 0,
            };
          }

          productStats[productKey]!['quantity'] += _getSaleItemQuantity(item);
          productStats[productKey]!['revenue'] += _getSaleItemUnitPrice(item) * _getSaleItemQuantity(item);
          productStats[productKey]!['sales'] += 1;
        }
      }
    }

    List<Map<String, dynamic>> topProducts = productStats.values.toList();
    topProducts.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));

    return topProducts.take(10).toList();
  }

  Map<String, double> _getPaymentMethodBreakdown(List<Sale> sales) {
    Map<String, double> breakdown = {};
    for (Sale sale in sales) {
      breakdown[sale.paymentMethod] = (breakdown[sale.paymentMethod] ?? 0.0) + sale.totalAmount;
    }
    return breakdown;
  }

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
      _generateReportData();
    }
  }

  Future<void> _generateReport() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      switch (_selectedReportType) {
        case ReportType.salesSummary:
          await _generateSalesReport();
          break;
        case ReportType.customerReport:
          await _generateCustomerReport();
          break;
        case ReportType.inventoryReport:
          await _generateInventoryReport();
          break;
        case ReportType.financialReport:
          await _generateFinancialReport();
          break;
        case ReportType.returnsReport:
          await _generateReturnsReport();
          break;
        case ReportType.fullBackup:
          await _generateFullBackup();
          break;
        case ReportType.customReport:
          await _generateCustomReport();
          break;
      }
    } catch (e) {
      _showErrorSnackBar('Failed to generate report: ${e.toString()}');
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<void> _generateSalesReport() async {
    final pdf = pw.Document();
    final reportData = _reportData['sales'] as Map<String, dynamic>;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          // Header
          _buildReportHeader('SALES REPORT'),

          pw.SizedBox(height: 30),

          // Summary Cards
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildPdfMetricCard(
                  'Total Sales',
                  '${reportData['totalSales']}',
                  'Transactions',
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: _buildPdfMetricCard(
                  'Gross Revenue',
                  _formatCurrency(reportData['grossRevenue']),
                  'Before Returns',
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: _buildPdfMetricCard(
                  'Net Revenue',
                  _formatCurrency(reportData['netRevenue']),
                  'After Returns',
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          pw.Row(
            children: [
              pw.Expanded(
                child: _buildPdfMetricCard(
                  'Total Returns',
                  _formatCurrency(reportData['totalReturns']),
                  'Refunded Amount',
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: _buildPdfMetricCard(
                  'Return Rate',
                  '${reportData['returnRate'].toStringAsFixed(1)}%',
                  'Of Gross Revenue',
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: _buildPdfMetricCard(
                  'Net Avg Order',
                  _formatCurrency(reportData['netAverageOrderValue']),
                  'Per Transaction',
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 30),

          // Top Customers Table
          pw.Text(
            'TOP CUSTOMERS (NET REVENUE)',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 15),

          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableHeader('Customer Name'),
                  _buildTableHeader('Orders'),
                  _buildTableHeader('Gross Revenue'),
                  _buildTableHeader('Returns'),
                  _buildTableHeader('Net Revenue'),
                ],
              ),
              ...((reportData['topCustomers'] as List).take(10).map((customer) {
                final customerData = customer as Map<String, dynamic>;
                final customerObj = customerData['customer'] as Customer;
                final grossRevenue = customerData['grossRevenue'] as double;
                final returns = customerData['returns'] as double;
                final netRevenue = customerData['netRevenue'] as double;
                final orderCount = customerData['orderCount'] as int;

                return pw.TableRow(
                  children: [
                    _buildTableCell(customerObj.name),
                    _buildTableCell('$orderCount'),
                    _buildTableCell(_formatCurrency(grossRevenue)),
                    _buildTableCell(_formatCurrency(returns)),
                    _buildTableCell(_formatCurrency(netRevenue)),
                  ],
                );
              })),
            ],
          ),

          pw.SizedBox(height: 30),

          // Daily Breakdown
          pw.Text(
            'DAILY SALES & RETURNS BREAKDOWN',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 15),

          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableHeader('Date'),
                  _buildTableHeader('Sales'),
                  _buildTableHeader('Gross Revenue'),
                  _buildTableHeader('Returns'),
                  _buildTableHeader('Net Revenue'),
                ],
              ),
              ...((reportData['dailyBreakdown'] as List).map((day) {
                final dayData = day as Map<String, dynamic>;
                final date = dayData['date'] as String;
                final salesCount = dayData['salesCount'] as int;
                final grossRevenue = dayData['grossRevenue'] as double;
                final returns = dayData['returns'] as double;
                final netRevenue = dayData['netRevenue'] as double;

                return pw.TableRow(
                  children: [
                    _buildTableCell(DateFormat('MMM dd').format(DateTime.parse(date))),
                    _buildTableCell('$salesCount'),
                    _buildTableCell(_formatCurrency(grossRevenue)),
                    _buildTableCell(_formatCurrency(returns)),
                    _buildTableCell(_formatCurrency(netRevenue)),
                  ],
                );
              })),
            ],
          ),
        ],
      ),
    );

    await _savePdf(pdf, 'Sales_Report_${DateFormat('yyyy_MM').format(_selectedMonth)}.pdf');
  }

  Future<void> _generateReturnsReport() async {
    final pdf = pw.Document();
    final returnsData = _reportData['returns'] as Map<String, dynamic>;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          _buildReportHeader('RETURNS ANALYSIS REPORT'),

          pw.SizedBox(height: 30),

          // Returns Summary
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildPdfMetricCard(
                  'Total Returns',
                  '${returnsData['totalReturns']}',
                  'Return Transactions',
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: _buildPdfMetricCard(
                  'Return Value',
                  _formatCurrency(returnsData['totalReturnValue']),
                  'Total Refunded',
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: _buildPdfMetricCard(
                  'Avg Return',
                  _formatCurrency(returnsData['averageReturnValue']),
                  'Per Transaction',
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 30),

          // Returns by Reason
          pw.Text(
            'RETURNS BY REASON',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 15),

          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableHeader('Return Reason'),
                  _buildTableHeader('Count'),
                  _buildTableHeader('Total Value'),
                  _buildTableHeader('Percentage'),
                ],
              ),
              ...(returnsData['returnsByReason']['count'] as Map<String, int>).entries.map((entry) {
                final reason = entry.key;
                final count = entry.value;
                final amount = (returnsData['returnsByReason']['amount'] as Map<String, double>)[reason] ?? 0.0;
                final percentage = returnsData['totalReturns'] > 0
                    ? (count / returnsData['totalReturns'] * 100)
                    : 0.0;

                return pw.TableRow(
                  children: [
                    _buildTableCell(reason),
                    _buildTableCell('$count'),
                    _buildTableCell(_formatCurrency(amount)),
                    _buildTableCell('${percentage.toStringAsFixed(1)}%'),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 30),

          // Top Returned Products
          pw.Text(
            'TOP RETURNED PRODUCTS',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 15),

          if ((returnsData['returnsByProduct'] as List).isNotEmpty) ...[
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableHeader('Product Name'),
                    _buildTableHeader('Return Count'),
                    _buildTableHeader('Qty Returned'),
                    _buildTableHeader('Return Value'),
                  ],
                ),
                ...((returnsData['returnsByProduct'] as List).map((product) => pw.TableRow(
                  children: [
                    _buildTableCell(product['productName']),
                    _buildTableCell('${product['returnCount']}'),
                    _buildTableCell('${product['totalQuantityReturned']}'),
                    _buildTableCell(_formatCurrency(product['totalReturnValue'])),
                  ],
                ))),
              ],
            ),
          ] else ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColors.green100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                'No returns recorded for this period!',
                style: pw.TextStyle(color: PdfColors.green800, fontSize: 14),
              ),
            ),
          ],

          pw.SizedBox(height: 30),

          // Daily Returns Trend
          pw.Text(
            'DAILY RETURNS TREND',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 15),

          if ((returnsData['dailyReturns'] as List).isNotEmpty) ...[
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableHeader('Date'),
                    _buildTableHeader('Return Count'),
                    _buildTableHeader('Return Value'),
                  ],
                ),
                ...((returnsData['dailyReturns'] as List).map((day) => pw.TableRow(
                  children: [
                    _buildTableCell(DateFormat('MMM dd').format(DateTime.parse(day['date']))),
                    _buildTableCell('${day['count']}'),
                    _buildTableCell(_formatCurrency(day['amount'])),
                  ],
                ))),
              ],
            ),
          ],
        ],
      ),
    );

    await _savePdf(pdf, 'Returns_Report_${DateFormat('yyyy_MM').format(_selectedMonth)}.pdf');
  }

  Future<void> _generateFinancialReport() async {
    final pdf = pw.Document();
    final financialData = _reportData['financial'] as Map<String, dynamic>;
    final salesData = _reportData['sales'] as Map<String, dynamic>;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          _buildReportHeader('FINANCIAL REPORT'),

          pw.SizedBox(height: 30),

          // Financial Summary
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildPdfMetricCard(
                  'Gross Revenue',
                  _formatCurrency(financialData['grossRevenue']),
                  'Total Sales Income',
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: _buildPdfMetricCard(
                  'Total Returns',
                  _formatCurrency(financialData['totalReturns']),
                  'Refunded Amount',
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: _buildPdfMetricCard(
                  'Net Revenue',
                  _formatCurrency(financialData['netRevenue']),
                  'Actual Income',
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          pw.Row(
            children: [
              pw.Expanded(
                child: _buildPdfMetricCard(
                  'Sales Transactions',
                  '${financialData['totalTransactions']}',
                  'Completed Sales',
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: _buildPdfMetricCard(
                  'Return Transactions',
                  '${financialData['totalReturnTransactions']}',
                  'Return Count',
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: _buildPdfMetricCard(
                  'Return Rate',
                  '${financialData['returnRate'].toStringAsFixed(1)}%',
                  'Of Gross Revenue',
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 30),

          // Payment Methods Breakdown
          pw.Text(
            'PAYMENT METHODS BREAKDOWN',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 15),

          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableHeader('Payment Method'),
                  _buildTableHeader('Total Amount'),
                  _buildTableHeader('Percentage'),
                ],
              ),
              ...(financialData['paymentMethods'] as Map<String, double>).entries.map((entry) {
                final method = entry.key;
                final amount = entry.value;
                final totalRevenue = financialData['grossRevenue'] as double;
                final percentage = totalRevenue > 0 ? (amount / totalRevenue) * 100 : 0.0;

                return pw.TableRow(
                  children: [
                    _buildTableCell(method),
                    _buildTableCell(_formatCurrency(amount)),
                    _buildTableCell('${percentage.toStringAsFixed(1)}%'),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 30),

          // Daily Revenue Breakdown
          pw.Text(
            'DAILY FINANCIAL BREAKDOWN',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 15),

          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableHeader('Date'),
                  _buildTableHeader('Sales Count'),
                  _buildTableHeader('Gross Revenue'),
                  _buildTableHeader('Returns'),
                  _buildTableHeader('Net Revenue'),
                ],
              ),
              ...((salesData['dailyBreakdown'] as List).map((day) {
                final dayData = day as Map<String, dynamic>;
                final date = dayData['date'] as String;
                final salesCount = dayData['salesCount'] as int;
                final grossRevenue = dayData['grossRevenue'] as double;
                final returns = dayData['returns'] as double;
                final netRevenue = dayData['netRevenue'] as double;

                return pw.TableRow(
                  children: [
                    _buildTableCell(DateFormat('MMM dd').format(DateTime.parse(date))),
                    _buildTableCell('$salesCount'),
                    _buildTableCell(_formatCurrency(grossRevenue)),
                    _buildTableCell(_formatCurrency(returns)),
                    _buildTableCell(_formatCurrency(netRevenue)),
                  ],
                );
              })),
            ],
          ),
        ],
      ),
    );

    await _savePdf(pdf, 'Financial_Report_${DateFormat('yyyy_MM').format(_selectedMonth)}.pdf');
  }

  Future<void> _generateCustomerReport() async {
    final pdf = pw.Document();
    final customerData = _reportData['customers'] as Map<String, dynamic>;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          _buildReportHeader('CUSTOMER REPORT'),

          pw.SizedBox(height: 30),

          // Customer Summary
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildPdfMetricCard(
                  'Total Customers',
                  '${customerData['totalCustomers']}',
                  'Registered',
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: _buildPdfMetricCard(
                  'New Customers',
                  '${customerData['newCustomers']}',
                  'This Month',
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: _buildPdfMetricCard(
                  'Active Customers',
                  '${customerData['activeCustomers']}',
                  'With Purchases',
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 30),

          // Customer Types Breakdown (Based on Net Purchases)
          pw.Text(
            'CUSTOMER SEGMENTATION (NET PURCHASES)',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Customer types based on net purchase value after returns',
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 15),

          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableHeader('Customer Type'),
                  _buildTableHeader('Count'),
                  _buildTableHeader('Percentage'),
                  _buildTableHeader('Criteria'),
                ],
              ),
              ...(customerData['customerTypes'] as Map<String, int>).entries.map((entry) {
                final customerType = entry.key;
                final count = entry.value;
                final totalCustomers = customerData['totalCustomers'] as int;

                String criteria = '';
                switch (customerType) {
                  case 'VIP':
                    criteria = '₵1,000+ net';
                    break;
                  case 'Premium':
                    criteria = '₵500+ net';
                    break;
                  case 'Regular':
                    criteria = '₵100+ net';
                    break;
                  case 'New':
                    criteria = 'Below ₵100 net';
                    break;
                }

                return pw.TableRow(
                  children: [
                    _buildTableCell(customerType),
                    _buildTableCell('$count'),
                    _buildTableCell('${(count / totalCustomers * 100).toStringAsFixed(1)}%'),
                    _buildTableCell(criteria),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    await _savePdf(pdf, 'Customer_Report_${DateFormat('yyyy_MM').format(_selectedMonth)}.pdf');
  }

  Future<void> _generateInventoryReport() async {
    final pdf = pw.Document();
    final productData = _reportData['products'] as Map<String, dynamic>;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          _buildReportHeader('INVENTORY REPORT'),

          pw.SizedBox(height: 30),

          // Inventory Summary
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildPdfMetricCard(
                  'Total Products',
                  '${productData['totalProducts']}',
                  'In Catalog',
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: _buildPdfMetricCard(
                  'Low Stock Items',
                  '${(productData['lowStockItems'] as List).length}',
                  'Need Reorder',
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: _buildPdfMetricCard(
                  'Total Stock Value',
                  _formatCurrency(_products.fold(0.0, (sum, product) => sum + (_getProductPrice(product) * _getProductStock(product)))),
                  'Inventory Value',
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 30),

          // Top Selling vs Top Returned Products Comparison
          pw.Text(
            'PRODUCT PERFORMANCE ANALYSIS',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 15),

          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Top Selling Products
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'TOP SELLING PRODUCTS',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey300),
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: PdfColors.green100),
                          children: [
                            _buildTableHeader('Product'),
                            _buildTableHeader('Revenue'),
                          ],
                        ),
                        ...((productData['topSellingProducts'] as List).take(5).map((product) => pw.TableRow(
                          children: [
                            _buildTableCell(product['name']),
                            _buildTableCell(_formatCurrency(product['revenue'])),
                          ],
                        ))),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              // Top Returned Products
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'TOP RETURNED PRODUCTS',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red800),
                    ),
                    pw.SizedBox(height: 10),
                    if ((productData['topReturnedProducts'] as List).isNotEmpty) ...[
                      pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey300),
                        children: [
                          pw.TableRow(
                            decoration: pw.BoxDecoration(color: PdfColors.red100),
                            children: [
                              _buildTableHeader('Product'),
                              _buildTableHeader('Return Value'),
                            ],
                          ),
                          ...((productData['topReturnedProducts'] as List).take(5).map((product) => pw.TableRow(
                            children: [
                              _buildTableCell(product['productName']),
                              _buildTableCell(_formatCurrency(product['totalReturnValue'])),
                            ],
                          ))),
                        ],
                      ),
                    ] else ...[
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.green100,
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Text(
                          'No returns recorded!',
                          style: pw.TextStyle(color: PdfColors.green800, fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 30),

          // Low Stock Alert
          pw.Text(
            'LOW STOCK ALERT',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.red),
          ),
          pw.SizedBox(height: 15),

          if ((productData['lowStockItems'] as List).isNotEmpty)
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.red100),
                  children: [
                    _buildTableHeader('Product Name'),
                    _buildTableHeader('Current Stock'),
                    _buildTableHeader('Unit Price'),
                    _buildTableHeader('Action Required'),
                  ],
                ),
                ...((productData['lowStockItems'] as List<Product>).map((product) => pw.TableRow(
                  children: [
                    _buildTableCell(_getProductName(product)),
                    _buildTableCell('${_getProductStock(product)}'),
                    _buildTableCell(_formatCurrency(_getProductPrice(product))),
                    _buildTableCell(_getProductStock(product) == 0 ? 'OUT OF STOCK' : 'REORDER SOON'),
                  ],
                ))),
              ],
            )
          else
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColors.green100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                'All products are adequately stocked!',
                style: pw.TextStyle(color: PdfColors.green800, fontSize: 14),
              ),
            ),
        ],
      ),
    );

    await _savePdf(pdf, 'Inventory_Report_${DateFormat('yyyy_MM').format(_selectedMonth)}.pdf');
  }

  Future<void> _generateFullBackup() async {
    try {
      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Creating backup...'),
            ],
          ),
        ),
      );

      Map<String, dynamic> backupData = {
        'backup_info': {
          'generated_at': DateTime.now().toIso8601String(),
          'period': _reportData['period']['month'],
          'version': '2.0',
          'total_records': _sales.length + _customers.length + _products.length + _returns.length,
        },
        'sales': _sales.map((sale) => {
          'id': sale.id,
          'customerId': sale.customerId,
          'totalAmount': sale.totalAmount,
          'saleDate': sale.saleDate.toIso8601String(),
          'paymentMethod': sale.paymentMethod,
        }).toList(),
        'customers': _customers.map((customer) => {
          'id': customer.id,
          'name': customer.name,
          'phone': customer.phone,
          'email': customer.email,
          'address': customer.address,
          'createdAt': customer.createdAt.toIso8601String(),
        }).toList(),
        'products': _products.map((product) => {
          'id': product.id,
          'name': _getProductName(product),
          'price': _getProductPrice(product),
          'wholesalePrice': product.wholesalePrice,
          'stock': _getProductStock(product),
          'category': _getProductCategory(product),
        }).toList(),
        'sale_items': _saleItems.map((item) => {
          'id': item.id,
          'saleId': item.saleId,
          'productId': item.productId,
          'quantity': _getSaleItemQuantity(item),
          'unitPrice': _getSaleItemUnitPrice(item),
          'subtotal': item.subtotal,
        }).toList(),
        'returns': _returns.map((returnItem) => {
          'id': returnItem.id,
          'saleId': returnItem.saleId,
          'productId': returnItem.productId,
          'quantity': returnItem.quantity,
          'unitPrice': returnItem.unitPrice,
          'totalAmount': returnItem.totalAmount,
          'reason': returnItem.reason,
          'returnDate': returnItem.returnDate.toIso8601String(),
          'status': returnItem.status,
          'notes': returnItem.notes,
        }).toList(),
        'summary': _reportData,
      };

      String jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
      Uint8List bytes = Uint8List.fromList(utf8.encode(jsonString));

      String fileName = 'Full_Backup_${DateFormat('yyyy_MM_dd_HHmm').format(DateTime.now())}.json';

      Navigator.of(context).pop(); // Close progress dialog

      await Printing.sharePdf(
        bytes: bytes,
        filename: fileName,
      );

      _showSuccessSnackBar('Full backup exported successfully');
    } catch (e) {
      Navigator.of(context).pop(); // Close progress dialog
      _showErrorSnackBar('Failed to create backup: ${e.toString()}');
    }
  }

  Future<void> _generateCustomReport() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          _buildReportHeader('CUSTOM REPORT'),

          pw.SizedBox(height: 30),

          // Build sections based on selected data types
          if (_selectedDataTypes.contains('sales'))
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'SALES DATA',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: _buildPdfMetricCard(
                        'Total Sales',
                        '${_reportData['sales']['totalSales']}',
                        'Transactions',
                      ),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Expanded(
                      child: _buildPdfMetricCard(
                        'Net Revenue',
                        _formatCurrency(_reportData['sales']['netRevenue']),
                        'After Returns',
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
              ],
            ),

          if (_selectedDataTypes.contains('customers'))
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CUSTOMER DATA',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: _buildPdfMetricCard(
                        'Total Customers',
                        '${_reportData['customers']['totalCustomers']}',
                        'Registered',
                      ),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Expanded(
                      child: _buildPdfMetricCard(
                        'Active Customers',
                        '${_reportData['customers']['activeCustomers']}',
                        'With Purchases',
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
              ],
            ),

          if (_selectedDataTypes.contains('inventory'))
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'INVENTORY DATA',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: _buildPdfMetricCard(
                        'Total Products',
                        '${_reportData['products']['totalProducts']}',
                        'In Catalog',
                      ),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Expanded(
                      child: _buildPdfMetricCard(
                        'Low Stock Items',
                        '${(_reportData['products']['lowStockItems'] as List).length}',
                        'Need Attention',
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
              ],
            ),

          if (_selectedDataTypes.contains('financial'))
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'FINANCIAL DATA',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: _buildPdfMetricCard(
                        'Net Revenue',
                        _formatCurrency(_reportData['financial']['netRevenue']),
                        'After Returns',
                      ),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Expanded(
                      child: _buildPdfMetricCard(
                        'Return Rate',
                        '${_reportData['financial']['returnRate'].toStringAsFixed(1)}%',
                        'Of Gross Revenue',
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
              ],
            ),

          if (_selectedDataTypes.contains('returns'))
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'RETURNS DATA',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: _buildPdfMetricCard(
                        'Total Returns',
                        '${_reportData['returns']['totalReturns']}',
                        'Return Transactions',
                      ),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Expanded(
                      child: _buildPdfMetricCard(
                        'Return Value',
                        _formatCurrency(_reportData['returns']['totalReturnValue']),
                        'Total Refunded',
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
              ],
            ),

          // Custom report summary
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.teal50,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.teal200),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Report Components:',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.teal800,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  _selectedDataTypes.map((type) => type.toUpperCase()).join(', '),
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.teal700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    await _savePdf(pdf, 'Custom_Report_${DateFormat('yyyy_MM').format(_selectedMonth)}.pdf');
  }

  pw.Widget _buildReportHeader(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 20),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 2, color: PdfColors.blue)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                _reportData['period'] != null ? _reportData['period']['month'] : DateFormat('MMMM yyyy').format(_selectedMonth),
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
                'Generated: ${DateFormat('MMM dd, yyyy \'at\' HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Your Business Name',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Business Address',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfMetricCard(String title, String value, String subtitle) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.blue200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            subtitle,
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  pw.Widget _buildTableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9),
      ),
    );
  }

  Future<void> _savePdf(pw.Document pdf, String fileName) async {
    try {
      final bytes = await pdf.save();

      await Printing.sharePdf(
        bytes: bytes,
        filename: fileName,
      );

      _showSuccessSnackBar('Report exported successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to export report: ${e.toString()}');
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

  String _getReportTypeTitle(ReportType type) {
    switch (type) {
      case ReportType.salesSummary:
        return 'Sales Summary Report';
      case ReportType.customerReport:
        return 'Customer Analysis Report';
      case ReportType.inventoryReport:
        return 'Inventory Status Report';
      case ReportType.financialReport:
        return 'Financial Performance Report';
      case ReportType.returnsReport:
        return 'Returns Analysis Report';
      case ReportType.fullBackup:
        return 'Complete Data Backup';
      case ReportType.customReport:
        return 'Custom Report';
    }
  }

  String _getReportTypeDescription(ReportType type) {
    switch (type) {
      case ReportType.salesSummary:
        return 'Comprehensive sales performance with net revenue insights';
      case ReportType.customerReport:
        return 'Customer demographics and net purchase analysis';
      case ReportType.inventoryReport:
        return 'Stock levels, returns impact, and product performance';
      case ReportType.financialReport:
        return 'Revenue breakdown with returns impact analysis';
      case ReportType.returnsReport:
        return 'Detailed returns analysis with reasons and trends';
      case ReportType.fullBackup:
        return 'Complete database backup including returns data';
      case ReportType.customReport:
        return 'Customizable report with selected data components';
    }
  }

  IconData _getReportTypeIcon(ReportType type) {
    switch (type) {
      case ReportType.salesSummary:
        return Icons.trending_up;
      case ReportType.customerReport:
        return Icons.people;
      case ReportType.inventoryReport:
        return Icons.inventory;
      case ReportType.financialReport:
        return Icons.account_balance;
      case ReportType.returnsReport:
        return Icons.keyboard_return;
      case ReportType.fullBackup:
        return Icons.backup;
      case ReportType.customReport:
        return Icons.tune;
    }
  }

  Color _getReportTypeColor(ReportType type) {
    switch (type) {
      case ReportType.salesSummary:
        return Colors.blue;
      case ReportType.customerReport:
        return Colors.green;
      case ReportType.inventoryReport:
        return Colors.orange;
      case ReportType.financialReport:
        return Colors.purple;
      case ReportType.returnsReport:
        return Colors.red;
      case ReportType.fullBackup:
        return Colors.grey;
      case ReportType.customReport:
        return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Monthly Reports & Backup',
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
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading data...'),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month Selection and Quick Stats
            Container(
              padding: const EdgeInsets.all(24),
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
                      Icon(Icons.calendar_month, color: Colors.blue.shade700, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'Report Period',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _selectMonth,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.edit_calendar, size: 18),
                        label: Text(
                          DateFormat('MMMM yyyy').format(_selectedMonth),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Quick Stats
                  if (_reportData.isNotEmpty) ...[
                    Text(
                      'Period Overview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Sales',
                            '${_reportData['sales']['totalSales']}',
                            Icons.receipt_long,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Net Revenue',
                            _formatCurrency(_reportData['sales']['netRevenue']),
                            Icons.monetization_on,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Returns',
                            '${_reportData['returns']['totalReturns']}',
                            Icons.keyboard_return,
                            Colors.red,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Return Rate',
                            '${_reportData['sales']['returnRate'].toStringAsFixed(1)}%',
                            Icons.trending_down,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Report Types
            Text(
              'Available Reports',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a report type to generate detailed insights and backup data for the selected period.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 20),

            // Report Type Cards
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
              ),
              itemCount: ReportType.values.length,
              itemBuilder: (context, index) {
                final reportType = ReportType.values[index];
                final isSelected = _selectedReportType == reportType;
                final color = _getReportTypeColor(reportType);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedReportType = reportType;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withOpacity(0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? color : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getReportTypeIcon(reportType),
                            color: color,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _getReportTypeTitle(reportType),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? color : Colors.grey.shade800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getReportTypeDescription(reportType),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Custom Report Options
            if (_selectedReportType == ReportType.customReport) ...[
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
                      'Custom Report Configuration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select the data components to include in your custom report:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _buildCheckboxChip('Sales Data', 'sales'),
                        _buildCheckboxChip('Customer Data', 'customers'),
                        _buildCheckboxChip('Inventory Data', 'inventory'),
                        _buildCheckboxChip('Financial Data', 'financial'),
                        _buildCheckboxChip('Returns Data', 'returns'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Generate Report Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getReportTypeColor(_selectedReportType),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                icon: _isGenerating
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Icon(_getReportTypeIcon(_selectedReportType)),
                label: Text(
                  _isGenerating
                      ? 'Generating Report...'
                      : 'Generate ${_getReportTypeTitle(_selectedReportType)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Information Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Report Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• Reports now include returns analysis for accurate financial insights\n'
                        '• Net revenue calculations show actual income after deducting returns\n'
                        '• Customer segmentation based on net purchase value\n'
                        '• Returns analysis helps identify problem products and trends\n'
                        '• Daily breakdowns show both sales and returns impact\n'
                        '• Full backup includes all returns data for complete restoration\n'
                        '• Generated files can be saved, shared, or printed directly\n'
                        '• Return rate tracking helps monitor business performance',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade700,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
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

  Widget _buildCheckboxChip(String label, String dataType) {
    final isSelected = _selectedDataTypes.contains(dataType);

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedDataTypes.add(dataType);
          } else {
            _selectedDataTypes.remove(dataType);
          }
        });
      },
      selectedColor: Colors.teal.shade100,
      checkmarkColor: Colors.teal.shade700,
      labelStyle: TextStyle(
        color: isSelected ? Colors.teal.shade700 : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}