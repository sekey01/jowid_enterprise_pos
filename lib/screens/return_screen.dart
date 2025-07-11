import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../provider/functions.dart';

class ReturnsPage extends StatefulWidget {
  const ReturnsPage({super.key});

  @override
  State<ReturnsPage> createState() => _ReturnsPageState();
}

class _ReturnsPageState extends State<ReturnsPage> with TickerProviderStateMixin {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // Controllers
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  // Tab Controller
  late TabController _tabController;

  // State variables
  List<Sale> _sales = [];
  List<Sale> _filteredSales = [];
  List<SaleItem> _saleItems = [];
  List<Product> _products = [];
  List<ProductReturn> _returns = [];
  List<ProductReturn> _filteredReturns = [];
  List<Customer> _customers = [];

  Sale? _selectedSale;
  SaleItem? _selectedSaleItem;
  Product? _selectedProduct;

  bool _isLoading = true;
  bool _isProcessing = false;
  String _searchQuery = '';
  String _returnReason = 'Defective Product';
  int _selectedTabIndex = 0; // 0 = Process Returns, 1 = View Returns
  String _selectedCurrency = 'GHS';

  final List<String> _returnReasons = [
    'Defective Product',
    'Wrong Item',
    'Customer Changed Mind',
    'Damaged in Transit',
    'Quality Issues',
    'Size/Fit Issues',
    'Not as Described',
    'Expired Product',
    'Customer Complaint',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBusinessSettings();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _quantityController.dispose();
    _reasonController.dispose();
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
      if (_selectedTabIndex == 0) {
        _filterSales();
      } else {
        _filterReturns();
      }
    });
  }

  void _filterSales() {
    setState(() {
      if (_searchQuery.isEmpty) {
        _filteredSales = _sales;
      } else {
        _filteredSales = _sales.where((sale) {
          final customer = _getCustomerName(sale.customerId);
          return sale.id.toString().contains(_searchQuery) ||
              customer.toLowerCase().contains(_searchQuery) ||
              DateFormat('yyyy-MM-dd').format(sale.saleDate).contains(_searchQuery);
        }).toList();
      }
    });
  }

  void _filterReturns() {
    setState(() {
      if (_searchQuery.isEmpty) {
        _filteredReturns = _returns;
      } else {
        _filteredReturns = _returns.where((returnItem) {
          final productName = _getProductName(returnItem.productId);
          return returnItem.id.toString().contains(_searchQuery) ||
              productName.toLowerCase().contains(_searchQuery) ||
              returnItem.reason.toLowerCase().contains(_searchQuery);
        }).toList();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final sales = await _databaseHelper.getAllSales();
      final products = await _databaseHelper.getAllProducts();
      final returns = await _databaseHelper.getAllReturns();
      final customers = await _databaseHelper.getAllCustomers();

      // Load all sale items
      List<SaleItem> allSaleItems = [];
      for (Sale sale in sales) {
        if (sale.id != null) {
          final items = await _databaseHelper.getSaleItems(sale.id!);
          allSaleItems.addAll(items);
        }
      }

      setState(() {
        _sales = sales;
        _filteredSales = sales;
        _products = products;
        _saleItems = allSaleItems;
        _returns = returns;
        _filteredReturns = returns;
        _customers = customers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorAlert('Loading Error', 'Failed to load data: ${e.toString()}');
    }
  }

  String _getCustomerName(int? customerId) {
    if (customerId == null) return 'Walk-in Customer';
    try {
      final customer = _customers.firstWhere((c) => c.id == customerId);
      return customer.name;
    } catch (e) {
      return 'Customer #$customerId';
    }
  }

  String _getProductName(int productId) {
    try {
      final product = _products.firstWhere((p) => p.id == productId);
      return product.name;
    } catch (e) {
      return 'Unknown Product';
    }
  }

  Product? _getProduct(int productId) {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (e) {
      return null;
    }
  }

  List<SaleItem> _getSaleItems(int saleId) {
    return _saleItems.where((item) => item.saleId == saleId).toList();
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

  Future<void> _processReturn() async {
    if (_selectedSale == null || _selectedSaleItem == null) {
      _showErrorAlert('Selection Required', 'Please select a sale and product to return');
      return;
    }

    final quantity = int.tryParse(_quantityController.text) ?? 0;
    if (quantity <= 0) {
      _showErrorAlert('Invalid Quantity', 'Please enter a valid return quantity greater than 0');
      return;
    }

    if (quantity > _selectedSaleItem!.quantity) {
      _showErrorAlert('Quantity Exceeded', 'Return quantity (${quantity}) cannot exceed sold quantity (${_selectedSaleItem!.quantity})');
      return;
    }

    final reason = _returnReason == 'Other'
        ? _reasonController.text.trim()
        : _returnReason;

    if (reason.isEmpty) {
      _showErrorAlert('Reason Required', 'Please provide a return reason');
      return;
    }

    // Show confirmation dialog
    final confirmed = await _showConfirmationDialog(
      'Confirm Return',
      'Are you sure you want to process this return?\n\n'
          'Product: ${_selectedProduct!.name}\n'
          'Quantity: $quantity\n'
          'Amount: ${_formatCurrency(_selectedSaleItem!.unitPrice * quantity)}\n'
          'Reason: $reason',
    );

    if (!confirmed) return;

    setState(() => _isProcessing = true);

    try {
      // Validate the return
      final isValid = await _databaseHelper.validateReturn(
        _selectedSale!.id!,
        _selectedSaleItem!.productId,
        quantity,
      );

      if (!isValid) {
        setState(() => _isProcessing = false);
        _showErrorAlert('Validation Failed', 'Invalid return: Check quantity limits or existing returns for this item');
        return;
      }

      // Create return record
      final returnItem = ProductReturn(
        saleId: _selectedSale!.id!,
        productId: _selectedSaleItem!.productId,
        quantity: quantity,
        unitPrice: _selectedSaleItem!.unitPrice,
        totalAmount: _selectedSaleItem!.unitPrice * quantity,
        reason: reason,
        returnDate: DateTime.now(),
        status: 'Completed',
      );

      // Process the return
      await _databaseHelper.processReturn(returnItem);

      setState(() => _isProcessing = false);

      // Show success dialog
      await _showSuccessAlert(
        'Return Processed Successfully!',
        'Return has been completed successfully.\n\n'
            'Return ID: #${returnItem.id ?? 'Pending'}\n'
            'Product: ${_selectedProduct!.name}\n'
            'Quantity Returned: $quantity\n'
            'Refund Amount: ${_formatCurrency(returnItem.totalAmount)}\n'
            'Date: ${DateFormat('MMM dd, yyyy HH:mm').format(returnItem.returnDate)}',
      );

      // Clear form and refresh data
      _clearForm();
      await _loadData();

    } catch (e) {
      setState(() => _isProcessing = false);
      _showErrorAlert('Processing Failed', 'Failed to process return: ${e.toString()}\n\nPlease try again or contact support.');
    }
  }

  void _clearForm() {
    setState(() {
      _selectedSale = null;
      _selectedSaleItem = null;
      _selectedProduct = null;
      _quantityController.clear();
      _reasonController.clear();
      _returnReason = 'Defective Product';
    });
  }

  // Enhanced Success Alert Dialog
  Future<void> _showSuccessAlert(String title, String message) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle, color: Colors.green.shade600, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.green.shade600, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'The inventory has been updated and the refund can be processed.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('OK', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // Enhanced Error Alert Dialog
  Future<void> _showErrorAlert(String title, String message) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error, color: Colors.red.shade600, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_outlined, color: Colors.red.shade600, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Please review the details and try again.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('OK', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // Confirmation Dialog
  Future<bool> _showConfirmationDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.help_outline, color: Colors.orange.shade600, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Confirm Return', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 12))),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 12))),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildSaleCard(Sale sale) {
    final saleItems = _getSaleItems(sale.id!);
    final isSelected = _selectedSale?.id == sale.id;

    return Card(
      elevation: isSelected ? 3 : 1,
      color: isSelected ? Colors.blue.shade50 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: isSelected ? Colors.blue.shade300 : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedSale = sale;
            _selectedSaleItem = null;
            _selectedProduct = null;
          });
        },
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sale #${sale.id}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.blue.shade700 : Colors.black,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      _formatCurrency(sale.totalAmount),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _getCustomerName(sale.customerId),
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                DateFormat('MMM dd, yyyy - HH:mm').format(sale.saleDate),
                style: TextStyle(
                  fontSize: 8,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${saleItems.length} item(s) • ${sale.paymentMethod}',
                style: TextStyle(
                  fontSize: 8,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaleItemCard(SaleItem saleItem) {
    final product = _getProduct(saleItem.productId);
    final isSelected = _selectedSaleItem?.id == saleItem.id;

    return Card(
      elevation: isSelected ? 2 : 1,
      color: isSelected ? Colors.orange.shade50 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: isSelected ? Colors.orange.shade300 : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () async {
          // Check available return quantity before selection
          final availableQty = await _databaseHelper.getAvailableReturnQuantity(
            _selectedSale!.id!,
            saleItem.productId,
          );

          if (availableQty <= 0) {
            _showErrorAlert(
              'No Returns Available',
              'No available quantity to return for this item.\n\nThis may be because:\n• All items have already been returned\n• Return period has expired\n• Item is not eligible for return',
            );
            return;
          }

          setState(() {
            _selectedSaleItem = saleItem;
            _selectedProduct = product;
            _quantityController.text = '1';
          });
        },
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product?.name ?? 'Unknown Product',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.orange.shade700 : Colors.black,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Qty: ${saleItem.quantity}',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    _formatCurrency(saleItem.unitPrice),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Total: ${_formatCurrency(saleItem.subtotal)}',
                style: TextStyle(
                  fontSize: 8,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReturnCard(ProductReturn returnItem) {
    final product = _getProduct(returnItem.productId);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Return #${returnItem.id}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(returnItem.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    returnItem.status,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(returnItem.status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              product?.name ?? 'Unknown Product',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Qty: ${returnItem.quantity}',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  _formatCurrency(returnItem.totalAmount),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                returnItem.reason,
                style: TextStyle(
                  fontSize: 8,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              DateFormat('MMM dd, yyyy - HH:mm').format(returnItem.returnDate),
              style: TextStyle(
                fontSize: 7,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildReturnForm() {
    return Container(
      width: 300,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.keyboard_return, color: Colors.orange, size: 16),
                  const SizedBox(width: 6),
                  const Text(
                    'Process Return',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _clearForm,
                    icon: const Icon(Icons.clear, size: 16),
                    tooltip: 'Clear Form',
                  ),
                ],
              ),
              const Divider(height: 16),

              // Selected Sale Info
              if (_selectedSale != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected Sale #${_selectedSale!.id}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM dd, yyyy').format(_selectedSale!.saleDate),
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '${_formatCurrency(_selectedSale!.totalAmount)} • ${_selectedSale!.paymentMethod}',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        'Customer: ${_getCustomerName(_selectedSale!.customerId)}',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Selected Product Info
              if (_selectedProduct != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected Product',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedProduct!.name,
                        style: const TextStyle(fontSize: 10),
                      ),
                      Text(
                        'Unit Price: ${_formatCurrency(_selectedSaleItem!.unitPrice)}',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        'Sold Qty: ${_selectedSaleItem!.quantity}',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Return Form
              if (_selectedSaleItem != null) ...[
                const Text(
                  'Return Details',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // Quantity Field
                TextFormField(
                  controller: _quantityController,
                  style: const TextStyle(fontSize: 11),
                  decoration: InputDecoration(
                    labelText: 'Return Quantity *',
                    labelStyle: const TextStyle(fontSize: 10),
                    hintText: 'Max: ${_selectedSaleItem!.quantity}',
                    hintStyle: const TextStyle(fontSize: 9),
                    prefixIcon: const Icon(Icons.numbers, size: 16),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    errorStyle: const TextStyle(fontSize: 9),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 8),

                // Reason Dropdown
                DropdownButtonFormField<String>(
                  value: _returnReason,
                  style: const TextStyle(fontSize: 11, color: Colors.black),
                  decoration: const InputDecoration(
                    labelText: 'Return Reason *',
                    labelStyle: TextStyle(fontSize: 10),
                    prefixIcon: Icon(Icons.help_outline, size: 16),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  items: _returnReasons.map((reason) {
                    return DropdownMenuItem<String>(
                      value: reason,
                      child: Text(reason, style: const TextStyle(fontSize: 10)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _returnReason = value ?? 'Defective Product';
                    });
                  },
                ),
                const SizedBox(height: 8),

                // Custom Reason Field (if "Other" is selected)
                if (_returnReason == 'Other') ...[
                  TextFormField(
                    controller: _reasonController,
                    style: const TextStyle(fontSize: 11),
                    decoration: const InputDecoration(
                      labelText: 'Specify Reason *',
                      labelStyle: TextStyle(fontSize: 10),
                      hintText: 'Enter custom reason',
                      hintStyle: TextStyle(fontSize: 9),
                      prefixIcon: Icon(Icons.edit, size: 16),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                ],

                // Expected Refund Amount
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Expected Refund:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      Text(
                        _formatCurrency(
                          _selectedSaleItem!.unitPrice * (int.tryParse(_quantityController.text) ?? 0),
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Process Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _processReturn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _isProcessing
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : const Icon(Icons.keyboard_return, size: 16),
                    label: Text(
                      _isProcessing ? 'Processing...' : 'Process Return',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ] else ...[
                const Center(
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'Select a sale and product\nto process return',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProcessReturnsTab() {
    return Row(
      children: [
        // Sales List
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.white,
                child: Row(
                  children: [
                    const Icon(Icons.receipt, size: 16),
                    const SizedBox(width: 6),
                    const Text(
                      'Select Sale',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      '${_filteredSales.length} sales',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _filteredSales.isEmpty
                    ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'No sales found',
                        style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Try adjusting your search',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _filteredSales.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _buildSaleCard(_filteredSales[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Sale Items List
        if (_selectedSale != null)
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.white,
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_cart, size: 16),
                      const SizedBox(width: 6),
                      const Text(
                        'Select Product',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text(
                        '${_getSaleItems(_selectedSale!.id!).length} items',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _getSaleItems(_selectedSale!.id!).length,
                    itemBuilder: (context, index) {
                      final saleItems = _getSaleItems(_selectedSale!.id!);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _buildSaleItemCard(saleItems[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

        // Return Form
        _buildReturnForm(),
      ],
    );
  }

  Widget _buildViewReturnsTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.white,
          child: Row(
            children: [
              const Icon(Icons.history, size: 16),
              const SizedBox(width: 6),
              const Text(
                'Returns History',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${_filteredReturns.length} returns',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 8),
              Text(
                'Total: ${_formatCurrency(_filteredReturns.fold(0.0, (sum, ret) => sum + ret.totalAmount))}',
                style: TextStyle(fontSize: 10, color: Colors.red.shade600, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Expanded(
          child: _filteredReturns.isEmpty
              ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.keyboard_return_outlined, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'No returns found',
                  style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                Text(
                  'Returns will appear here once processed',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          )
              : GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.2,
            ),
            itemCount: _filteredReturns.length,
            itemBuilder: (context, index) {
              return _buildReturnCard(_filteredReturns[index]);
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Returns Management',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await _loadBusinessSettings();
              _loadData();
            },
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: _selectedTabIndex == 0
                        ? 'Search sales by ID, customer, or date...'
                        : 'Search returns by ID, product, or reason...',
                    hintStyle: const TextStyle(fontSize: 11),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          if (_selectedTabIndex == 0) {
                            _filteredSales = _sales;
                          } else {
                            _filteredReturns = _returns;
                          }
                        });
                      },
                      icon: const Icon(Icons.clear, size: 16),
                    )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),

              // Tab Bar
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  onTap: (index) {
                    setState(() {
                      _selectedTabIndex = index;
                      _clearForm();
                    });
                  },
                  labelColor: Colors.orange.shade700,
                  unselectedLabelColor: Colors.grey.shade600,
                  indicatorColor: Colors.orange.shade700,
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(text: 'Process Returns'),
                    Tab(text: 'View Returns'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading returns data...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      )
          : _selectedTabIndex == 0
          ? _buildProcessReturnsTab()
          : _buildViewReturnsTab(),
    );
  }
}