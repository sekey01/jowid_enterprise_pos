import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:io';

// Model Classes
class Product {
  final int? id;
  final String name;
  final String description;
  final double price;
  final double wholesalePrice;
  final int stockQuantity;
  final String category;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.wholesalePrice,
    required this.stockQuantity,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'wholesale_price': wholesalePrice,
      'stock_quantity': stockQuantity,
      'category': category,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id']?.toInt(),
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      wholesalePrice: (map['wholesale_price'] ?? 0).toDouble(),
      stockQuantity: map['stock_quantity']?.toInt() ?? 0,
      category: map['category'] ?? '',
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Product copyWith({
    int? id,
    String? name,
    String? description,
    double? price,
    double? wholesalePrice,
    int? stockQuantity,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class Customer {
  final int? id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final DateTime createdAt;

  Customer({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id']?.toInt(),
      name: map['name'] ?? '',
      phone: map['phone'],
      email: map['email'],
      address: map['address'],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    DateTime? createdAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class Sale {
  final int? id;
  final int? customerId;
  final double totalAmount;
  final DateTime saleDate;
  final String paymentMethod;

  Sale({
    this.id,
    this.customerId,
    required this.totalAmount,
    required this.saleDate,
    required this.paymentMethod,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'total_amount': totalAmount,
      'sale_date': saleDate.toIso8601String(),
      'payment_method': paymentMethod,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id']?.toInt(),
      customerId: map['customer_id']?.toInt(),
      totalAmount: (map['total_amount'] ?? 0).toDouble(),
      saleDate: DateTime.parse(map['sale_date'] ?? DateTime.now().toIso8601String()),
      paymentMethod: map['payment_method'] ?? 'Cash',
    );
  }

  Sale copyWith({
    int? id,
    int? customerId,
    double? totalAmount,
    DateTime? saleDate,
    String? paymentMethod,
  }) {
    return Sale(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      totalAmount: totalAmount ?? this.totalAmount,
      saleDate: saleDate ?? this.saleDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}

class SaleItem {
  final int? id;
  final int saleId;
  final int productId;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  SaleItem({
    this.id,
    required this.saleId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'subtotal': subtotal,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id']?.toInt(),
      saleId: map['sale_id']?.toInt() ?? 0,
      productId: map['product_id']?.toInt() ?? 0,
      quantity: map['quantity']?.toInt() ?? 0,
      unitPrice: (map['unit_price'] ?? 0).toDouble(),
      subtotal: (map['subtotal'] ?? 0).toDouble(),
    );
  }

  SaleItem copyWith({
    int? id,
    int? saleId,
    int? productId,
    int? quantity,
    double? unitPrice,
    double? subtotal,
  }) {
    return SaleItem(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      subtotal: subtotal ?? this.subtotal,
    );
  }
}

// ProductReturn Model Class
class ProductReturn {
  final int? id;
  final int saleId;
  final int productId;
  final int quantity;
  final double unitPrice;
  final double totalAmount;
  final String reason;
  final DateTime returnDate;
  final String status;
  final String? notes;

  ProductReturn({
    this.id,
    required this.saleId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    required this.reason,
    required this.returnDate,
    required this.status,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_amount': totalAmount,
      'reason': reason,
      'return_date': returnDate.toIso8601String(),
      'status': status,
      'notes': notes,
    };
  }

  factory ProductReturn.fromMap(Map<String, dynamic> map) {
    return ProductReturn(
      id: map['id']?.toInt(),
      saleId: map['sale_id']?.toInt() ?? 0,
      productId: map['product_id']?.toInt() ?? 0,
      quantity: map['quantity']?.toInt() ?? 0,
      unitPrice: (map['unit_price'] ?? 0).toDouble(),
      totalAmount: (map['total_amount'] ?? 0).toDouble(),
      reason: map['reason'] ?? '',
      returnDate: DateTime.parse(map['return_date'] ?? DateTime.now().toIso8601String()),
      status: map['status'] ?? 'Pending',
      notes: map['notes'],
    );
  }

  ProductReturn copyWith({
    int? id,
    int? saleId,
    int? productId,
    int? quantity,
    double? unitPrice,
    double? totalAmount,
    String? reason,
    DateTime? returnDate,
    String? status,
    String? notes,
  }) {
    return ProductReturn(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalAmount: totalAmount ?? this.totalAmount,
      reason: reason ?? this.reason,
      returnDate: returnDate ?? this.returnDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }
}

// Database Helper Class
class DatabaseHelper extends ChangeNotifier {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static bool _isInitialized = false;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  // Initialize the database factory
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize sqflite for desktop platforms
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    _isInitialized = true;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;

    // Ensure initialization
    await initialize();

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      String path = join(await getDatabasesPath(), 'jowid_shop.db');
      return await openDatabase(
        path,
        version: 3, // Increased version to handle returns table
        onCreate: _createDatabase,
        onUpgrade: _upgradeDatabase,
      );
    } catch (e) {
      debugPrint('Error initializing database: $e');
      rethrow;
    }
  }

  Future<void> _createDatabase(Database db, int version) async {
    // Create Products table with wholesale_price
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        price REAL NOT NULL,
        wholesale_price REAL NOT NULL DEFAULT 0.0,
        stock_quantity INTEGER NOT NULL DEFAULT 0,
        category TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create Customers table
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Create Sales table
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER,
        total_amount REAL NOT NULL,
        sale_date TEXT NOT NULL,
        payment_method TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id)
      )
    ''');

    // Create SaleItems table
    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // Create Returns table
    await db.execute('''
      CREATE TABLE product_returns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        total_amount REAL NOT NULL,
        reason TEXT NOT NULL,
        return_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'Pending',
        notes TEXT,
        FOREIGN KEY (sale_id) REFERENCES sales (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_products_name ON products(name)');
    await db.execute('CREATE INDEX idx_products_category ON products(category)');
    await db.execute('CREATE INDEX idx_sales_date ON sales(sale_date)');
    await db.execute('CREATE INDEX idx_sale_items_sale_id ON sale_items(sale_id)');
    await db.execute('CREATE INDEX idx_sale_items_product_id ON sale_items(product_id)');
    await db.execute('CREATE INDEX idx_returns_date ON product_returns(return_date)');
    await db.execute('CREATE INDEX idx_returns_sale_id ON product_returns(sale_id)');
    await db.execute('CREATE INDEX idx_returns_product_id ON product_returns(product_id)');
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add wholesale_price column if it doesn't exist
      try {
        await db.execute('ALTER TABLE products ADD COLUMN wholesale_price REAL NOT NULL DEFAULT 0.0');
      } catch (e) {
        // Column might already exist, ignore error
        debugPrint('Error adding wholesale_price column: $e');
      }
    }

    if (oldVersion < 3) {
      // Add returns table
      try {
        await db.execute('''
          CREATE TABLE product_returns (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sale_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            quantity INTEGER NOT NULL,
            unit_price REAL NOT NULL,
            total_amount REAL NOT NULL,
            reason TEXT NOT NULL,
            return_date TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'Pending',
            notes TEXT,
            FOREIGN KEY (sale_id) REFERENCES sales (id),
            FOREIGN KEY (product_id) REFERENCES products (id)
          )
        ''');

        // Add indexes for returns table
        await db.execute('CREATE INDEX idx_returns_date ON product_returns(return_date)');
        await db.execute('CREATE INDEX idx_returns_sale_id ON product_returns(sale_id)');
        await db.execute('CREATE INDEX idx_returns_product_id ON product_returns(product_id)');
      } catch (e) {
        debugPrint('Error creating returns table: $e');
      }
    }
  }

  // PRODUCT OPERATIONS

  Future<int> insertProduct(Product product) async {
    try {
      final db = await database;
      final id = await db.insert('products', product.toMap());
      notifyListeners();
      return id;
    } catch (e) {
      debugPrint('Error inserting product: $e');
      rethrow;
    }
  }

  Future<List<Product>> getAllProducts() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'products',
        orderBy: 'name ASC',
      );
      return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
    } catch (e) {
      debugPrint('Error getting all products: $e');
      return [];
    }
  }

  Future<Product?> getProductById(int id) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        return Product.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting product by id: $e');
      return null;
    }
  }

  Future<List<Product>> searchProducts(String query) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'products',
        where: 'name LIKE ? OR description LIKE ? OR category LIKE ?',
        whereArgs: ['%$query%', '%$query%', '%$query%'],
        orderBy: 'name ASC',
      );
      return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
    } catch (e) {
      debugPrint('Error searching products: $e');
      return [];
    }
  }

  Future<List<Product>> getProductsByCategory(String category) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'products',
        where: 'category = ?',
        whereArgs: [category],
        orderBy: 'name ASC',
      );
      return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
    } catch (e) {
      debugPrint('Error getting products by category: $e');
      return [];
    }
  }

  Future<List<Product>> getLowStockProducts(int threshold) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'products',
        where: 'stock_quantity <= ?',
        whereArgs: [threshold],
        orderBy: 'stock_quantity ASC',
      );
      return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
    } catch (e) {
      debugPrint('Error getting low stock products: $e');
      return [];
    }
  }

  Future<int> updateProduct(Product product) async {
    try {
      final db = await database;
      final updatedProduct = product.copyWith(updatedAt: DateTime.now());
      final result = await db.update(
        'products',
        updatedProduct.toMap(),
        where: 'id = ?',
        whereArgs: [product.id],
      );
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('Error updating product: $e');
      rethrow;
    }
  }

  Future<int> updateProductStock(int productId, int newQuantity) async {
    try {
      final db = await database;
      final result = await db.update(
        'products',
        {
          'stock_quantity': newQuantity,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [productId],
      );
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('Error updating product stock: $e');
      rethrow;
    }
  }

  Future<int> deleteProduct(int id) async {
    try {
      final db = await database;
      final result = await db.delete(
        'products',
        where: 'id = ?',
        whereArgs: [id],
      );
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('Error deleting product: $e');
      rethrow;
    }
  }

  // CUSTOMER OPERATIONS

  Future<int> insertCustomer(Customer customer) async {
    try {
      final db = await database;
      final id = await db.insert('customers', customer.toMap());
      notifyListeners();
      return id;
    } catch (e) {
      debugPrint('Error inserting customer: $e');
      rethrow;
    }
  }

  Future<List<Customer>> getAllCustomers() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'customers',
        orderBy: 'name ASC',
      );
      return List.generate(maps.length, (i) => Customer.fromMap(maps[i]));
    } catch (e) {
      debugPrint('Error getting all customers: $e');
      return [];
    }
  }

  Future<Customer?> getCustomerById(int id) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'customers',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        return Customer.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting customer by id: $e');
      return null;
    }
  }

  Future<List<Customer>> searchCustomers(String query) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'customers',
        where: 'name LIKE ? OR phone LIKE ? OR email LIKE ?',
        whereArgs: ['%$query%', '%$query%', '%$query%'],
        orderBy: 'name ASC',
      );
      return List.generate(maps.length, (i) => Customer.fromMap(maps[i]));
    } catch (e) {
      debugPrint('Error searching customers: $e');
      return [];
    }
  }

  Future<int> updateCustomer(Customer customer) async {
    try {
      final db = await database;
      final result = await db.update(
        'customers',
        customer.toMap(),
        where: 'id = ?',
        whereArgs: [customer.id],
      );
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('Error updating customer: $e');
      rethrow;
    }
  }

  Future<int> deleteCustomer(int id) async {
    try {
      final db = await database;
      final result = await db.delete(
        'customers',
        where: 'id = ?',
        whereArgs: [id],
      );
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('Error deleting customer: $e');
      rethrow;
    }
  }

  // SALES OPERATIONS

  Future<int> insertSale(Sale sale) async {
    try {
      final db = await database;
      final id = await db.insert('sales', sale.toMap());
      notifyListeners();
      return id;
    } catch (e) {
      debugPrint('Error inserting sale: $e');
      rethrow;
    }
  }

  Future<int> insertSaleItem(SaleItem saleItem) async {
    try {
      final db = await database;
      return await db.insert('sale_items', saleItem.toMap());
    } catch (e) {
      debugPrint('Error inserting sale item: $e');
      rethrow;
    }
  }

  Future<int> processSale(Sale sale, List<SaleItem> saleItems) async {
    final db = await database;
    int saleId = 0;

    try {
      await db.transaction((txn) async {
        // Insert sale
        saleId = await txn.insert('sales', sale.toMap());

        // Insert sale items and update stock
        for (SaleItem item in saleItems) {
          final itemWithSaleId = item.copyWith(saleId: saleId);

          await txn.insert('sale_items', itemWithSaleId.toMap());

          // Update product stock
          await txn.rawUpdate(
            'UPDATE products SET stock_quantity = stock_quantity - ?, updated_at = ? WHERE id = ?',
            [item.quantity, DateTime.now().toIso8601String(), item.productId],
          );
        }
      });

      notifyListeners();
      return saleId;
    } catch (e) {
      debugPrint('Error processing sale: $e');
      rethrow;
    }
  }

  Future<List<Sale>> getAllSales() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'sales',
        orderBy: 'sale_date DESC',
      );
      return List.generate(maps.length, (i) => Sale.fromMap(maps[i]));
    } catch (e) {
      debugPrint('Error getting all sales: $e');
      return [];
    }
  }

  Future<List<Sale>> getSalesByDateRange(DateTime startDate, DateTime endDate) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'sales',
        where: 'sale_date BETWEEN ? AND ?',
        whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
        orderBy: 'sale_date DESC',
      );
      return List.generate(maps.length, (i) => Sale.fromMap(maps[i]));
    } catch (e) {
      debugPrint('Error getting sales by date range: $e');
      return [];
    }
  }

  Future<List<SaleItem>> getSaleItems(int saleId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );
      return List.generate(maps.length, (i) => SaleItem.fromMap(maps[i]));
    } catch (e) {
      debugPrint('Error getting sale items: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSaleWithItems(int saleId) async {
    try {
      final db = await database;
      return await db.rawQuery('''
        SELECT 
          si.*, 
          p.name as product_name,
          p.description as product_description,
          p.category as product_category
        FROM sale_items si
        JOIN products p ON si.product_id = p.id
        WHERE si.sale_id = ?
        ORDER BY p.name ASC
      ''', [saleId]);
    } catch (e) {
      debugPrint('Error getting sale with items: $e');
      return [];
    }
  }

  // RETURNS OPERATIONS

  Future<int> insertReturn(ProductReturn productReturn) async {
    try {
      final db = await database;
      final id = await db.insert('product_returns', productReturn.toMap());
      notifyListeners();
      return id;
    } catch (e) {
      debugPrint('Error inserting return: $e');
      rethrow;
    }
  }

  Future<int> processReturn(ProductReturn productReturn) async {
    final db = await database;
    int returnId = 0;

    try {
      await db.transaction((txn) async {
        // Insert return record
        returnId = await txn.insert('product_returns', productReturn.toMap());

        // Update product stock (add back the returned quantity)
        await txn.rawUpdate(
          'UPDATE products SET stock_quantity = stock_quantity + ?, updated_at = ? WHERE id = ?',
          [productReturn.quantity, DateTime.now().toIso8601String(), productReturn.productId],
        );
      });

      notifyListeners();
      return returnId;
    } catch (e) {
      debugPrint('Error processing return: $e');
      rethrow;
    }
  }

  Future<List<ProductReturn>> getAllReturns() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'product_returns',
        orderBy: 'return_date DESC',
      );
      return List.generate(maps.length, (i) => ProductReturn.fromMap(maps[i]));
    } catch (e) {
      debugPrint('Error getting all returns: $e');
      return [];
    }
  }

  Future<List<ProductReturn>> getReturnsByDateRange(DateTime startDate, DateTime endDate) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'product_returns',
        where: 'return_date BETWEEN ? AND ?',
        whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
        orderBy: 'return_date DESC',
      );
      return List.generate(maps.length, (i) => ProductReturn.fromMap(maps[i]));
    } catch (e) {
      debugPrint('Error getting returns by date range: $e');
      return [];
    }
  }

  Future<List<ProductReturn>> getReturnsBySaleId(int saleId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'product_returns',
        where: 'sale_id = ?',
        whereArgs: [saleId],
        orderBy: 'return_date DESC',
      );
      return List.generate(maps.length, (i) => ProductReturn.fromMap(maps[i]));
    } catch (e) {
      debugPrint('Error getting returns by sale id: $e');
      return [];
    }
  }

  Future<List<ProductReturn>> getReturnsByProductId(int productId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'product_returns',
        where: 'product_id = ?',
        whereArgs: [productId],
        orderBy: 'return_date DESC',
      );
      return List.generate(maps.length, (i) => ProductReturn.fromMap(maps[i]));
    } catch (e) {
      debugPrint('Error getting returns by product id: $e');
      return [];
    }
  }

  Future<ProductReturn?> getReturnById(int id) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'product_returns',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        return ProductReturn.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting return by id: $e');
      return null;
    }
  }

  Future<int> updateReturnStatus(int returnId, String status, {String? notes}) async {
    try {
      final db = await database;
      final updateData = {
        'status': status,
      };

      if (notes != null) {
        updateData['notes'] = notes;
      }

      final result = await db.update(
        'product_returns',
        updateData,
        where: 'id = ?',
        whereArgs: [returnId],
      );
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('Error updating return status: $e');
      rethrow;
    }
  }

  Future<int> deleteReturn(int id) async {
    try {
      final db = await database;
      final result = await db.delete(
        'product_returns',
        where: 'id = ?',
        whereArgs: [id],
      );
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('Error deleting return: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getReturnWithDetails(int returnId) async {
    try {
      final db = await database;
      return await db.rawQuery('''
        SELECT 
          pr.*,
          p.name as product_name,
          p.description as product_description,
          p.category as product_category,
          s.sale_date,
          s.payment_method
        FROM product_returns pr
        JOIN products p ON pr.product_id = p.id
        JOIN sales s ON pr.sale_id = s.id
        WHERE pr.id = ?
      ''', [returnId]);
    } catch (e) {
      debugPrint('Error getting return with details: $e');
      return [];
    }
  }

  // REPORTING FUNCTIONS

  Future<Map<String, dynamic>> getDailySalesReport(DateTime date) async {
    try {
      final db = await database;
      final startDate = DateTime(date.year, date.month, date.day);
      final endDate = startDate.add(const Duration(days: 1));

      final result = await db.rawQuery('''
        SELECT 
          COUNT(*) as total_transactions,
          COALESCE(SUM(total_amount), 0) as total_sales,
          COALESCE(AVG(total_amount), 0) as average_sale
        FROM sales
        WHERE sale_date >= ? AND sale_date < ?
      ''', [startDate.toIso8601String(), endDate.toIso8601String()]);

      return result.first;
    } catch (e) {
      debugPrint('Error getting daily sales report: $e');
      return {'total_transactions': 0, 'total_sales': 0.0, 'average_sale': 0.0};
    }
  }

  Future<Map<String, dynamic>> getWeeklySalesReport(DateTime startDate) async {
    try {
      final db = await database;
      final endDate = startDate.add(const Duration(days: 7));

      final result = await db.rawQuery('''
        SELECT 
          COUNT(*) as total_transactions,
          COALESCE(SUM(total_amount), 0) as total_sales,
          COALESCE(AVG(total_amount), 0) as average_sale
        FROM sales
        WHERE sale_date >= ? AND sale_date < ?
      ''', [startDate.toIso8601String(), endDate.toIso8601String()]);

      return result.first;
    } catch (e) {
      debugPrint('Error getting weekly sales report: $e');
      return {'total_transactions': 0, 'total_sales': 0.0, 'average_sale': 0.0};
    }
  }

  Future<Map<String, dynamic>> getReturnsReport(DateTime? startDate, DateTime? endDate) async {
    try {
      final db = await database;
      String whereClause = '';
      List<dynamic> whereArgs = [];

      if (startDate != null && endDate != null) {
        whereClause = 'WHERE return_date BETWEEN ? AND ?';
        whereArgs = [startDate.toIso8601String(), endDate.toIso8601String()];
      }

      final result = await db.rawQuery('''
        SELECT 
          COUNT(*) as total_returns,
          COALESCE(SUM(total_amount), 0) as total_return_amount,
          COALESCE(SUM(quantity), 0) as total_quantity_returned,
          COALESCE(AVG(total_amount), 0) as average_return_amount
        FROM product_returns
        $whereClause
      ''', whereArgs);

      return result.first;
    } catch (e) {
      debugPrint('Error getting returns report: $e');
      return {
        'total_returns': 0,
        'total_return_amount': 0.0,
        'total_quantity_returned': 0,
        'average_return_amount': 0.0
      };
    }
  }

  Future<List<Map<String, dynamic>>> getTopReturnedProducts(int limit) async {
    try {
      final db = await database;
      return await db.rawQuery('''
        SELECT 
          p.id,
          p.name,
          p.category,
          COALESCE(SUM(pr.quantity), 0) as total_returned,
          COALESCE(SUM(pr.total_amount), 0) as total_return_amount,
          COUNT(pr.id) as return_count
        FROM products p
        LEFT JOIN product_returns pr ON p.id = pr.product_id
        WHERE pr.id IS NOT NULL
        GROUP BY p.id, p.name, p.category
        ORDER BY total_returned DESC
        LIMIT ?
      ''', [limit]);
    } catch (e) {
      debugPrint('Error getting top returned products: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getReturnsByReason() async {
    try {
      final db = await database;
      return await db.rawQuery('''
        SELECT 
          reason,
          COUNT(*) as return_count,
          COALESCE(SUM(total_amount), 0) as total_amount,
          COALESCE(SUM(quantity), 0) as total_quantity
        FROM product_returns
        GROUP BY reason
        ORDER BY return_count DESC
      ''');
    } catch (e) {
      debugPrint('Error getting returns by reason: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTopSellingProducts(int limit) async {
    try {
      final db = await database;
      return await db.rawQuery('''
        SELECT 
          p.id,
          p.name,
          p.category,
          COALESCE(SUM(si.quantity), 0) as total_sold,
          COALESCE(SUM(si.subtotal), 0) as total_revenue
        FROM products p
        LEFT JOIN sale_items si ON p.id = si.product_id
        GROUP BY p.id, p.name, p.category
        ORDER BY total_sold DESC
        LIMIT ?
      ''', [limit]);
    } catch (e) {
      debugPrint('Error getting top selling products: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSalesByPaymentMethod() async {
    try {
      final db = await database;
      return await db.rawQuery('''
        SELECT 
          payment_method,
          COUNT(*) as transaction_count,
          COALESCE(SUM(total_amount), 0) as total_amount
        FROM sales
        GROUP BY payment_method
        ORDER BY total_amount DESC
      ''');
    } catch (e) {
      debugPrint('Error getting sales by payment method: $e');
      return [];
    }
  }

  Future<double> getTotalRevenue() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COALESCE(SUM(total_amount), 0) as total FROM sales');
      return (result.first['total'] as num).toDouble();
    } catch (e) {
      debugPrint('Error getting total revenue: $e');
      return 0.0;
    }
  }

  Future<double> getTotalReturns() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COALESCE(SUM(total_amount), 0) as total FROM product_returns');
      return (result.first['total'] as num).toDouble();
    } catch (e) {
      debugPrint('Error getting total returns: $e');
      return 0.0;
    }
  }

  Future<double> getNetRevenue() async {
    try {
      final totalRevenue = await getTotalRevenue();
      final totalReturns = await getTotalReturns();
      return totalRevenue - totalReturns;
    } catch (e) {
      debugPrint('Error getting net revenue: $e');
      return 0.0;
    }
  }

  Future<int> getTotalProducts() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM products');
      return result.first['count'] as int;
    } catch (e) {
      debugPrint('Error getting total products: $e');
      return 0;
    }
  }

  Future<int> getTotalCustomers() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM customers');
      return result.first['count'] as int;
    } catch (e) {
      debugPrint('Error getting total customers: $e');
      return 0;
    }
  }

  Future<int> getTotalSales() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM sales');
      return result.first['count'] as int;
    } catch (e) {
      debugPrint('Error getting total sales: $e');
      return 0;
    }
  }

  Future<int> getTotalReturnsCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM product_returns');
      return result.first['count'] as int;
    } catch (e) {
      debugPrint('Error getting total returns count: $e');
      return 0;
    }
  }

  // UTILITY FUNCTIONS

  Future<void> closeDatabase() async {
    try {
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
    } catch (e) {
      debugPrint('Error closing database: $e');
    }
  }

  Future<void> deleteDatabase() async {
    try {
      await initialize(); // Ensure factory is initialized
      String path = join(await getDatabasesPath(), 'jowid_shop.db');
      await databaseFactory.deleteDatabase(path);
      _database = null;
    } catch (e) {
      debugPrint('Error deleting database: $e');
    }
  }

  Future<List<String>> getProductCategories() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT DISTINCT category FROM products ORDER BY category');
      return result.map((row) => row['category'] as String).toList();
    } catch (e) {
      debugPrint('Error getting product categories: $e');
      return [];
    }
  }

  Future<List<String>> getReturnReasons() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT DISTINCT reason FROM product_returns ORDER BY reason');
      return result.map((row) => row['reason'] as String).toList();
    } catch (e) {
      debugPrint('Error getting return reasons: $e');
      return [];
    }
  }

  // Check if a product can be returned (has available quantity to return)
  Future<int> getAvailableReturnQuantity(int saleId, int productId) async {
    try {
      final db = await database;

      // Get original sold quantity
      final soldResult = await db.rawQuery('''
        SELECT COALESCE(SUM(quantity), 0) as sold_quantity
        FROM sale_items
        WHERE sale_id = ? AND product_id = ?
      ''', [saleId, productId]);

      final soldQuantity = soldResult.first['sold_quantity'] as int;

      // Get already returned quantity
      final returnedResult = await db.rawQuery('''
        SELECT COALESCE(SUM(quantity), 0) as returned_quantity
        FROM product_returns
        WHERE sale_id = ? AND product_id = ?
      ''', [saleId, productId]);

      final returnedQuantity = returnedResult.first['returned_quantity'] as int;

      return soldQuantity - returnedQuantity;
    } catch (e) {
      debugPrint('Error getting available return quantity: $e');
      return 0;
    }
  }

  // Validate return before processing
  Future<bool> validateReturn(int saleId, int productId, int returnQuantity) async {
    try {
      final availableQuantity = await getAvailableReturnQuantity(saleId, productId);
      return returnQuantity > 0 && returnQuantity <= availableQuantity;
    } catch (e) {
      debugPrint('Error validating return: $e');
      return false;
    }
  }

  Future<void> clearDatabase() async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        await txn.delete('product_returns');
        await txn.delete('sale_items');
        await txn.delete('sales');
        await txn.delete('customers');
        await txn.delete('products');
      });
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing database: $e');
    }
  }

  // Advanced search for returns
  Future<List<ProductReturn>> searchReturns(String query) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT pr.*
        FROM product_returns pr
        JOIN products p ON pr.product_id = p.id
        WHERE pr.reason LIKE ? 
           OR pr.status LIKE ? 
           OR p.name LIKE ?
           OR CAST(pr.id AS TEXT) LIKE ?
           OR CAST(pr.sale_id AS TEXT) LIKE ?
        ORDER BY pr.return_date DESC
      ''', ['%$query%', '%$query%', '%$query%', '%$query%', '%$query%']);

      return List.generate(maps.length, (i) => ProductReturn.fromMap(maps[i]));
    } catch (e) {
      debugPrint('Error searching returns: $e');
      return [];
    }
  }

  // Get return rate for a specific product
  Future<double> getProductReturnRate(int productId) async {
    try {
      final db = await database;

      // Get total sold quantity
      final soldResult = await db.rawQuery('''
        SELECT COALESCE(SUM(quantity), 0) as total_sold
        FROM sale_items
        WHERE product_id = ?
      ''', [productId]);

      final totalSold = soldResult.first['total_sold'] as int;

      if (totalSold == 0) return 0.0;

      // Get total returned quantity
      final returnedResult = await db.rawQuery('''
        SELECT COALESCE(SUM(quantity), 0) as total_returned
        FROM product_returns
        WHERE product_id = ?
      ''', [productId]);

      final totalReturned = returnedResult.first['total_returned'] as int;

      return (totalReturned / totalSold) * 100; // Return as percentage
    } catch (e) {
      debugPrint('Error getting product return rate: $e');
      return 0.0;
    }
  }

  // Get overall return rate
  Future<double> getOverallReturnRate() async {
    try {
      final db = await database;

      // Get total sold items
      final soldResult = await db.rawQuery('''
        SELECT COALESCE(SUM(quantity), 0) as total_sold
        FROM sale_items
      ''');

      final totalSold = soldResult.first['total_sold'] as int;

      if (totalSold == 0) return 0.0;

      // Get total returned items
      final returnedResult = await db.rawQuery('''
        SELECT COALESCE(SUM(quantity), 0) as total_returned
        FROM product_returns
      ''');

      final totalReturned = returnedResult.first['total_returned'] as int;

      return (totalReturned / totalSold) * 100; // Return as percentage
    } catch (e) {
      debugPrint('Error getting overall return rate: $e');
      return 0.0;
    }
  }
}