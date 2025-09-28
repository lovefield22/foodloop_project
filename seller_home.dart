import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';
import 'seller_orders_screen.dart';
import 'seller_food_screen.dart';
import 'seller_profile_screen.dart';
import 'seller_analytics_screen.dart';
import 'seller_notification_screen.dart';
import 'seller_reviews_screen.dart';
import 'post_food_sceen.dart';

class SellerHomeScreen extends StatefulWidget {
  final int sellerId;
  final String sellerName;

  const SellerHomeScreen({
    super.key,
    required this.sellerId,
    required this.sellerName,
  });

  @override
  State<SellerHomeScreen> createState() => _SellerHomeScreenState();
}

class _SellerHomeScreenState extends State<SellerHomeScreen> {
  final String baseUrl = 'http://172.20.10.8:8080';

  // Dashboard Data
  Map<String, dynamic> dashboardData = {
    'todaySales': 0.0,
    'todayOrders': 0,
    'totalMenuItems': 0,
    'averageRating': 0.0,
    'pendingOrders': 0,
    'completedOrders': 0,
  };

  List<dynamic> recentOrders = [];
  List<dynamic> topMenuItems = [];
  bool isStoreOpen = true;
  bool isLoading = true;
  int unreadNotificationCount = 0;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    fetchDashboardData();
    // Auto refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      fetchDashboardData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchDashboardData() async {
    try {
      print('🔄 กำลังโหลดข้อมูล Dashboard...');

      // Fetch dashboard summary
      final dashboardResponse = await http.get(
        Uri.parse('$baseUrl/api/sellers/${widget.sellerId}/dashboard'),
      );

      // Fetch seller profile เพื่อดึงสถานะร้าน
      final sellerProfileResponse = await http.get(
        Uri.parse('$baseUrl/api/sellers/${widget.sellerId}'),
      );

      // Fetch completed orders - เอาแค่ 5 รายการที่ completed แล้ว
      final ordersResponse = await http.get(
        Uri.parse(
          '$baseUrl/api/sellers/${widget.sellerId}/completed-orders?limit=5',
        ),
      );

      // Fetch menu items ที่ Active เท่านั้น
      final menuResponse = await http.get(
        Uri.parse('$baseUrl/api/food/seller/${widget.sellerId}'),
      );

      // Fetch unread notification count
      final notificationResponse = await http.get(
        Uri.parse(
          '$baseUrl/api/notifications/seller/unread-count/${widget.sellerId}',
        ),
      );

      if (mounted) {
        setState(() {
          if (dashboardResponse.statusCode == 200) {
            dashboardData = jsonDecode(dashboardResponse.body);
            print('✅ Dashboard data loaded: $dashboardData');
          }

          // โหลดสถานะร้านจาก seller profile
          if (sellerProfileResponse.statusCode == 200) {
            final sellerProfile = jsonDecode(sellerProfileResponse.body);
            isStoreOpen = sellerProfile['isOpen'] ?? true;
            print('✅ Store status loaded: ${isStoreOpen ? "OPEN" : "CLOSED"}');
          } else {
            print(
              '❌ Seller profile API failed: ${sellerProfileResponse.statusCode}',
            );
            // เก็บสถานะเดิมไว้ถ้าดึงไม่ได้
          }

          if (ordersResponse.statusCode == 200) {
            recentOrders = jsonDecode(ordersResponse.body);
            print('✅ Recent orders loaded: ${recentOrders.length} orders');
          } else {
            print('❌ Orders API failed: ${ordersResponse.statusCode}');
            recentOrders = [];
          }

          if (menuResponse.statusCode == 200) {
            final menuItems = jsonDecode(menuResponse.body) as List;

            // กรองเฉพาะรายการที่มีสถานะ Active
            final activeMenuItems = menuItems
                .where(
                  (item) =>
                      item['status']?.toString().toLowerCase() == 'active',
                )
                .toList();

            dashboardData['totalMenuItems'] = activeMenuItems.length;

            // เอารายการ Active แค่ 3 อันดับแรกสำหรับแสดงใน Home
            topMenuItems = activeMenuItems.take(3).toList();
            print(
              '✅ Active menu items loaded: ${activeMenuItems.length} items',
            );
          } else {
            print('❌ Menu API failed: ${menuResponse.statusCode}');
            topMenuItems = [];
          }

          if (notificationResponse.statusCode == 200) {
            unreadNotificationCount =
                int.tryParse(notificationResponse.body) ?? 0;
            print('✅ Notification count loaded: $unreadNotificationCount');
          }

          isLoading = false;
        });
      }
    } catch (e) {
      print('💥 Error fetching dashboard data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ไม่สามารถโหลดข้อมูลได้ กรุณาลองใหม่อีกครั้ง',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade700,
            duration: Duration(seconds: 3),
            action: SnackBarAction(
              label: 'ลองใหม่',
              textColor: Colors.white,
              onPressed: fetchDashboardData,
            ),
          ),
        );
      }
    }
  }

  Future<void> toggleStoreStatus() async {
    try {
      print('🔄 กำลัง toggle สถานะร้าน...');

      final response = await http.patch(
        Uri.parse('$baseUrl/api/sellers/${widget.sellerId}/toggle-status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'isOpen': !isStoreOpen}),
      );

      print('📡 Toggle API Response: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        // อัพเดต state ก่อน
        setState(() {
          isStoreOpen = !isStoreOpen;
        });

        // แสดง SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isStoreOpen ? 'ร้านเปิดแล้ว 🟢' : 'ร้านปิดแล้ว 🔴'),
            backgroundColor: isStoreOpen ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );

        // 🔥 เพิ่ม: Refresh ข้อมูลจากเซิร์ฟเวอร์เพื่อให้ทุกหน้าได้ข้อมูลใหม่
        await fetchDashboardData();

        print('✅ สถานะร้านอัพเดตเป็น: ${isStoreOpen ? "OPEN" : "CLOSED"}');
      } else {
        print('❌ Failed to toggle store status: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ไม่สามารถเปลี่ยนสถานะร้านได้: ${response.statusCode}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('💥 Error toggling store status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เกิดข้อผิดพลาดในการเปลี่ยนสถานะร้าน'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchDashboardData,
              child: CustomScrollView(
                slivers: [
                  // Custom App Bar
                  SliverAppBar(
                    expandedHeight: 120,
                    floating: false,
                    pinned: true,
                    backgroundColor: Colors.green.shade600,
                    flexibleSpace: FlexibleSpaceBar(
                      title: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ยินดีต้อนรับกลับมา!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          Text(
                            widget.sellerName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.green.shade400,
                              Colors.green.shade700,
                            ],
                          ),
                        ),
                      ),
                    ),
                    actions: [
                      IconButton(
                        icon: Stack(
                          children: [
                            const Icon(Icons.notifications_outlined),
                            if (unreadNotificationCount > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    unreadNotificationCount > 9
                                        ? '9+'
                                        : '$unreadNotificationCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SellerNotificationScreen(
                                sellerId: widget.sellerId,
                              ),
                            ),
                          );
                          // Refresh notifications count after returning
                          if (result == true) {
                            fetchDashboardData();
                          }
                        },
                      ),
                    ],
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Store Status Card
                          _buildStoreStatusCard(),
                          const SizedBox(height: 16),

                          // Quick Stats
                          _buildQuickStats(),
                          const SizedBox(height: 24),

                          // Quick Actions
                          _buildQuickActions(),
                          const SizedBox(height: 24),

                          // Recent Orders
                          _buildRecentOrders(),
                          const SizedBox(height: 24),

                          // Top Menu Items
                          _buildTopMenuItems(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildStoreStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isStoreOpen
              ? [Colors.green.shade400, Colors.green.shade600]
              : [Colors.red.shade400, Colors.red.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isStoreOpen ? Colors.green : Colors.red).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isStoreOpen ? Icons.store : Icons.store_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'สถานะร้าน',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                Text(
                  isStoreOpen ? 'เปิด' : 'ปิด',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isStoreOpen,
            onChanged: (_) => toggleStoreStatus(),
            activeColor: Colors.white,
            activeTrackColor: Colors.white.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'ยอดขายวันนี้',
          '฿${dashboardData['todaySales']?.toStringAsFixed(0) ?? '0'}',
          Icons.attach_money,
          Colors.green,
        ),
        _buildStatCard(
          'ออเดอร์วันนี้',
          '${dashboardData['todayOrders'] ?? 0}',
          Icons.receipt_long,
          Colors.blue,
        ),
        _buildStatCard(
          'รายการเมนู',
          '${dashboardData['totalMenuItems'] ?? 0}',
          Icons.restaurant_menu,
          Colors.orange,
        ),
        _buildStatCard(
          'คะแนนเฉลี่ย',
          '${(dashboardData['averageRating'] ?? 0.0).toStringAsFixed(1)} ⭐',
          Icons.star,
          Colors.amber,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'การกระทำด่วน',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'เพิ่มเมนู',
                Icons.add_circle_outline,
                Colors.green,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PostFoodScreen(sellerId: widget.sellerId),
                  ),
                ).then((_) => fetchDashboardData()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'ดูคำสั่งซื้อ',
                Icons.receipt_long,
                Colors.blue,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SellerOrdersScreen(sellerId: widget.sellerId),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'สถิติ',
                Icons.analytics_outlined,
                Colors.orange,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SellerAnalyticsScreen(
                      sellerId: widget.sellerId,
                      sellerName: widget.sellerName,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'รีวิว',
                Icons.star_outline,
                Colors.amber,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SellerReviewsScreen(sellerId: widget.sellerId),
                  ),
                ),
              ),
            ),
          ],
        ),
       

  Widget _buildRecentOrders() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.receipt_long_outlined,
                      color: Colors.blue.shade600,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'คำสั่งซื้อที่สำเร็จแล้ว',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SellerOrdersScreen(sellerId: widget.sellerId),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ดูทั้งหมด',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: Colors.blue.shade700,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (recentOrders.isEmpty)
            SizedBox(
              height: 100,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 40,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ไม่มีคำสั่งซื้อที่สำเร็จ',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...recentOrders.asMap().entries.map((entry) {
              final index = entry.key;
              final order = entry.value;
              final bool isLast = index == recentOrders.length - 1;

              return Container(
                margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                ),
                child: Row(
                  children: [
                    // Order Icon with Status Color
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _getStatusColor(
                          order['status'],
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getStatusColor(
                            order['status'],
                          ).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        _getStatusIcon(order['status']),
                        color: _getStatusColor(order['status']),
                        size: 24,
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Order Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Order #${order['orderId'] ?? 'N/A'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF2D3748),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    order['status'],
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _getStatusText(order['status']),
                                  style: TextStyle(
                                    color: _getStatusColor(order['status']),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ยอดรวม ฿${NumberFormat('#,##0').format(order['totalAmount'] ?? 0)}',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _formatOrderDate(order['orderDate']),
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Action Arrow
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTopMenuItems() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.restaurant_menu_rounded,
                      color: Colors.orange.shade600,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Your Menu Items',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SellerFoodScreen(
                      sellerId: widget.sellerId,
                      sellerName: widget.sellerName,
                    ),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: Colors.orange.shade700,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (topMenuItems.isEmpty)
            SizedBox(
              height: 120,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.restaurant_outlined,
                      size: 40,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ยังไม่มีรายการอาหาร',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'เพิ่มเมนูแรกของคุณ',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 180, // เพิ่มความสูงจาก 140 เป็น 180
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: topMenuItems.length,
                itemBuilder: (context, index) {
                  final item = topMenuItems[index];
                  final bool isLast = index == topMenuItems.length - 1;

                 
                  String imageUrl = '';
                  final rawImageUrl = item['urlImage'] ?? '';
                  if (rawImageUrl.isNotEmpty) {
                    if (rawImageUrl.startsWith('http')) {
                      imageUrl = rawImageUrl;
                    } else {
                      final cleanUrl = rawImageUrl.startsWith('/')
                          ? rawImageUrl
                          : '/$rawImageUrl';
                      imageUrl = 'http://172.20.10.8:8080$cleanUrl';
                    }
                  }

                  return Container(
                    width: 150, // เพิ่มความกว้างจาก 120 เป็น 150
                    margin: EdgeInsets.only(right: isLast ? 0 : 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Food Image
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            width: double.infinity,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(15),
                              ),
                              child: imageUrl.isNotEmpty
                                  ? Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return Container(
                                          color: Colors.grey.shade100,
                                          child: Center(
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                value:
                                                    loadingProgress
                                                            .expectedTotalBytes !=
                                                        null
                                                    ? loadingProgress
                                                              .cumulativeBytesLoaded /
                                                          loadingProgress
                                                              .expectedTotalBytes!
                                                    : null,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.orange.shade50,
                                              child: Center(
                                                child: Icon(
                                                  Icons.fastfood_rounded,
                                                  color: Colors.orange.shade300,
                                                  size: 40, // เพิ่มขนาดไอคอน
                                                ),
                                              ),
                                            );
                                          },
                                    )
                                  : Container(
                                      color: Colors.orange.shade50,
                                      child: Center(
                                        child: Icon(
                                          Icons.fastfood_rounded,
                                          color: Colors.orange.shade300,
                                          size: 40, // เพิ่มขนาดไอคอน
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        // Food Details
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(14), // เพิ่ม padding
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Food Name
                                Flexible(
                                  child: Text(
                                    item['name'] ?? 'ไม่ระบุชื่อ',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14, // เพิ่มขนาดฟอนต์
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2D3748),
                                      height: 1.2,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 6),

                                // Food Price and Status
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '฿${NumberFormat('#,##0').format(item['price'] ?? 0)}',
                                        style: TextStyle(
                                          fontSize: 15, // เพิ่มขนาดฟอนต์
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.green.shade200,
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Text(
                                        'Active',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.green,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      currentIndex: 0, // Home tab is selected
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "หน้าหลัก"),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long),
          label: "ออเดอร์",
        ),
        BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: "เมนู"),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "สถิติ"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "โปรไฟล์"),
      ],
      onTap: (index) {
        switch (index) {
          case 0:
            // Already on Home
            break;
          case 1:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SellerOrdersScreen(sellerId: widget.sellerId),
              ),
            );
            break;
          case 2:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SellerFoodScreen(
                  sellerId: widget.sellerId,
                  sellerName: widget.sellerName,
                ),
              ),
            );
            break;
          case 3:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SellerAnalyticsScreen(
                  sellerId: widget.sellerId,
                  sellerName: widget.sellerName,
                ),
              ),
            );
            break;
          case 4:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SellerProfileScreen(
                  sellerId: widget.sellerId,
                  username: widget.sellerName,
                ),
              ),
            );
            break;
        }
      },
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'preparing':
        return Colors.blue;
      case 'ready':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Icons.check_circle_outline;
      case 'pending':
        return Icons.access_time_rounded;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'preparing':
        return Icons.restaurant_rounded;
      case 'ready':
        return Icons.delivery_dining_rounded;
      default:
        return Icons.receipt_outlined;
    }
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return 'เสร็จสิ้น';
      case 'pending':
        return 'รอดำเนินการ';
      case 'cancelled':
        return 'ยกเลิก';
      case 'preparing':
        return 'กำลังเตรียม';
      case 'ready':
        return 'พร้อมรับ';
      default:
        return 'ไม่ระบุ';
    }
  }

  String _formatOrderDate(dynamic orderDate) {
    try {
      if (orderDate == null) return 'ไม่ระบุวันที่';

      DateTime date;
      if (orderDate is String) {
        date = DateTime.parse(orderDate);
      } else if (orderDate is DateTime) {
        date = orderDate;
      } else {
        return 'ไม่ระบุวันที่';
      }

      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return DateFormat('HH:mm').format(date);
      } else if (difference.inDays == 1) {
        return 'เมื่อวาน ${DateFormat('HH:mm').format(date)}';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} วันที่แล้ว';
      } else {
        return DateFormat('dd/MM/yyyy').format(date);
      }
    } catch (e) {
      return 'ไม่ระบุวันที่';
    }
  }
}
