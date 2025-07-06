import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import '../../provider/functions.dart';

class Sell extends StatefulWidget {
  const Sell({super.key});

  @override
  State<Sell> createState() => _SellState();
}

class _SellState extends State<Sell> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  Map<int, int> _cart = {}; // productId -> quantity
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isWholesaleMode = false; // Toggle between retail and wholesale
  String _searchQuery = '';

  // Controllers
  final _searchController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _customerAddressController = TextEditingController();

  // Payment method
  String _selectedPaymentMethod = 'Cash';
  final List<String> _paymentMethods = ['Cash', 'Card', 'Mobile Money', 'Bank Transfer'];

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerEmailController.dispose();
    _customerAddressController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterProducts();
    });
  }

  void _filterProducts() {
    if (_searchQuery.isEmpty) {
      _filteredProducts = List.from(_products);
    } else {
      _filteredProducts = _products.where((product) {
        return product.name.toLowerCase().contains(_searchQuery) ||
            product.description.toLowerCase().contains(_searchQuery) ||
            product.category.toLowerCase().contains(_searchQuery);
      }).toList();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final products = await _dbHelper.getAllProducts();
      setState(() {
        _products = products;
        _filterProducts();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }

  void _addToCart(Product product) {
    if (product.id == null) return;

    final currentCartQuantity = _cart[product.id!] ?? 0;
    if (product.stockQuantity > currentCartQuantity) {
      setState(() {
        _cart[product.id!] = currentCartQuantity + 1;
      });
    } else {
      _showMessage('Insufficient stock available!', isError: true);
    }
  }

  void _removeFromCart(int productId) {
    setState(() {
      if (_cart[productId] != null && _cart[productId]! > 1) {
        _cart[productId] = _cart[productId]! - 1;
      } else {
        _cart.remove(productId);
      }
    });
  }

  void _updateCartQuantity(int productId, int newQuantity) {
    try {
      final product = _products.firstWhere((p) => p.id == productId);
      if (newQuantity <= 0) {
        setState(() {
          _cart.remove(productId);
        });
      } else if (newQuantity <= product.stockQuantity) {
        setState(() {
          _cart[productId] = newQuantity;
        });
      } else {
        _showMessage('Quantity exceeds available stock!', isError: true);
      }
    } catch (e) {
      _showMessage('Error updating cart: Product not found', isError: true);
    }
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _customerNameController.clear();
      _customerPhoneController.clear();
      _customerEmailController.clear();
      _customerAddressController.clear();
      _selectedPaymentMethod = 'Cash';
    });
  }

  double get _cartTotal {
    double total = 0;
    _cart.forEach((productId, quantity) {
      try {
        final product = _products.firstWhere((p) => p.id == productId);
        final price = _getCurrentPrice(product);
        total += price * quantity;
      } catch (e) {
        print('Product with ID $productId not found in cart calculation');
      }
    });
    return total;
  }

  double _getCurrentPrice(Product product) {
    if (_isWholesaleMode && product.wholesalePrice > 0) {
      return product.wholesalePrice;
    }
    return product.price;
  }

  int get _cartItemCount {
    return _cart.values.fold(0, (sum, quantity) => sum + quantity);
  }

  Future<void> _processSale() async {
    if (_cart.isEmpty) {
      _showMessage('Cart is empty!', isError: true);
      return;
    }

    if (_customerNameController.text.trim().isEmpty) {
      _showMessage('Customer name is required!', isError: true);
      return;
    }

    // Validate stock availability before processing
    for (var entry in _cart.entries) {
      final productId = entry.key;
      final quantity = entry.value;
      try {
        final product = _products.firstWhere((p) => p.id == productId);
        if (product.stockQuantity < quantity) {
          _showMessage('Insufficient stock for ${product.name}!', isError: true);
          return;
        }
      } catch (e) {
        _showMessage('Error: Product not found in inventory!', isError: true);
        return;
      }
    }

    try {
      // Create or find customer
      int? customerId;
      final existingCustomers = await _dbHelper.searchCustomers(_customerNameController.text.trim());

      if (existingCustomers.isNotEmpty) {
        customerId = existingCustomers.first.id;
      } else {
        final customer = Customer(
          name: _customerNameController.text.trim(),
          phone: _customerPhoneController.text.trim().isEmpty
              ? null : _customerPhoneController.text.trim(),
          email: _customerEmailController.text.trim().isEmpty
              ? null : _customerEmailController.text.trim(),
          address: _customerAddressController.text.trim().isEmpty
              ? null : _customerAddressController.text.trim(),
          createdAt: DateTime.now(),
        );
        customerId = await _dbHelper.insertCustomer(customer);
      }

      // Create sale items
      List<SaleItem> saleItems = [];
      for (var entry in _cart.entries) {
        final productId = entry.key;
        final quantity = entry.value;
        try {
          final product = _products.firstWhere((p) => p.id == productId);
          final unitPrice = _getCurrentPrice(product);

          saleItems.add(SaleItem(
            saleId: 0, // Will be set by processSale
            productId: productId,
            quantity: quantity,
            unitPrice: unitPrice,
            subtotal: unitPrice * quantity,
          ));
        } catch (e) {
          _showMessage('Error processing product with ID $productId', isError: true);
          return;
        }
      }

      // Create sale
      final sale = Sale(
        customerId: customerId,
        saleDate: DateTime.now(),
        totalAmount: _cartTotal,
        paymentMethod: _selectedPaymentMethod,
      );

      // Process sale (this handles stock updates automatically)
      final saleId = await _dbHelper.processSale(sale, saleItems);

      _showMessage('Sale completed successfully!\nSale ID: $saleId');
      _clearCart();
      _loadData(); // Refresh products to show updated stock

    } catch (e) {
      _showMessage('Error processing sale: $e', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(
          isError ? 'Error' : 'Success',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 11),
          overflow: TextOverflow.ellipsis,
          maxLines: 3,
        ),
        actions: [
          FilledButton(
            child: const Text('OK', style: TextStyle(fontSize: 10)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    if (product.id == null) return const SizedBox.shrink();

    final isInCart = _cart.containsKey(product.id);
    final cartQuantity = _cart[product.id] ?? 0;
    final isOutOfStock = product.stockQuantity <= 0;
    final isLowStock = product.stockQuantity <= 5 && product.stockQuantity > 0;

    return Card(
      borderRadius: BorderRadius.circular(6),
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product name and stock indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                      color: Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: isOutOfStock
                        ? Colors.red
                        : isLowStock
                        ? Colors.orange
                        : Colors.green,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '${product.stockQuantity}',
                    style: const TextStyle(color: Colors.white, fontSize: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Description
            Text(
              product.description,
              style: const TextStyle(color: Colors.grey, fontSize: 8),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),

            // Category
            Text(
              product.category,
              style: const TextStyle(fontSize: 7, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),

            // Price and cart controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Price section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₵${_getCurrentPrice(product).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_isWholesaleMode && product.wholesalePrice > 0 && product.wholesalePrice != product.price)
                        Text(
                          '₵${product.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 7,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),

                // Cart controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isInCart) ...[
                      IconButton(
                        icon: const Icon(FluentIcons.remove, size: 10),
                        onPressed: () => _removeFromCart(product.id!),
                        style: ButtonStyle(
                          padding: ButtonState.all(const EdgeInsets.all(2)),
                        ),
                      ),
                      Container(
                        width: 20,
                        height: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[60]),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Center(
                          child: Text(
                            '$cartQuantity',
                            style: const TextStyle(fontSize: 8),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                    IconButton(
                      icon: const Icon(FluentIcons.add, size: 10),
                      onPressed: !isOutOfStock && (product.stockQuantity > cartQuantity)
                          ? () => _addToCart(product)
                          : null,
                      style: ButtonStyle(
                        padding: ButtonState.all(const EdgeInsets.all(2)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartSection() {
    return Card(
      borderRadius: BorderRadius.circular(8),
      backgroundColor: Colors.white,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cart header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cart',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  '$_cartItemCount items',
                  style: const TextStyle(color: Colors.grey, fontSize: 9),
                ),
              ],
            ),
            const Divider(),

            // Customer Details Form
            const Text('Customer', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10)),
            const SizedBox(height: 6),
            TextBox(
              controller: _customerNameController,
              placeholder: 'Name *',
              prefix: const Icon(FluentIcons.personalize, size: 12),
              style: const TextStyle(fontSize: 9),
              placeholderStyle: const TextStyle(fontSize: 9),
            ),
            const SizedBox(height: 4),
            TextBox(
              controller: _customerPhoneController,
              placeholder: 'Phone',
              prefix: const Icon(FluentIcons.phone, size: 12),
              style: const TextStyle(fontSize: 9),
              placeholderStyle: const TextStyle(fontSize: 9),
            ),
            const SizedBox(height: 4),
            TextBox(
              controller: _customerEmailController,
              placeholder: 'Email',
              prefix: const Icon(FluentIcons.mail, size: 12),
              style: const TextStyle(fontSize: 9),
              placeholderStyle: const TextStyle(fontSize: 9),
            ),
            const SizedBox(height: 8),

            // Payment method
            const Text('Payment', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10)),
            const SizedBox(height: 4),
            ComboBox<String>(
              value: _selectedPaymentMethod,
              items: _paymentMethods.map((method) {
                return ComboBoxItem<String>(
                  value: method,
                  child: Text(method, style: const TextStyle(fontSize: 9)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPaymentMethod = value ?? 'Cash';
                });
              },
            ),
            const SizedBox(height: 8),

            // Cart items
            Expanded(
              child: _cart.isEmpty
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(FluentIcons.shopping_cart, size: 32, color: Colors.grey),
                    SizedBox(height: 4),
                    Text('Cart is empty', style: TextStyle(color: Colors.grey, fontSize: 9)),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: _cart.length,
                itemBuilder: (context, index) {
                  final productId = _cart.keys.elementAt(index);
                  final quantity = _cart[productId]!;

                  try {
                    final product = _products.firstWhere((p) => p.id == productId);
                    final unitPrice = _getCurrentPrice(product);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[40]),
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.grey[10],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  product.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 9),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(FluentIcons.delete, size: 10),
                                onPressed: () => _removeFromCart(productId),
                                style: ButtonStyle(
                                  padding: ButtonState.all(const EdgeInsets.all(2)),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$quantity × ₵${unitPrice.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 8),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '₵${(quantity * unitPrice).toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(FluentIcons.remove, size: 8),
                                onPressed: () => _updateCartQuantity(productId, quantity - 1),
                                style: ButtonStyle(
                                  padding: ButtonState.all(const EdgeInsets.all(1)),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 20,
                                  child: TextBox(
                                    controller: TextEditingController(text: quantity.toString()),
                                    onChanged: (value) {
                                      final newQuantity = int.tryParse(value) ?? 0;
                                      _updateCartQuantity(productId, newQuantity);
                                    },
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 8),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(FluentIcons.add, size: 8),
                                onPressed: product.stockQuantity > quantity
                                    ? () => _updateCartQuantity(productId, quantity + 1)
                                    : null,
                                style: ButtonStyle(
                                  padding: ButtonState.all(const EdgeInsets.all(1)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  } catch (e) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Product not found', style: TextStyle(color: Colors.red, fontSize: 8)),
                          IconButton(
                            icon: const Icon(FluentIcons.delete, size: 10),
                            onPressed: () => _removeFromCart(productId),
                            style: ButtonStyle(
                              padding: ButtonState.all(const EdgeInsets.all(2)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
            ),

            // Cart total and actions
            if (_cart.isNotEmpty) ...[
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  Text(
                    '₵${_cartTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Button(
                      onPressed: _clearCart,
                      style: ButtonStyle(
                        padding: ButtonState.all(const EdgeInsets.symmetric(vertical: 6)),
                      ),
                      child: const Text('Clear', style: TextStyle(fontSize: 9)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _processSale,
                      child: const Text('Complete Sale', style: TextStyle(fontSize: 9)),
                      style: ButtonStyle(
                        padding: ButtonState.all(const EdgeInsets.symmetric(vertical: 6)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Point of Sale', style: TextStyle(fontSize: 14)),
        commandBar: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Search box
            SizedBox(
              width: 200,
              child: TextBox(
                controller: _searchController,
                placeholder: 'Search...',
                prefix: const Icon(FluentIcons.search, size: 14),
                suffix: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(FluentIcons.clear, size: 12),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
                    : null,
                style: const TextStyle(fontSize: 10),
                placeholderStyle: const TextStyle(fontSize: 10),
              ),
            ),
            const SizedBox(width: 8),

            // Wholesale/Retail toggle
            ToggleButton(
              checked: _isWholesaleMode,
              onChanged: (value) {
                setState(() {
                  _isWholesaleMode = value;
                });
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_isWholesaleMode ? FluentIcons.shop : FluentIcons.shop_server, size: 12),
                  const SizedBox(width: 2),
                  Text(
                    _isWholesaleMode ? 'Wholesale' : 'Retail',
                    style: const TextStyle(fontSize: 9),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // Refresh button
            Button(
              onPressed: _loadData,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.refresh, size: 12),
                  SizedBox(width: 2),
                  Text('Refresh', style: TextStyle(fontSize: 9)),
                ],
              ),
            ),
          ],
        ),
      ),
      content: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ProgressRing(),
            SizedBox(height: 8),
            Text('Loading...', style: TextStyle(fontSize: 10)),
          ],
        ),
      )
          : _errorMessage.isNotEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.error, size: 32, color: Colors.red),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: TextStyle(color: Colors.red, fontSize: 10),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Button(
              onPressed: _loadData,
              child: const Text('Retry', style: TextStyle(fontSize: 9)),
            ),
          ],
        ),
      )
          : Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Products section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Products (${_filteredProducts.length}/${_products.length}) - ${_isWholesaleMode ? 'Wholesale' : 'Retail'}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _filteredProducts.isEmpty
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(FluentIcons.search, size: 32, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No products found matching "$_searchQuery"'
                                : 'No products available',
                            style: const TextStyle(color: Colors.grey, fontSize: 10),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    )
                        : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) => _buildProductCard(_filteredProducts[index]),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Cart section
          _buildCartSection(),
        ],
      ),
    );
  }
}