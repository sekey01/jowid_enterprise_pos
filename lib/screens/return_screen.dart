import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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

  Sale? _selectedSale;
  SaleItem? _selectedSaleItem;
  Product? _selectedProduct;

  bool _isLoading = true;
  bool _isProcessing = false;
  String _searchQuery = '';
  String _returnReason = 'Defective Product';
  int _selectedTabIndex = 0; // 0 = Process Returns, 1 = View Returns

  final List<String> _returnReasons = [
    'Defective Product',
    'Wrong Item',
    'Customer Changed Mind',
    'Damaged in Transit',
    'Quality Issues',
    'Size/Fit Issues',
    'Not as Described',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Error loading data: $e');
    }
  }

  String _getCustomerName(int? customerId) {
    if (customerId == null) return 'Walk-in Customer';
    // In a real app, you'd fetch customer details
    return 'Customer #$customerId';
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

  Future<void> _processReturn() async {
    if (_selectedSale == null || _selectedSaleItem == null) {
      _showErrorSnackBar('Please select a sale and product to return');
      return;
    }

    final quantity = int.tryParse(_quantityController.text) ?? 0;
    if (quantity <= 0 || quantity > _selectedSaleItem!.quantity) {
      _showErrorSnackBar('Invalid return quantity');
      return;
    }

    final reason = _returnReason == 'Other'
        ? _reasonController.text.trim()
        : _returnReason;

    if (reason.isEmpty) {
      _showErrorSnackBar('Please provide a return reason');
      return;
    }

    // Validate the return
    final isValid = await _databaseHelper.validateReturn(
      _selectedSale!.id!,
      _selectedSaleItem!.productId,
      quantity,
    );

    if (!isValid) {
      _showErrorSnackBar('Invalid return: Check quantity limits');
      return;
    }

    setState(() => _isProcessing = true);

    try {
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

      _showSuccessSnackBar('Return processed successfully');
      _clearForm();
      await _loadData();

    } catch (e) {
      _showErrorSnackBar('Error processing return: $e');
    } finally {
      setState(() => _isProcessing = false);
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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 12))),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 12))),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
                      '₵${sale.totalAmount.toStringAsFixed(2)}',
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
            _showErrorSnackBar('No available quantity to return for this item');
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
                    '₵${saleItem.unitPrice.toStringAsFixed(2)}',
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
                'Total: ₵${saleItem.subtotal.toStringAsFixed(2)}',
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
                  '₵${returnItem.totalAmount.toStringAsFixed(2)}',
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
                        '₵${_selectedSale!.totalAmount.toStringAsFixed(2)} • ${_selectedSale!.paymentMethod}',
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
                        'Unit Price: ₵${_selectedSaleItem!.unitPrice.toStringAsFixed(2)}',
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
                    labelText: 'Return Quantity',
                    labelStyle: const TextStyle(fontSize: 10),
                    hintText: 'Max: ${_selectedSaleItem!.quantity}',
                    hintStyle: const TextStyle(fontSize: 9),
                    prefixIcon: const Icon(Icons.numbers, size: 16),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                    labelText: 'Return Reason',
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
                      labelText: 'Specify Reason',
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

                // Process Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _processReturn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : const Text('Process Return', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ] else ...[
                const Center(
                  child: Text(
                    'Select a sale and product\nto process return',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey),
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
                  child: Text(
                    'No sales found',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
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
            ],
          ),
        ),
        Expanded(
          child: _filteredReturns.isEmpty
              ? const Center(
            child: Text(
              'No returns found',
              style: TextStyle(fontSize: 11, color: Colors.grey),
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
            onPressed: _loadData,
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
                        ? 'Search sales...'
                        : 'Search returns...',
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
          ? const Center(child: CircularProgressIndicator())
          : _selectedTabIndex == 0
          ? _buildProcessReturnsTab()
          : _buildViewReturnsTab(),
    );
  }
}