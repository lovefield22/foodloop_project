import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'seller_manage.dart';
import 'approved_sellers_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final String baseUrl = 'http://172.20.10.8:8080';

  // Dashboard Data
  Map<String, dynamic> dashboardData = {
    'pendingSellers': 0,
    'approvedSellers': 0,
    'openStores': 0,
    'closedStores': 0,
    'totalStores': 0,
  };

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchDashboardData();
  }

  Future<void> fetchDashboardData() async {
    try {
      setState(() {
        isLoading = true;
      });

      // ดึงข้อมูลร้านค้าที่รอการอนุมัติ (Pending)
      final pendingResponse = await http.get(
        Uri.parse('$baseUrl/api/admin/sellers/pending'),
      );

      // ดึงข้อมูลร้านค้าที่ได้รับการอนุมัติแล้ว (Approved)
      final approvedResponse = await http.get(
        Uri.parse('$baseUrl/api/admin/sellers/approved'),
      );

      if (mounted) {
        setState(() {
          // นับจำนวนร้านค้าที่รอการอนุมัติ
          if (pendingResponse.statusCode == 200) {
            final pendingSellers = jsonDecode(pendingResponse.body) as List;
            dashboardData['pendingSellers'] = pendingSellers.length;
          }

          // นับและแยกสถานะร้านค้าที่ได้รับการอนุมัติแล้ว
          if (approvedResponse.statusCode == 200) {
            final approvedSellers = jsonDecode(approvedResponse.body) as List;
            dashboardData['approvedSellers'] = approvedSellers.length;

            // แยกนับร้านที่เปิด/ปิด จาก field isOpen
            int openCount = 0;
            int closedCount = 0;

            for (var seller in approvedSellers) {
              // ตรวจสอบสถานะเปิด/ปิดของร้าน
              final isOpen = seller['isOpen'];
              if (isOpen == true ||
                  (isOpen is String && isOpen.toLowerCase() == 'true')) {
                openCount++;
              } else {
                closedCount++;
              }
            }

            dashboardData['openStores'] = openCount;
            dashboardData['closedStores'] = closedCount;
            dashboardData['totalStores'] = approvedSellers.length;
          }

          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching dashboard data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _goToSellerManagement(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SellerManagementScreen()),
    ).then((_) => fetchDashboardData()); // Refresh data when coming back
  }

  void _goToApprovedSellers(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ApprovedSellersScreen()),
    ).then((_) => fetchDashboardData()); // Refresh data when coming back
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: const Text(
          'แดชบอร์ดผู้ดูแลระบบ',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: fetchDashboardData,
            tooltip: 'รีเฟรชข้อมูล',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Stats Summary
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade600, Colors.blue.shade800],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '🎛️ ภาพรวมระบบ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'สถิติการใช้งานทั้งหมด',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMiniStat(
                                'ร้านค้าทั้งหมด',
                                '${dashboardData['totalStores']}',
                                Icons.store,
                              ),
                              _buildMiniStat(
                                'ร้านเปิดใช้งาน',
                                '${dashboardData['openStores']}',
                                Icons.store_mall_directory,
                              ),
                              _buildMiniStat(
                                'ร้านปิดใช้งาน',
                                '${dashboardData['closedStores']}',
                                Icons.store_outlined,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      '🔧 เครื่องมือจัดการ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Dashboard Cards Grid - เฉพาะ 2 การ์ดหลัก
                    Row(
                      children: [
                        Expanded(
                          child: _DashboardCard(
                            title: 'ยืนยันร้านค้า',
                            value: '${dashboardData['pendingSellers']}',
                            subtitle: 'ร้านค้ารออนุมัติ',
                            icon: Icons.verified_user,
                            color: Colors.blue.shade50,
                            iconColor: Colors.blue.shade600,
                            onTap: () => _goToSellerManagement(context),
                            badge: dashboardData['pendingSellers'] > 0
                                ? '${dashboardData['pendingSellers']}'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _DashboardCard(
                            title: 'ระงับร้านค้า',
                            value: '${dashboardData['approvedSellers']}',
                            subtitle: 'ร้านค้าในระบบ',
                            icon: Icons.pause_circle,
                            color: Colors.orange.shade50,
                            iconColor: Colors.orange.shade600,
                            onTap: () => _goToApprovedSellers(context),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Quick Actions
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '⚡ การกระทำด่วน',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildQuickActionButton(
                                  'ยืนยันร้านค้า',
                                  Icons.verified_user,
                                  Colors.blue,
                                  () => _goToSellerManagement(context),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildQuickActionButton(
                                  'ระงับร้านค้า',
                                  Icons.pause_circle,
                                  Colors.orange,
                                  () => _goToApprovedSellers(context),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildQuickActionButton(
                                  'รีเฟรชข้อมูล',
                                  Icons.refresh,
                                  Colors.green,
                                  fetchDashboardData,
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
            ),
    );
  }

  Widget _buildMiniStat(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;
  final String? badge;

  const _DashboardCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: iconColor.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 28, color: iconColor),
                ),
                const SizedBox(height: 16),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF4A5568),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),

            // Badge notification
            if (badge != null)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
