import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/app_theme.dart';
import '../services/history_repository.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/glass_card.dart';

String formatAssessmentDateTime(DateTime dateTime) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = dateTime.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '${local.day} ${months[local.month - 1]} ${local.year} · '
      '$hour:$minute $period';
}

String buildAssessmentShareText(AssessmentRecord record) {
  final isMatric = record.educationLevel.trim().toLowerCase() == 'matric';
  final matchPercent = record.top5.isEmpty ? 0 : record.top5.first.matchPercent;
  final topMatches = record.top5
      .take(3)
      .map((match) => '${match.title} — ${match.matchPercent}%');
  return 'AI Career Advisor\n'
      '${isMatric ? 'Top study path' : 'Top career'}: ${record.topCareer}\n'
      'Match: $matchPercent%\n'
      'Top 3 matches:\n${topMatches.join('\n')}\n'
      'Date: ${formatAssessmentDateTime(record.createdAt)}';
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.repository,
    required this.onViewMatches,
    required this.onStartAssessment,
    this.showBackButton = false,
  });

  final HistoryRepository repository;
  final ValueChanged<AssessmentRecord> onViewMatches;
  final VoidCallback onStartAssessment;
  final bool showBackButton;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  AssessmentHistorySnapshot? _history;
  Object? _loadError;
  bool _isLoading = true;
  bool _isClearing = false;
  final Map<String, AssessmentRecord> _pendingDeletes = {};

  @override
  void initState() {
    super.initState();
    unawaited(_loadHistory());
  }

  Future<void> _loadHistory({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final history = await widget.repository.loadWithStatus();
      if (!mounted) return;
      setState(() {
        _history = history;
        _loadError = null;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Could not load assessment history: $error');
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() => _loadHistory(showLoading: false);

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear assessment history?'),
        content: const Text(
          'This removes all saved assessments from this device and your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    for (final id in _pendingDeletes.keys.toList()) {
      _pendingDeletes.remove(id);
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _isClearing = true);
    try {
      await widget.repository.clearAll();
      if (!mounted) return;
      setState(() {
        _history = _history?.withRecords(const []);
        _isClearing = false;
      });
      showAppSnackBar(context, 'All assessments cleared.');
    } catch (error) {
      debugPrint('Could not clear assessment history: $error');
      if (!mounted) return;
      setState(() => _isClearing = false);
      showAppSnackBar(context, 'Could not clear history. Please try again.');
      await _loadHistory(showLoading: false);
    }
  }

  void _onDismissed(AssessmentRecord record) {
    final history = _history;
    if (history == null) return;
    _pendingDeletes[record.id] = record;
    setState(() {
      _history = history.withRecords(
        history.records.where((item) => item.id != record.id).toList(),
      );
    });

    final controller = ScaffoldMessenger.of(context).showSnackBar(
      buildAppSnackBar(
        context,
        'Assessment deleted.',
        icon: Icons.check_circle_rounded,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: AppTheme.accent(context),
          onPressed: () => _undoDelete(record),
        ),
      ),
    );
    unawaited(
      controller.closed.then((reason) async {
        if (_pendingDeletes.remove(record.id) == null) return;
        if (reason != SnackBarClosedReason.action) {
          await _deleteRecord(record);
        }
      }),
    );
  }

  void _undoDelete(AssessmentRecord record) {
    final history = _history;
    if (_pendingDeletes.remove(record.id) == null || history == null) return;
    final records = [...history.records, record]
      ..sort((first, second) => second.createdAt.compareTo(first.createdAt));
    setState(() => _history = history.withRecords(records));
    showAppSnackBar(context, 'Assessment restored.', icon: Icons.check_rounded);
  }

  Future<void> _deleteRecord(AssessmentRecord record) async {
    try {
      await widget.repository.delete(record.id);
    } catch (error) {
      debugPrint('Could not delete assessment "${record.id}": $error');
      if (!mounted) return;
      showAppSnackBar(context, 'Could not delete assessment. Please retry.');
      await _loadHistory(showLoading: false);
    }
  }

  Future<void> _shareRecord(AssessmentRecord record) async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: buildAssessmentShareText(record)),
      );
    } catch (error) {
      debugPrint('Could not share assessment "${record.id}": $error');
      if (mounted) showAppSnackBar(context, 'Could not share assessment.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = _history;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Expanded(
          child: _isLoading && history == null
              ? _loadingState()
              : _loadError != null && history == null
              ? _errorState()
              : _historyList(history!, isDark),
        ),
        _StartAssessmentButton(onPressed: widget.onStartAssessment),
      ],
    );
  }

  Widget _loadingState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
      children: [
        _HistoryHeader(
          count: null,
          isSynced: false,
          onClear: null,
          onBack: widget.showBackButton
              ? () => Navigator.of(context).maybePop()
              : null,
        ),
        const SizedBox(height: 28),
        const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _errorState() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
        children: [
          _HistoryHeader(
            count: null,
            isSynced: false,
            onClear: null,
            onBack: widget.showBackButton
                ? () => Navigator.of(context).maybePop()
                : null,
          ),
          const SizedBox(height: 14),
          GlassCard(
            radius: 16,
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 32,
                  color: AppTheme.rose,
                ),
                const SizedBox(height: 10),
                Text(
                  'Could not load assessment history',
                  textAlign: TextAlign.center,
                  style: AppTheme.title(
                    fontSize: 14,
                    color: AppTheme.onCanvas(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: AppTheme.body(
                    fontSize: 12,
                    color: AppTheme.muted(context),
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => _loadHistory(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyList(AssessmentHistorySnapshot history, bool isDark) {
    final records = history.records;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        key: const ValueKey('career-history-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
        children: [
          _HistoryHeader(
            count: records.length,
            isSynced: history.isSynced,
            onClear: records.isEmpty || _isClearing ? null : _confirmClearAll,
            onBack: widget.showBackButton
                ? () => Navigator.of(context).maybePop()
                : null,
          ),
          const SizedBox(height: 13),
          if (records.isEmpty)
            _EmptyHistoryCard(onStartAssessment: widget.onStartAssessment)
          else
            for (final record in records) ...[
              _AssessmentHistoryCard(
                record: record,
                isSynced: history.syncedIds.contains(record.id),
                onViewMatches: () => widget.onViewMatches(record),
                onShare: () => _shareRecord(record),
                onDismissed: () => _onDismissed(record),
                isDark: isDark,
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}
class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.count,
    required this.isSynced,
    required this.onClear,
    required this.onBack,
  });

  final int? count;
  final bool isSynced;
  final VoidCallback? onClear;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final countText = count == null
        ? 'Loading saved assessments'
        : '$count saved assessment${count == 1 ? '' : 's'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (onBack != null)
              IconButton(
                tooltip: 'Back',
                onPressed: onBack,
                style: IconButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.surface
                      : AppTheme.lightSurface,
                  foregroundColor: AppTheme.onCanvas(context),
                  side: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.glassBorder
                        : AppTheme.lightBorder,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
              ),
            Expanded(
              child: Text(
                'Assessment History',
                style: AppTheme.heading(
                  fontSize: 18,
                  color: AppTheme.onCanvas(context),
                ),
              ),
            ),
            TextButton(
              onPressed: onClear,
              child: Text(
                'Clear',
                style: AppTheme.label(fontSize: 11, color: AppTheme.rose),
              ),
            ),
          ],
        ),
        Text(
          countText,
          style: AppTheme.label(
            fontSize: 12,
            color: AppTheme.onCanvas(context),
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Icon(
              isSynced ? Icons.cloud_done_rounded : Icons.phone_android_rounded,
              size: 13,
              color: AppTheme.muted(context),
            ),
            const SizedBox(width: 5),
            Text(
              isSynced ? 'Synced to your account' : 'Saved on this device',
              style: AppTheme.body(
                fontSize: 11,
                color: AppTheme.muted(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AssessmentHistoryCard extends StatelessWidget {
  const _AssessmentHistoryCard({
    required this.record,
    required this.isSynced,
    required this.onViewMatches,
    required this.onShare,
    required this.onDismissed,
    required this.isDark,
  });

  final AssessmentRecord record;
  final bool isSynced;
  final VoidCallback onViewMatches;
  final VoidCallback onShare;
  final VoidCallback onDismissed;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final matchPercent = record.top5.isEmpty
        ? 0
        : record.top5.first.matchPercent;
    final otherMatches = record.top5.skip(1).take(2).toList();
    final matchColor = isDark ? AppTheme.cyan : const Color(0xFF0369A1);
    final badgeBackground = isSynced
        ? (isDark
              ? AppTheme.emerald.withValues(alpha: 0.15)
              : const Color(0xFFDCFCE7))
        : (isDark ? AppTheme.surface : const Color(0xFFF1F5F9));
    final badgeForeground = isSynced
        ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857))
        : AppTheme.muted(context);
    final card = GlassCard(
      radius: 16,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: AppTheme.accent(context),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  formatAssessmentDateTime(record.createdAt),
                  style: AppTheme.label(
                    fontSize: 10,
                    color: AppTheme.accent(context),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBackground,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSynced
                        ? AppTheme.emerald.withValues(
                            alpha: isDark ? 0.35 : 0.55,
                          )
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : AppTheme.lightBorder),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSynced
                          ? Icons.cloud_done_rounded
                          : Icons.phone_android_rounded,
                      size: 11,
                      color: badgeForeground,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isSynced ? 'Synced' : 'On device',
                      style: AppTheme.label(
                        fontSize: 9,
                        color: badgeForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.primary.withValues(alpha: 0.2)
                  : const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isDark
                    ? AppTheme.primaryLight.withValues(alpha: 0.35)
                    : const Color(0xFFC084FC),
              ),
            ),
            child: Text(
              '${record.educationLevel} (${record.group})',
              style: AppTheme.label(
                fontSize: 9,
                color: isDark
                    ? const Color(0xFFD8B4FE)
                    : const Color(0xFF6B21A8),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  record.topCareer,
                  style: AppTheme.title(
                    fontSize: 14,
                    color: AppTheme.onCanvas(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: matchColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: matchColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '$matchPercent% Match',
                  style: AppTheme.label(fontSize: 10, color: matchColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (matchPercent / 100).clamp(0.0, 1.0).toDouble(),
              minHeight: 5,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(matchColor),
            ),
          ),
          if (otherMatches.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Other: ${otherMatches.map((match) => '${match.title} (${match.matchPercent}%)').join(', ')}',
              style: AppTheme.body(
                fontSize: 10,
                color: AppTheme.muted(context),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.09)
                : const Color(0xFFE2E8F0),
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: onViewMatches,
                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                label: const Text('View Matches'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.accent(context),
                  textStyle: AppTheme.label(fontSize: 11),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Share assessment',
                onPressed: onShare,
                icon: const Icon(Icons.share_rounded, size: 18),
                color: AppTheme.muted(context),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
    return Dismissible(
      key: ValueKey('history-${record.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: _DismissBackground(
        alignment: Alignment.centerLeft,
        isDark: isDark,
      ),
      secondaryBackground: _DismissBackground(
        alignment: Alignment.centerRight,
        isDark: isDark,
      ),
      child: card,
    );
  }
}

class _DismissBackground extends StatelessWidget {
  const _DismissBackground({required this.alignment, required this.isDark});

  final Alignment alignment;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF4C1D2D) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        Icons.delete_outline_rounded,
        color: isDark ? const Color(0xFFFDA4AF) : const Color(0xFFBE123C),
      ),
    );
  }
}

class _EmptyHistoryCard extends StatelessWidget {
  const _EmptyHistoryCard({required this.onStartAssessment});

  final VoidCallback onStartAssessment;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.accent(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.history_rounded,
              size: 24,
              color: AppTheme.accent(context),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No assessments yet',
            style: AppTheme.title(
              fontSize: 15,
              color: AppTheme.onCanvas(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your saved career matches will appear here.',
            textAlign: TextAlign.center,
            style: AppTheme.body(fontSize: 11, color: AppTheme.muted(context)),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onStartAssessment,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Start Assessment'),
          ),
        ],
      ),
    );
  }
}

class _StartAssessmentButton extends StatelessWidget {
  const _StartAssessmentButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.38),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('start-new-assessment'),
              onTap: onPressed,
              borderRadius: BorderRadius.circular(13),
              child: SizedBox(
                height: 46,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Start New Assessment',
                        style: AppTheme.label(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}