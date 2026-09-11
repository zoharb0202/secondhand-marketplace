import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/order_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../support/data/services/order_dispute_service.dart';
import '../../../support/presentation/pages/ticket_chat_page.dart';

class _IssueTypeOption {
  final String value;
  final String label;
  final IconData icon;
  const _IssueTypeOption(this.value, this.label, this.icon);
}

const List<_IssueTypeOption> _issueTypes = [
  _IssueTypeOption('arrived_broken', 'המוצר פגום', Icons.broken_image_outlined),
  _IssueTypeOption(
    'not_as_described',
    'לא תואם את התיאור',
    Icons.fact_check_outlined,
  ),
  _IssueTypeOption(
    'never_arrived',
    'המוכר לא הגיע לאיסוף',
    Icons.person_off_outlined,
  ),
  _IssueTypeOption('wrong_item', 'התקבל מוצר אחר', Icons.swap_horiz_outlined),
  _IssueTypeOption('other', 'אחר', Icons.help_outline),
];

class _ResolutionOption {
  final String value;
  final String label;
  const _ResolutionOption(this.value, this.label);
}

const List<_ResolutionOption> _resolutions = [
  _ResolutionOption('refund', 'החזר כספי מלא'),
  _ResolutionOption('replacement', 'החלפה'),
  _ResolutionOption('partial_refund', 'החזר חלקי'),
  _ResolutionOption('other', 'משהו אחר'),
];

class OrderProblemSheet extends ConsumerStatefulWidget {
  final OrderModel order;

  const OrderProblemSheet({super.key, required this.order});

  static Future<String?> show(BuildContext context, OrderModel order) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrderProblemSheet(order: order),
    );
  }

  @override
  ConsumerState<OrderProblemSheet> createState() => _OrderProblemSheetState();
}

class _OrderProblemSheetState extends ConsumerState<OrderProblemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _issueType;
  bool? _itemInPossession;
  String? _preferredResolution;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider).value;
    _phoneController.text = user?.phoneNumber ?? '';
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_issueType == null) {
      _warn('נא לבחור מה קרה עם ההזמנה');
      return;
    }
    if (_itemInPossession == null) {
      _warn('נא לציין האם המוצר ברשותך');
      return;
    }
    if (_preferredResolution == null) {
      _warn('נא לבחור את הפתרון המועדף');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    final service = OrderDisputeService();
    final result = await service.reportOrderProblem(
      orderId: widget.order.id,
      issueType: _issueType!,
      description: _descriptionController.text.trim(),
      itemInPossession: _itemInPossession!,
      preferredResolution: _preferredResolution!,
      contactPhone: _phoneController.text.trim().isNotEmpty
          ? _phoneController.text.trim()
          : null,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success && result.ticketId != null) {
      Navigator.of(context).pop(result.ticketId);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TicketChatPage(ticketId: result.ticketId!),
        ),
      );
    } else {
      _warn(result.message ?? 'שגיאה בשליחת הדיווח, נסה שוב');
    }
  }

  void _warn(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: AppColors.warning),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Form(
              key: _formKey,
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.report_problem_outlined,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'יש לי בעיה עם ההזמנה',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.order.productTitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 20),

                  _sectionTitle('מה קרה? *'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _issueTypes.map((opt) {
                      final selected = _issueType == opt.value;
                      return ChoiceChip(
                        avatar: Icon(
                          opt.icon,
                          size: 16,
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                        label: Text(opt.label),
                        selected: selected,
                        onSelected: (v) =>
                            setState(() => _issueType = v ? opt.value : null),
                        selectedColor: AppColors.warning,
                        labelStyle: TextStyle(
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        backgroundColor: AppColors.surfaceVariant,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: selected
                                ? AppColors.warning
                                : AppColors.border,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  _sectionTitle('פרטים נוספים *'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 1000,
                    decoration: InputDecoration(
                      hintText: 'ספר/י לנו מה קרה בפירוט...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                    ),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.length < 10) return 'נא לפרט לפחות 10 תווים';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  _sectionTitle('האם המוצר אצלך? *'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _segmentButton(
                          label: 'כן',
                          selected: _itemInPossession == true,
                          onTap: () => setState(() => _itemInPossession = true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _segmentButton(
                          label: 'לא',
                          selected: _itemInPossession == false,
                          onTap: () =>
                              setState(() => _itemInPossession = false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _sectionTitle('מה הפתרון שהיית רוצה? *'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _resolutions.map((opt) {
                      final selected = _preferredResolution == opt.value;
                      return ChoiceChip(
                        label: Text(opt.label),
                        selected: selected,
                        onSelected: (v) => setState(
                          () => _preferredResolution = v ? opt.value : null,
                        ),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        backgroundColor: AppColors.surfaceVariant,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: selected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  _sectionTitle('טלפון ליצירת קשר (אופציונלי)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: 'טלפון',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: AppColors.info,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'הפנייה תיפתח מול שירות הלקוחות והמוכר יקבל הודעה. '
                            'זו אינה בקשת החזר מיידית — ההחלטה מתקבלת אחרי הבירור.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'שלח פנייה',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text(
                        'ביטול',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimary,
    ),
  );

  Widget _segmentButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
