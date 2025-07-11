import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../provider/functions.dart';
import '../../screens/return_screen.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> with TickerProviderStateMixin {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _wholesalePriceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // Form key for validation
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // State variables
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<String> _categories = [];
  String _selectedCategory = '';
  Product? _editingProduct;
  bool _isLoading = false;
  bool _isFormLoading = false;
  String _sortBy = 'name';
  bool _sortAscending = true;

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _wholesalePriceController.dispose();
    _stockController.dispose();
    _categoryController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Data Loading Methods
  void _onSearchChanged() {
    _filterProducts(_searchController.text);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final products = await _databaseHelper.getAllProducts();
      final categories = await _databaseHelper.getProductCategories();

      setState(() {
        _products = products;
        _filteredProducts = products;
        _categories = categories;
        _isLoading = false;
      });

      _fadeController.forward();
      _sortProducts();
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Error loading data: $e');
    }
  }

  void _filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _products;
      } else {
        _filteredProducts = _products.where((product) =>
        product.name.toLowerCase().contains(query.toLowerCase()) ||
            product.description.toLowerCase().contains(query.toLowerCase()) ||
            product.category.toLowerCase().contains(query.toLowerCase())
        ).toList();
      }
      _sortProducts();
    });
  }

  void _sortProducts() {
    setState(() {
      _filteredProducts.sort((a, b) {
        dynamic aValue, bValue;

        switch (_sortBy) {
          case 'name':
            aValue = a.name.toLowerCase();
            bValue = b.name.toLowerCase();
            break;
          case 'category':
            aValue = a.category.toLowerCase();
            bValue = b.category.toLowerCase();
            break;
          case 'price':
            aValue = a.price;
            bValue = b.price;
            break;
          case 'stock':
            aValue = a.stockQuantity;
            bValue = b.stockQuantity;
            break;
          case 'created':
            aValue = a.createdAt;
            bValue = b.createdAt;
            break;
          default:
            aValue = a.name.toLowerCase();
            bValue = b.name.toLowerCase();
        }

        int result = Comparable.compare(aValue, bValue);
        return _sortAscending ? result : -result;
      });
    });
  }

  void _changeSortOrder(String sortBy) {
    setState(() {
      if (_sortBy == sortBy) {
        _sortAscending = !_sortAscending;
      } else {
        _sortBy = sortBy;
        _sortAscending = true;
      }
      _sortProducts();
    });
  }

  // Form Management Methods
  void _clearForm() {
    setState(() {
      _nameController.clear();
      _descriptionController.clear();
      _priceController.clear();
      _wholesalePriceController.clear();
      _stockController.clear();
      _categoryController.clear();
      _selectedCategory = '';
      _editingProduct = null;
    });
  }

  void _populateForm(Product product) {
    setState(() {
      _nameController.text = product.name;
      _descriptionController.text = product.description;
      _priceController.text = product.price.toString();
      _wholesalePriceController.text = product.wholesalePrice.toString();
      _stockController.text = product.stockQuantity.toString();
      _categoryController.text = product.category;
      _selectedCategory = product.category;
      _editingProduct = product;
    });
  }

  Future<bool> _checkDuplicateName(String name) async {
    final existingProduct = _products.where((p) =>
    p.name.toLowerCase() == name.toLowerCase() &&
        p.id != _editingProduct?.id
    ).toList();
    return existingProduct.isNotEmpty;
  }

  // CRUD Operations
  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorAlert('Validation Error', 'Please fill in all required fields correctly.');
      return;
    }

    final productName = _nameController.text.trim();

    // Check for duplicate names
    if (await _checkDuplicateName(productName)) {
      _showErrorAlert('Duplicate Product', 'A product with this name already exists!');
      return;
    }

    setState(() => _isFormLoading = true);

    try {
      final now = DateTime.now();
      final product = Product(
        id: _editingProduct?.id,
        name: productName,
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text),
        wholesalePrice: double.tryParse(_wholesalePriceController.text) ?? 0.0,
        stockQuantity: int.parse(_stockController.text),
        category: _selectedCategory.isNotEmpty ? _selectedCategory : _categoryController.text.trim(),
        createdAt: _editingProduct?.createdAt ?? now,
        updatedAt: now,
      );

      if (_editingProduct != null) {
        await _databaseHelper.updateProduct(product);
        setState(() {
          _isFormLoading = false;
        });
        _showSuccessAlert('Success!', 'Product "${product.name}" has been updated successfully!');
      } else {
        await _databaseHelper.insertProduct(product);
        setState(() {
          _isFormLoading = false;
        });
        _showSuccessAlert('Success!', 'Product "${product.name}" has been added successfully!');
      }

      // Clear form and refresh data
      _clearForm();
      await _loadData();

    } catch (e) {
      setState(() => _isFormLoading = false);
      _showErrorAlert('Error', 'Failed to save product: ${e.toString()}');
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final result = await _showConfirmDialog(
      'Delete Product',
      'Are you sure you want to delete "${product.name}"?\n\nThis action cannot be undone.',
      'Delete',
      Colors.red,
    );

    if (result == true) {
      try {
        await _databaseHelper.deleteProduct(product.id!);
        setState(() {
          // Remove from local lists immediately for instant UI update
          _products.removeWhere((p) => p.id == product.id);
          _filteredProducts.removeWhere((p) => p.id == product.id);
        });
        _showSuccessAlert('Deleted!', 'Product "${product.name}" has been deleted successfully!');
        await _loadData(); // Refresh to ensure consistency
      } catch (e) {
        _showErrorAlert('Error', 'Failed to delete product: ${e.toString()}');
      }
    }
  }

  Future<void> _clearAllProducts() async {
    if (_products.isEmpty) {
      _showErrorAlert('No Products', 'There are no products to clear!');
      return;
    }

    final result = await _showConfirmDialog(
      'Clear All Products',
      'Are you sure you want to delete ALL products?\n\nThis will permanently remove ${_products.length} products from your inventory.\n\nThis action cannot be undone.',
      'Clear All',
      Colors.red,
    );

    if (result == true) {
      try {
        setState(() => _isLoading = true);

        // Delete all products
        for (Product product in _products) {
          await _databaseHelper.deleteProduct(product.id!);
        }

        // Update state immediately
        setState(() {
          _products.clear();
          _filteredProducts.clear();
          _categories.clear();
          _isLoading = false;
        });

        _showSuccessAlert('Cleared!', 'All products have been cleared successfully!');
        await _loadData(); // Refresh to ensure consistency
      } catch (e) {
        setState(() => _isLoading = false);
        _showErrorAlert('Error', 'Failed to clear products: ${e.toString()}');
      }
    }
  }

  void _navigateToReturns() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReturnsPage(),
      ),
    ).then((_) => _loadData()); // Refresh data when returning
  }

  // Enhanced Dialog and Notification Methods
  Future<bool?> _showConfirmDialog(String title, String content, String actionText, Color actionColor) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: actionColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(content, style: const TextStyle(fontSize: 12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(fontSize: 11)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor,
              foregroundColor: Colors.white,
            ),
            child: Text(actionText, style: const TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  // Enhanced Success Alert Dialog
  Future<void> _showSuccessAlert(String title, String message) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('OK', style: TextStyle(fontSize: 12)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red.shade600, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('OK', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
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

  // Widget Builder Methods
  Widget _buildSortButton(String field, String label, IconData icon) {
    final isActive = _sortBy == field;
    return InkWell(
      onTap: () => _changeSortOrder(field),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive ? Colors.blue.shade300 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: isActive ? Colors.blue.shade700 : Colors.grey.shade600,
            ),
            const SizedBox(width: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: isActive ? Colors.blue.shade700 : Colors.grey.shade700,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 2),
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 10,
                color: Colors.blue.shade700,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final isLowStock = product.stockQuantity <= 10;
    final isOutOfStock = product.stockQuantity == 0;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: InkWell(
        onTap: () => _populateForm(product),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert, size: 14),
                    iconSize: 14,
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        height: 28,
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 12),
                            SizedBox(width: 4),
                            Text('Edit', style: TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        height: 28,
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 12, color: Colors.red),
                            SizedBox(width: 4),
                            Text('Delete', style: TextStyle(color: Colors.red, fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _populateForm(product);
                      } else if (value == 'delete') {
                        _deleteProduct(product);
                      }
                    },
                  ),
                ],
              ),
              if (product.description.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  product.description,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 9,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  product.category,
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₵${product.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        if (product.wholesalePrice > 0)
                          Text(
                            'W: ₵${product.wholesalePrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: isOutOfStock
                          ? Colors.red.shade100
                          : isLowStock
                          ? Colors.orange.shade100
                          : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOutOfStock
                              ? Icons.error
                              : isLowStock
                              ? Icons.warning
                              : Icons.check_circle,
                          size: 10,
                          color: isOutOfStock
                              ? Colors.red.shade700
                              : isLowStock
                              ? Colors.orange.shade700
                              : Colors.green.shade700,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${product.stockQuantity}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isOutOfStock
                                ? Colors.red.shade700
                                : isLowStock
                                ? Colors.orange.shade700
                                : Colors.green.shade700,
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
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(left: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _editingProduct != null ? Icons.edit : Icons.add,
                      color: Colors.blue.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _editingProduct != null ? 'Edit Product' : 'Add Product',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
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
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Product Name
                        SizedBox(
                          height: 50,
                          child: TextFormField(
                            controller: _nameController,
                            style: const TextStyle(fontSize: 11),
                            decoration: const InputDecoration(
                              labelText: 'Product Name *',
                              labelStyle: TextStyle(fontSize: 10),
                              hintText: 'Enter product name',
                              hintStyle: TextStyle(fontSize: 10),
                              prefixIcon: Icon(Icons.inventory, size: 16),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Product name is required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Description
                        SizedBox(
                          height: 60,
                          child: TextFormField(
                            controller: _descriptionController,
                            style: const TextStyle(fontSize: 11),
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              labelStyle: TextStyle(fontSize: 10),
                              hintText: 'Enter description',
                              hintStyle: TextStyle(fontSize: 10),
                              prefixIcon: Icon(Icons.description, size: 16),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            ),
                            maxLines: 2,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Price Row
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: TextFormField(
                                  controller: _priceController,
                                  style: const TextStyle(fontSize: 11),
                                  decoration: const InputDecoration(
                                    labelText: 'Retail Price (₵) *',
                                    labelStyle: TextStyle(fontSize: 10),
                                    hintText: '0.00',
                                    hintStyle: TextStyle(fontSize: 10),
                                    prefixIcon: Icon(Icons.attach_money, size: 16),
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*\.?\d{0,2}'),
                                    ),
                                  ],
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Price is required';
                                    }
                                    final price = double.tryParse(value);
                                    if (price == null || price < 0) {
                                      return 'Enter a valid price';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: TextFormField(
                                  controller: _wholesalePriceController,
                                  style: const TextStyle(fontSize: 11),
                                  decoration: const InputDecoration(
                                    labelText: 'Wholesale',
                                    labelStyle: TextStyle(fontSize: 10),
                                    hintText: '0.00',
                                    hintStyle: TextStyle(fontSize: 10),
                                    prefixIcon: Icon(Icons.business, size: 16),
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*\.?\d{0,2}'),
                                    ),
                                  ],
                                  validator: (value) {
                                    if (value != null && value.isNotEmpty) {
                                      final price = double.tryParse(value);
                                      if (price == null || price < 0) {
                                        return 'Enter a valid price';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Stock Quantity
                        SizedBox(
                          height: 50,
                          child: TextFormField(
                            controller: _stockController,
                            style: const TextStyle(fontSize: 11),
                            decoration: const InputDecoration(
                              labelText: 'Stock Quantity *',
                              labelStyle: TextStyle(fontSize: 10),
                              hintText: '0',
                              hintStyle: TextStyle(fontSize: 10),
                              prefixIcon: Icon(Icons.storage, size: 16),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Stock quantity is required';
                              }
                              final stock = int.tryParse(value);
                              if (stock == null || stock < 0) {
                                return 'Enter a valid quantity';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Category
                        if (_categories.isNotEmpty)
                          SizedBox(
                            height: 50,
                            child: DropdownButtonFormField<String>(
                              value: _selectedCategory.isEmpty ? null : _selectedCategory,
                              style: const TextStyle(fontSize: 11, color: Colors.black),
                              decoration: const InputDecoration(
                                labelText: 'Category *',
                                labelStyle: TextStyle(fontSize: 10),
                                prefixIcon: Icon(Icons.category, size: 16),
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              ),
                              hint: const Text('Select category', style: TextStyle(fontSize: 10)),
                              items: _categories.map((category) {
                                return DropdownMenuItem<String>(
                                  value: category,
                                  child: Text(category, style: const TextStyle(fontSize: 10)),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCategory = value ?? '';
                                  if (value != null) {
                                    _categoryController.clear();
                                  }
                                });
                              },
                            ),
                          ),
                        if (_categories.isNotEmpty) const SizedBox(height: 8),

                        SizedBox(
                          height: 50,
                          child: TextFormField(
                            controller: _categoryController,
                            style: const TextStyle(fontSize: 11),
                            decoration: InputDecoration(
                              labelText: _categories.isEmpty ? 'Category *' : 'Or create new',
                              labelStyle: const TextStyle(fontSize: 10),
                              hintText: 'Enter category name',
                              hintStyle: const TextStyle(fontSize: 10),
                              prefixIcon: const Icon(Icons.new_label, size: 16),
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            ),
                            onChanged: (value) {
                              if (value.isNotEmpty) {
                                setState(() {
                                  _selectedCategory = '';
                                });
                              }
                            },
                            validator: (value) {
                              if (_selectedCategory.isEmpty &&
                                  (value == null || value.trim().isEmpty)) {
                                return 'Category is required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Form Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _clearForm,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontSize: 10)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isFormLoading ? null : _saveProduct,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                        ),
                        child: _isFormLoading
                            ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                            : Text(
                          _editingProduct != null ? 'Update' : 'Add',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 8,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
          'Inventory Management',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _navigateToReturns,
            icon: const Icon(Icons.keyboard_return, size: 20),
            tooltip: 'Returns',
          ),
          IconButton(
            onPressed: _clearAllProducts,
            icon: const Icon(Icons.clear_all, size: 20),
            tooltip: 'Clear All Products',
          ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : FadeTransition(
        opacity: _fadeAnimation,
        child: Row(
          children: [
            // Product List Section
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  // Search and Filter Bar
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.white,
                    child: Column(
                      children: [
                        // Stats Row
                        Row(
                          children: [
                            _buildStatCard(
                              'Total Products',
                              '${_products.length}',
                              Icons.inventory,
                              Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            _buildStatCard(
                              'Low Stock',
                              '${_products.where((p) => p.stockQuantity <= 10).length}',
                              Icons.warning,
                              Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            _buildStatCard(
                              'Out of Stock',
                              '${_products.where((p) => p.stockQuantity == 0).length}',
                              Icons.error,
                              Colors.red,
                            ),
                            const SizedBox(width: 8),
                            _buildStatCard(
                              'Categories',
                              '${_categories.length}',
                              Icons.category,
                              Colors.green,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Search Bar
                        TextField(
                          controller: _searchController,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Search products...',
                            hintStyle: const TextStyle(fontSize: 11),
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                _filterProducts('');
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
                        const SizedBox(height: 8),

                        // Sort Buttons
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              const Text('Sort by: ', style: TextStyle(fontSize: 9)),
                              const SizedBox(width: 6),
                              _buildSortButton('name', 'Name', Icons.sort_by_alpha),
                              const SizedBox(width: 4),
                              _buildSortButton('category', 'Category', Icons.category),
                              const SizedBox(width: 4),
                              _buildSortButton('price', 'Price', Icons.attach_money),
                              const SizedBox(width: 4),
                              _buildSortButton('stock', 'Stock', Icons.storage),
                              const SizedBox(width: 4),
                              _buildSortButton('created', 'Created', Icons.schedule),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Products Grid
                  Expanded(
                    child: _filteredProducts.isEmpty
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _products.isEmpty
                                ? 'No products found.\nAdd your first product to get started!'
                                : 'No products match your search.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                        : Padding(
                      padding: const EdgeInsets.all(12),
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          return _buildProductCard(_filteredProducts[index]);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Form Section
            _buildForm(),
          ],
        ),
      ),
    );
  }
}