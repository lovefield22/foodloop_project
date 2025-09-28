import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'location_picker_screen.dart'; // นำเข้าไฟล์ LocationPickerScreen
import 'search_food_screen.dart'; // เพิ่มบรรทัดนี้
import 'food_detail_screen.dart';
import 'dart:math';
import 'notification_screen.dart';
import 'notification_detail_screen.dart';
import 'profile_consumer.dart'; // ใช้ไฟล์นี้แทน profile_screen.dart
import 'my_orders_screen.dart';
import 'order_from.dart';
import 'cart_screen.dart';

class ConsumerHomeScreen extends StatefulWidget {
  final int consumerId;
  final String username;

  const ConsumerHomeScreen({
    super.key,
    required this.consumerId,
    required this.username,
  });

  @override
  State<ConsumerHomeScreen> createState() => _ConsumerHomeScreenState();
}

class _ConsumerHomeScreenState extends State<ConsumerHomeScreen> {
  late Future<List<dynamic>> featuredDealsFuture;
  late Future<List<dynamic>> nearbyDealsFuture;
  late Future<List<dynamic>> notificationsFuture; // เพิ่มกลับมา

  String locationName = "Chiangmai meajo";
  double? selectedLat, selectedLng;
  double radiusKm = 10;
  int unreadCount = 0; // เพิ่มกลับมา
  int _currentIndex = 0;

  List<Map<String, dynamic>> selectedFoods = [];

  @override
  void initState() {
    super.initState();
    featuredDealsFuture = fetchFeaturedDeals();
    // ไม่ต้อง set nearbyDealsFuture ตอนแรก
    // nearbyDealsFuture = fetchNearbyDeals();
    notificationsFuture = fetchLatestNotifications(); // เพิ่มกลับมา
    fetchUnreadCount(); // เพิ่มกลับมา
  }

  Future<List<dynamic>> fetchFeaturedDeals() async {
    final response = await http.get(
      Uri.parse('http://172.20.10.8:8080/api/food/filter?status=active'),
    );
    if (response.statusCode == 200) {
      final List<dynamic> foods = jsonDecode(response.body);
      // filter เฉพาะที่มีส่วนลด (โปรโมชั่น) และจำนวนมากกว่า 0
      return foods
          .where(
            (f) =>
                (f['discount'] ?? 0) > 0 &&
                (f['quantity'] ?? 0) > 0 &&
                (f['status'] ?? '').toLowerCase() == 'active',
          )
          .toList();
    } else {
      throw Exception('ไม่สามารถโหลดโปรโมชั่นแนะนำได้');
    }
  }

  // แก้ไขฟังก์ชัน fetchNearbyDeals
  Future<List<dynamic>> fetchNearbyDeals({
    double? lat,
    double? lng,
    double? radius,
  }) async {
    if (lat == null || lng == null) {
      final response = await http.get(
        Uri.parse('http://172.20.10.8:8080/api/food/filter?status=active'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> foods = jsonDecode(response.body);
        // filter เฉพาะ active, ร้านเปิดอยู่, และจำนวนมากกว่า 0
        return foods
            .where(
              (food) =>
                  (food['status'] ?? '').toString().toLowerCase() == 'active' &&
                  (food['seller']?['isOpen'] ?? true) == true &&
                  (food['quantity'] ?? 0) > 0,
            )
            .toList();
      } else {
        throw Exception('ไม่สามารถโหลดร้านค้าใกล้เคียงได้');
      }
    }

    final url = Uri.parse(
      'http://172.20.10.8:8080/api/food/getNearbyFoods?lat=$lat&lng=$lng&radiusKm=${radius ?? 10}',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> foods = jsonDecode(response.body);
      // filter เฉพาะ active, ร้านเปิดอยู่, และจำนวนมากกว่า 0
      return foods
          .where(
            (food) =>
                (food['status'] ?? '').toString().toLowerCase() == 'active' &&
                (food['seller']?['isOpen'] ?? true) == true &&
                (food['quantity'] ?? 0) > 0,
          )
          .toList();
    } else {
      throw Exception('ไม่สามารถโหลดร้านค้าใกล้เคียงได้');
    }
  }

  // ฟังก์ชันดึงแจ้งเตือนล่าสุด
  Future<List<dynamic>> fetchLatestNotifications() async {
    try {
      final response = await http.get(
        Uri.parse(
          'http://172.20.10.8:8080/api/notifications/consumer/${widget.consumerId}',
        ),
      );
      if (response.statusCode == 200) {
        List<dynamic> notifications = jsonDecode(
          utf8.decode(response.bodyBytes),
        );

      
        

        return notifications.take(4).toList(); // เอาแค่ 4 รายการล่าสุด
      } else {
        print('Error: HTTP ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching notifications: $e');
      return [];
    }
  }

  Future<void> fetchUnreadCount() async {
    final response = await http.get(
      Uri.parse(
        'http://172.20.10.8:8080/api/notifications/unread-count/${widget.consumerId}',
      ),
    );
    if (response.statusCode == 200) {
      setState(() {
        unreadCount = int.tryParse(response.body) ?? 0;
      });
    }
  }

  String fixImageUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return '';
    if (rawUrl.startsWith('http')) return rawUrl;
    if (!rawUrl.startsWith('/')) rawUrl = '/$rawUrl';
    const baseUrl = 'http://172.20.10.8:8080';
    return '$baseUrl$rawUrl';
  }

  String timeLeft(String? isoString) {
    if (isoString == null) return '';
    final created = DateTime.tryParse(isoString);
    if (created == null) return '';
    final expire = created.add(const Duration(days: 1));
    final diff = expire.difference(DateTime.now());
    if (diff.isNegative) return 'หมดอายุแล้ว';
    if (diff.inHours > 0) return 'เหลืออีก ${diff.inHours} ชม.';
    if (diff.inMinutes > 0) return 'เหลืออีก ${diff.inMinutes} นาที';
    return 'หมดอายุแล้ว';
  }

  double calculateDistanceKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const R = 6371;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  // เพิ่มฟังก์ชันสำหรับเพิ่มอาหารลงตะกร้า - แก้ไขให้สมบูรณ์
  void addToCart(Map<String, dynamic> food) async {
    // ดึง sellerId ของสินค้าใหม่
    final newSellerId = _getSellerId(food);

    if (selectedFoods.isNotEmpty) {
      // ดึง sellerId ของสินค้าแรกในตะกร้า
      final currentSellerId = _getSellerId(selectedFoods.first);

      // เช็คว่าเป็นคนละร้านหรือไม่
      if (newSellerId != currentSellerId) {
        // แสดง dialog ยืนยันการเปลี่ยนร้าน
        final shouldChangeStore = await _showStoreChangeDialog(
          currentStoreName: _getStoreName(selectedFoods.first),
          newStoreName: _getStoreName(food),
        );

        if (shouldChangeStore == true) {
          // ลบสินค้าทั้งหมดและเพิ่มสินค้าใหม่
          setState(() {
            selectedFoods.clear();
            selectedFoods.add(food);
          });
          _showSuccessMessage('เปลี่ยนร้านและเพิ่มสินค้าสำเร็จ');
        } else {
          // ยกเลิกการเพิ่มสินค้า
          _showCancelMessage('ยกเลิกการเพิ่มสินค้า');
        }
        return;
      }
    }

    // ตรวจสอบว่ามีสินค้านี้ในตะกร้าแล้วหรือไม่
    final existingIndex = selectedFoods.indexWhere(
      (item) => item['foodItemId'] == food['foodItemId'],
    );

    setState(() {
      if (existingIndex >= 0) {
        // เพิ่มจำนวนสินค้าที่มีอยู่แล้ว
        selectedFoods[existingIndex]['quantity'] =
            (selectedFoods[existingIndex]['quantity'] ?? 1) +
            (food['quantity'] ?? 1);
      } else {
        // เพิ่มสินค้าใหม่
        selectedFoods.add(food);
      }
    });

    _showSuccessMessage('เพิ่มลงตะกร้าแล้ว');
  }

  // ฟังก์ชันช่วยดึง sellerId
  int? _getSellerId(Map<String, dynamic> food) {
    // ลองดึงจากหลายๆ ที่
    if (food['sellerId'] != null) return food['sellerId'] as int?;
    if (food['seller'] != null && food['seller']['sellerId'] != null) {
      return food['seller']['sellerId'] as int?;
    }
    if (food['seller'] != null && food['seller']['id'] != null) {
      return food['seller']['id'] as int?;
    }
    return null;
  }

  // ฟังก์ชันช่วยดึงชื่อร้าน
  String _getStoreName(Map<String, dynamic> food) {
    if (food['seller'] != null) {
      final seller = food['seller'];
      return seller['storename'] ??
          seller['shopName'] ??
          seller['name'] ??
          'ร้านไม่ระบุชื่อ';
    }
    return 'ร้านไม่ระบุชื่อ';
  }

  // แสดง dialog ยืนยันการเปลี่ยนร้าน - ปรับปรุงให้สวยงาม
  Future<bool?> _showStoreChangeDialog({
    required String currentStoreName,
    required String newStoreName,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 24, horizontal: 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade400, Colors.red.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.swap_horiz,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'เปลี่ยนร้านค้า?',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Current store card
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.shopping_cart,
                                    color: Colors.red.shade600,
                                    size: 20,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ตะกร้าปัจจุบัน',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.red.shade600,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        currentStoreName,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'จำนวน ${selectedFoods.length} รายการ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 16),

                      // Arrow down
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_downward_rounded,
                          color: Colors.orange.shade600,
                          size: 24,
                        ),
                      ),

                      SizedBox(height: 16),

                      // New store card
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.store,
                                color: Colors.green.shade600,
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ร้านใหม่ที่ต้องการ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    newStoreName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 20),

                      // Warning message
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.amber.shade700,
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'คำเตือน',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade800,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'สินค้าในตะกร้าจากร้านเดิมจะถูกลบออกทั้งหมด',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.amber.shade700,
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
                ),

                // Action buttons
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          child: Text(
                            'ยกเลิก',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade500,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'เปลี่ยนร้าน',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // แสดงข้อความสำเร็จ
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // แสดงข้อความยกเลิก
  void _showCancelMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.cancel, color: Colors.white),
            SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 56), // ใหญ่ขึ้น
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () {
                  if (selectedFoods.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ตะกร้าว่างเปล่า')),
                    );
                    return;
                  }
                  // ไปหน้า CartScreen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CartScreen(
                        cartItems: selectedFoods,
                        consumerId: widget.consumerId,
                        onCartUpdated: (updatedCart) {
                          setState(() {
                            selectedFoods = updatedCart;
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
              if (selectedFoods.isNotEmpty)
                Positioned(
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: BoxConstraints(minWidth: 20, minHeight: 20),
                    child: Text(
                      '${selectedFoods.length}',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        children: [
          // Welcome Banner - ทำให้คลิกได้เพื่อไปตั้งค่าตำแหน่ง
          GestureDetector(
            onTap: () async {
              // ไปหน้า Location Picker เพื่อตั้งค่าตำแหน่ง
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LocationPickerScreen(
                    consumerId: widget.consumerId.toString(),
                    initialLat: selectedLat,
                    initialLng: selectedLng,
                    initialRadius: radiusKm,
                  ),
                ),
              );

              if (result != null && result is Map<String, dynamic>) {
                setState(() {
                  selectedLat = result['lat'];
                  selectedLng = result['lng'];
                  locationName = result['locationName'] ?? 'ตำแหน่งที่เลือก';
                  radiusKm = result['radius'] ?? 10;
                  // อัพเดทข้อมูลร้านค้าใกล้เคียงใหม่
                  nearbyDealsFuture = fetchNearbyDeals(
                    lat: selectedLat,
                    lng: selectedLng,
                    radius: radiusKm,
                  );
                });

                // แสดงข้อความแจ้งเตือนว่าอัพเดทตำแหน่งแล้ว
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.white),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '📍 อัพเดทตำแหน่งเป็น "$locationName" แล้ว',
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'สวัสดี, ${widget.username}! 👋',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // แสดงไอคอนบอกว่าคลิกได้
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.location_searching,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ค้นหาโปรโมชั่นอาหารอร่อยใกล้คุณ',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'แตะที่นี่เพื่อตั้งค่าตำแหน่งและดูโปรโมชั่นใกล้เคียง!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

         
               

  // เพิ่มฟังก์ชันแก้ไข URL รูปโปรไฟล์
  String _fixSellerImageUrl(String imageUrl) {
    if (imageUrl.isEmpty) return '';
    if (imageUrl.startsWith('http')) return imageUrl;
    if (!imageUrl.startsWith('/')) imageUrl = '/$imageUrl';
    return 'http://172.20.10.8:8080$imageUrl';
  }

  Widget _buildNearbyDealCard(dynamic food) {
    final imageUrl = fixImageUrl(food['urlImage']);
    final price = food['price'] ?? '';
    final seller = food['seller'];
    String timeStr = '-';
    String distanceStr = '-';

    // แปลงชื่ออาหารให้เป็น utf-8
    final foodName = food['name'] != null
        ? utf8.decode((food['name'] as String).codeUnits)
        : '-';

    // เวลา
    if (food['createdAt'] != null) {
      timeStr = timeLeft(food['createdAt']);
    }

    // ระยะทาง
    final sellerLat = seller != null ? getSellerLat(seller) : null;
    final sellerLng = seller != null ? getSellerLng(seller) : null;
    try {
      if (sellerLat != null &&
          sellerLng != null &&
          selectedLat != null &&
          selectedLng != null) {
        final dist = calculateDistanceKm(
          selectedLat!,
          selectedLng!,
          sellerLat,
          sellerLng,
        );
        distanceStr = '${dist.toStringAsFixed(2)} km';
      }
    } catch (e) {
      distanceStr = '-';
    }

    print('seller: $seller');

    return GestureDetector(
      onTap: () async {
        final cartItem = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FoodDetailScreen(
              foodItemId: food['foodItemId'],
              userLat: selectedLat,
              userLng: selectedLng,
              consumerId: widget.consumerId,
            ),
          ),
        );
        if (cartItem != null) {
          addToCart(cartItem); // เรียกฟังก์ชันเพิ่มลงตะกร้า
        }
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: imageUrl.isEmpty
                  ? Container(
                      height: 90,
                      color: Colors.grey[200],
                      child: const Icon(Icons.fastfood, size: 40),
                    )
                  : Image.network(
                      imageUrl,
                      height: 90,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.fastfood),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    foodName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$$price',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.timer, size: 14, color: Colors.grey),
                      const SizedBox(width: 2),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        distanceStr,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double? getSellerLat(dynamic seller) {
    if (seller is Map) {
      final lat =
          seller['latitude'] ?? seller['lat'] ?? (seller['location']?['lat']);
      if (lat is num) return lat.toDouble();
      if (lat is String) return double.tryParse(lat);
    }
    return null;
  }

  double? getSellerLng(dynamic seller) {
    if (seller is Map) {
      final lng =
          seller['longitude'] ?? seller['lng'] ?? (seller['location']?['lng']);
      if (lng is num) return lng.toDouble();
      if (lng is String) return double.tryParse(lng);
    }
    return null;
  }

  // Loading state for featured deals
  Widget _buildFeaturedDealsLoading() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            width: 280,
            margin: EdgeInsets.only(right: 12),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [Colors.grey[300]!, Colors.grey[200]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          color: Colors.grey[300],
                        ),
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.green),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            SizedBox(height: 8),
                            Container(
                              height: 12,
                              width: 100,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Empty state for featured deals
  Widget _buildEmptyFeaturedDeals() {
    return Container(
      height: 200,
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_outlined, size: 48, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'ยังไม่มีอาหารโปรโมชั่น',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'กลับมาใหม่อีกครั้งในภายหลัง',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // Grid layout for featured deals
  Widget _buildFeaturedDealsGrid(List<dynamic> foods) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: foods.length,
        itemBuilder: (context, index) {
          final food = foods[index];
          return _buildFeaturedDealCard(food);
        },
      ),
    );
  }

  // Quick action card
  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Error state widget
  Widget _buildErrorState(String message) {
    return Container(
      height: 200,
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
          SizedBox(height: 16),
          Text(
            'เกิดข้อผิดพลาด',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                // Refresh data
              });
              // fetchNearbyFoods(); // Remove this undefined method call
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }

  // เพิ่มฟังก์ชันแสดงตะกร้า
  // เพิ่มฟังก์ชันคำนวณยอดรวม
  double _calculateTotal() {
    return selectedFoods.fold(
      0.0,
      (sum, item) => sum + (item['price'] * item['quantity']),
    );
  }

  // เพิ่มฟังก์ชันดำเนินการสั่งซื้อ
  void _proceedToCheckout() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderFormScreen(
          orderItems: List<Map<String, dynamic>>.from(selectedFoods),
          consumerId: widget.consumerId,
        ),
      ),
    );
  }
}

String timeAgo(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inSeconds < 60) return 'เมื่อสักครู่';
  if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
  if (diff.inHours < 24) return '${diff.inHours} ชั่วโมงที่แล้ว';
  if (diff.inDays < 7) return '${diff.inDays} วันที่แล้ว';
  return '${date.day}/${date.month}/${date.year}';
}
