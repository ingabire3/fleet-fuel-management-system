import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/notification_item.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  NotificationCategory? _categoryFilter;
  DateTime? _dateFilter;
  String _search = '';

  static const _categories = [
    null,
    NotificationCategory.fuelRequest,
    NotificationCategory.aiAlert,
    NotificationCategory.vehicle,
    NotificationCategory.budget,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthService>();
    final notifSvc = context.read<NotificationService>();
    final userId = auth.currentProfile?.id;
    if (userId == null) return;
    final seeAll = auth.currentProfile?.isAdmin ?? false;
    await notifSvc.fetch(userId, seeAll: seeAll);
  }

  @override
  void dispose() {
    super.dispose();
  }

  List<NotificationItem> _filtered(List<NotificationItem> all) {
    return all.where((n) {
      if (_categoryFilter != null && n.category != _categoryFilter) {
        return false;
      }
      if (_dateFilter != null) {
        final d = n.createdAt;
        if (d.year != _dateFilter!.year ||
            d.month != _dateFilter!.month ||
            d.day != _dateFilter!.day) {
          return false;
        }
      }
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        if (!n.title.toLowerCase().contains(q) &&
            !n.message.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFilter ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _dateFilter = picked);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final notifSvc = context.watch<NotificationService>();
    final userId = auth.currentProfile?.id;
    final items = _filtered(notifSvc.notifications);

    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        actions: [
          if (notifSvc.unreadCount > 0)
            TextButton(
              onPressed: userId == null
                  ? null
                  : () => notifSvc.markAllAsRead(userId),
              child: const Text('Mark all read',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search notifications...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                ..._categories.map((c) {
                  final selected = _categoryFilter == c;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(c == null ? 'All' : c.label),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _categoryFilter = selected ? null : c),
                      selectedColor: AppConstants.primaryOrange,
                      checkmarkColor: Colors.white,
                      labelStyle: GoogleFonts.poppins(
                        fontSize: 12,
                        color: selected ? Colors.white : AppConstants.darkText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: Icon(Icons.calendar_today,
                        size: 14,
                        color: _dateFilter != null
                            ? Colors.white
                            : AppConstants.darkText),
                    label: Text(_dateFilter == null
                        ? 'Date'
                        : AppConstants.formatDate(_dateFilter!).split(' ').first),
                    backgroundColor: _dateFilter != null
                        ? AppConstants.primaryOrange
                        : null,
                    labelStyle: GoogleFonts.poppins(
                      fontSize: 12,
                      color: _dateFilter != null
                          ? Colors.white
                          : AppConstants.darkText,
                      fontWeight: FontWeight.w500,
                    ),
                    onPressed: _dateFilter != null
                        ? () => setState(() => _dateFilter = null)
                        : _pickDate,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: notifSvc.loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    color: AppConstants.primaryOrange,
                    onRefresh: _load,
                    child: items.isEmpty
                        ? _empty()
                        : ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (_, i) {
                              final n = items[i];
                              return Dismissible(
                                key: ValueKey(n.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  color: AppConstants.severityCritical,
                                  alignment: Alignment.centerRight,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 20),
                                  child: const Icon(Icons.delete,
                                      color: Colors.white),
                                ),
                                onDismissed: (_) => notifSvc.delete(n.id),
                                child: _NotificationTile(
                                  item: n,
                                  onTap: () => notifSvc.markAsRead(n.id),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _empty() => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications_off_outlined,
                      size: 56, color: AppConstants.mediumText),
                  const SizedBox(height: 12),
                  Text('No notifications',
                      style: GoogleFonts.poppins(
                          fontSize: 14, color: AppConstants.mediumText)),
                ],
              ),
            ),
          ),
        ),
      );
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;

  const _NotificationTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: item.isRead ? null : AppConstants.lightOrangeBg.withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.priorityColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(item.category.icon, color: item.priorityColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(item.title,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight:
                                  item.isRead ? FontWeight.w500 : FontWeight.bold,
                              color: AppConstants.darkText,
                            )),
                      ),
                      if (!item.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppConstants.primaryOrange,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(item.message,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppConstants.mediumText)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.priorityColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(item.priorityLabel,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: item.priorityColor,
                            )),
                      ),
                      const SizedBox(width: 8),
                      Text(AppConstants.timeAgo(item.createdAt),
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: AppConstants.mediumText)),
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
}
