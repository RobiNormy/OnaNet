import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ona_net/auth/installation_service_request.dart';
import 'package:ona_net/themes/app_theme.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  final InstallationServiceRequest _service = InstallationServiceRequest();
  late Future<List<InstallationRequestResult>> _requests = _load();
  String? _cancellingId;
  String? _reviewingId;
  final Set<String> _promptedReviewIds = <String>{};

  Future<List<InstallationRequestResult>> _load() async {
    final requests = await _service.myRequests();
    final needsReview = requests.where(
      (request) =>
          (request.status.toLowerCase() == 'complete' ||
              request.status.toLowerCase() == 'completed') &&
          request.reviewId == null,
    );
    if (needsReview.isNotEmpty) {
      final request = needsReview.first;
      if (_promptedReviewIds.add(request.id)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openReview(request);
        });
      }
    }
    return requests;
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _requests = next);
    await next;
  }

  Future<void> _cancel(InstallationRequestResult request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel request?'),
        content: const Text(
          'You can only cancel within 10 minutes of sending it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep request'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancellingId = request.id);
    try {
      await _service.cancel(request.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Installation request cancelled.')),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _cancellingId = null);
    }
  }

  Future<void> _openReview(InstallationRequestResult request) async {
    if (_reviewingId != null) return;
    final review = await showDialog<_ReviewDraft>(
      context: context,
      builder: (_) => _ReviewDialog(
        providerName: request.providerName ?? 'Your provider',
        packageName: request.packageName ?? 'internet',
      ),
    );
    if (review == null || !mounted) return;

    setState(() => _reviewingId = request.id);
    try {
      await _service.submitReview(
        installationRequestId: request.id,
        rating: review.rating,
        comment: review.comment,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks! Your review was submitted.')),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _reviewingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My requests',
          style: GoogleFonts.urbanist(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh requests',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<InstallationRequestResult>>(
        future: _requests,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _RequestMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load your requests',
              message: snapshot.error.toString(),
              buttonLabel: 'Try again',
              onPressed: _refresh,
            );
          }
          final requests = snapshot.data ?? const [];
          if (requests.isEmpty) {
            return _RequestMessage(
              icon: Icons.receipt_long_outlined,
              title: 'No installation requests yet',
              message:
                  'Requests you send to providers will appear here with their live status.',
              buttonLabel: 'Refresh',
              onPressed: _refresh,
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: requests.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final request = requests[index];
                return _RequestCard(
                  request: request,
                  isCancelling: _cancellingId == request.id,
                  isReviewing: _reviewingId == request.id,
                  onCancel: () => _cancel(request),
                  onReview: () => _openReview(request),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ReviewDraft {
  const _ReviewDraft({required this.rating, required this.comment});

  final int rating;
  final String? comment;
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.providerName, required this.packageName});

  final String providerName;
  final String packageName;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final TextEditingController _commentController = TextEditingController();
  int _rating = 0;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      title: const Text('How was your installation?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.providerName} completed your ${widget.packageName} installation.',
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            children: List.generate(5, (index) {
              final value = index + 1;
              return IconButton(
                constraints: const BoxConstraints.tightFor(
                  width: 42,
                  height: 48,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                tooltip: '$value star${value == 1 ? '' : 's'}',
                onPressed: () => setState(() => _rating = value),
                icon: Icon(
                  value <= _rating
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: AppTheme.amber,
                  size: 34,
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            maxLines: 3,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Tell us more (optional)',
              hintText: 'Installation speed, service and experience',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: _rating == 0
              ? null
              : () => Navigator.pop(
                  context,
                  _ReviewDraft(
                    rating: _rating,
                    comment: _commentController.text.trim().isEmpty
                        ? null
                        : _commentController.text.trim(),
                  ),
                ),
          child: const Text('Submit review'),
        ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.isCancelling,
    required this.isReviewing,
    required this.onCancel,
    required this.onReview,
  });

  final InstallationRequestResult request;
  final bool isCancelling;
  final bool isReviewing;
  final VoidCallback onCancel;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.offWhite : AppTheme.navy;
    final muted = textColor.withValues(alpha: 0.62);
    final status = _statusInfo(request.status);
    final canCancel =
        request.status.toLowerCase() == 'pending' &&
        request.createdAt != null &&
        DateTime.now().difference(request.createdAt!).inMinutes < 10;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.navyMid : AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppTheme.navyLight.withValues(alpha: 0.7)
              : AppTheme.lightGray,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.providerName?.trim().isNotEmpty == true
                          ? request.providerName!
                          : 'Internet provider',
                      style: GoogleFonts.urbanist(
                        color: textColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      request.packageName ?? 'Selected package',
                      style: GoogleFonts.urbanist(
                        color: muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.label,
                  style: GoogleFonts.urbanist(
                    color: status.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _StatusProgress(status: request.status),
          const SizedBox(height: 15),
          _DetailRow(
            icon: Icons.location_on_outlined,
            text: request.estateOrBuilding,
            color: muted,
          ),
          if (request.preferredDate != null) ...[
            const SizedBox(height: 8),
            _DetailRow(
              icon: Icons.event_outlined,
              text:
                  'Preferred: ${_date(request.preferredDate!)}${request.preferredTime == null ? '' : ' at ${_time(request.preferredTime!)}'}',
              color: muted,
            ),
          ],
          if (request.createdAt != null) ...[
            const SizedBox(height: 8),
            _DetailRow(
              icon: Icons.schedule_rounded,
              text: 'Sent ${_dateTime(request.createdAt!.toLocal())}',
              color: muted,
            ),
          ],
          if (request.declineReason?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Provider note: ${request.declineReason}',
                style: GoogleFonts.urbanist(
                  color: Colors.red.shade400,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (request.status.toLowerCase() == 'complete' ||
              request.status.toLowerCase() == 'completed') ...[
            const SizedBox(height: 14),
            if (request.reviewId == null)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isReviewing ? null : onReview,
                  icon: isReviewing
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.star_outline_rounded),
                  label: Text(isReviewing ? 'Submitting...' : 'Leave a review'),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppTheme.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, color: AppTheme.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your review: ${request.reviewRating ?? 0}/5',
                        style: GoogleFonts.urbanist(
                          color: textColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (canCancel) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: isCancelling ? null : onCancel,
                icon: isCancelling
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.close_rounded),
                label: Text(isCancelling ? 'Cancelling...' : 'Cancel request'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusProgress extends StatelessWidget {
  const _StatusProgress({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    if (normalized == 'declined' || normalized == 'cancelled') {
      final info = _statusInfo(normalized);
      return Row(
        children: [
          Icon(info.icon, color: info.color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              normalized == 'declined'
                  ? 'The provider declined this request'
                  : 'This request was cancelled',
              style: GoogleFonts.urbanist(
                color: info.color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }

    final current = normalized == 'accepted'
        ? 1
        : (normalized == 'complete' || normalized == 'completed')
        ? 2
        : 0;
    const labels = ['Sent', 'Accepted', 'Installed'];
    return Row(
      children: List.generate(labels.length, (index) {
        final active = index <= current;
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: active ? AppTheme.green : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  active ? Icons.check_rounded : Icons.circle,
                  size: active ? 15 : 7,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  labels[index],
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.urbanist(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: active ? AppTheme.green : Colors.grey,
                  ),
                ),
              ),
              if (index < labels.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    color: index < current
                        ? AppTheme.green
                        : Colors.grey.shade300,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: GoogleFonts.urbanist(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _RequestMessage extends StatelessWidget {
  const _RequestMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String buttonLabel;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 52, color: AppTheme.amber),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.urbanist(
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(buttonLabel),
          ),
        ],
      ),
    ),
  );
}

({String label, Color color, IconData icon}) _statusInfo(String status) {
  switch (status.toLowerCase()) {
    case 'accepted':
      return (
        label: 'Accepted',
        color: Colors.blue,
        icon: Icons.check_circle_outline,
      );
    case 'complete':
    case 'completed':
      return (
        label: 'Installed',
        color: AppTheme.green,
        icon: Icons.task_alt_rounded,
      );
    case 'declined':
      return (
        label: 'Declined',
        color: Colors.red,
        icon: Icons.cancel_outlined,
      );
    case 'cancelled':
      return (
        label: 'Cancelled',
        color: Colors.grey,
        icon: Icons.block_rounded,
      );
    default:
      return (
        label: 'Pending',
        color: AppTheme.amberDark,
        icon: Icons.schedule_rounded,
      );
  }
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _time(DateTime value) {
  final hour = value.hour == 0
      ? 12
      : (value.hour > 12 ? value.hour - 12 : value.hour);
  return '$hour:${value.minute.toString().padLeft(2, '0')} ${value.hour >= 12 ? 'PM' : 'AM'}';
}

String _dateTime(DateTime value) => '${_date(value)} at ${_time(value)}';
