import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../profile/profile_page.dart';
import '../visit/visit_detail_page.dart';
import '../lists/list_detail_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAndMarkRead();
  }

  Future<void> _fetchAndMarkRead() async {
    try {
      final notifs = await ApiService.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifs;
          _isLoading = false;
        });
      }
      // Tandai terbaca di background
      await ApiService.markNotificationsAsRead();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatTimeRelative(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}h lalu';
    if (diff.inHours > 0) return '${diff.inHours}j lalu';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m lalu';
    return 'Baru saja';
  }

  Widget _buildNotificationText(Map<String, dynamic> notif) {
    final type = notif['type'];
    final actor = notif['username'] ?? 'Seseorang';
    
    String actionText = '';
    if (type == 'follow') actionText = 'mulai mengikutimu';
    else if (type == 'like') {
      final target = notif['target_type'] == 'review' ? 'review' : 'list';
      actionText = 'nge-like $target kamu';
    }
    else if (type == 'comment') actionText = 'komentar di review kamu';
    else if (type == 'reply') actionText = 'bales komentar kamu';
    
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black, fontSize: 14),
        children: [
          TextSpan(text: '@$actor ', style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: actionText),
        ],
      ),
    );
  }

  Future<void> _handleTap(Map<String, dynamic> notif) async {
    final type = notif['type'];
    final targetType = notif['target_type'];
    final targetId = notif['target_id'];
    final commentId = notif['comment_id']?.toString();
    
    try {
      if (type == 'follow') {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ProfilePage(userId: notif['actor_id']?.toString()),
        ));
      } else if (targetId != null) {
        if (targetType == 'review') {
          // Verify existence
          await ApiService.getVisitDetail(targetId.toString());
          if (!mounted) return;
          
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => VisitDetailPage(visitId: targetId.toString(), focusCommentId: commentId),
          ));
        } else if (targetType == 'list') {
          // Verify existence
          await ApiService.getListDetail(targetId.toString());
          if (!mounted) return;
          
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => ListDetailPage(listId: targetId.toString(), focusCommentId: commentId),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Konten sudah tidak tersedia')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifikasi', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Text('Gagal memuat: $_error', style: const TextStyle(color: Colors.red)))
          : _notifications.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Belum ada notifikasi', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ],
                )
              )
            : RefreshIndicator(
                onRefresh: _fetchAndMarkRead,
                child: ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (context, i) {
                    final notif = _notifications[i];
                    final bool isRead = notif['is_read'] ?? true;
                    
                    return InkWell(
                      onTap: () => _handleTap(notif),
                      child: Container(
                        color: isRead ? Colors.transparent : Colors.blue.withOpacity(0.05),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.accent,
                              child: Text(
                                notif['username'] != null && notif['username'].toString().isNotEmpty 
                                  ? notif['username'][0].toUpperCase() : 'U',
                                style: const TextStyle(color: Colors.white)
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildNotificationText(notif),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTimeRelative(notif['created_at']), 
                                    style: const TextStyle(color: Colors.grey, fontSize: 12)
                                  ),
                                ],
                              ),
                            ),
                            if (!isRead)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                width: 8, height: 8,
                                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
    );
  }
}
