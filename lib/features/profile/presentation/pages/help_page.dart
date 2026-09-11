import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart';
import 'chatbot_page.dart';
import '../../../../core/constants/app_constants.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('עזרה ותמיכה')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'שאלות נפוצות',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          _FAQItem(
            question: 'איך מוכרים מוצר?',
            answer:
                'לחץ על כפתור ה-+ בתחתית המסך, מלא את פרטי המוצר, הוסף תמונות ולחץ על "פרסם".',
          ),
          _FAQItem(
            question: 'איך קונים מוצר?',
            answer:
                'בחר מוצר שמעניין אותך, לחץ על "קנה עכשיו" והשלם את התשלום. לאחר שהמוכר יסמן שההזמנה מוכנה, תקבל את כתובת האיסוף.',
          ),
          _FAQItem(
            question: 'איך יוצרים קשר עם מוכר?',
            answer: 'בדף המוצר, לחץ על "שלח הודעה" כדי לפתוח צ\'אט עם המוכר.',
          ),
          _FAQItem(
            question: 'מה עושים אם יש בעיה בהזמנה?',
            answer:
                'נסה קודם לתאם מול המוכר בצ\'אט. אם זה לא נפתר, לחץ על "דיווח על בעיה בהזמנה" בדף ההזמנה ונציג שירות יטפל בפנייה.',
          ),
          const SizedBox(height: 32),

          const Text(
            'צור קשר',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          _ContactOption(
            icon: Icons.email_outlined,
            title: 'אימייל',
            subtitle: AppConstants.supportEmail,
            onTap: () async {
              final uri = Uri.parse('mailto:${AppConstants.supportEmail}');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
          ),
          _ContactOption(
            icon: Icons.phone_outlined,
            title: 'טלפון',
            subtitle: '*5678',
            onTap: () async {
              final uri = Uri.parse('tel:*5678');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
          ),
          _ContactOption(
            icon: Icons.chat_outlined,
            title: 'עוזר תמיכה חכם',
            subtitle: 'צ\'אט AI - זמין 24/7',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatbotPage()),
              );
            },
          ),
          const SizedBox(height: 32),

          OutlinedButton.icon(
            onPressed: () {
              _showReportDialog(context);
            },
            icon: const Icon(Icons.flag_outlined),
            label: const Text('דווח על בעיה'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('דווח על בעיה'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'תאר את הבעיה...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              final text = controller.text.trim();

              if (text.isEmpty) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('נא לתאר את הבעיה')),
                );
                return;
              }

              navigator.pop();

              try {
                final user = FirebaseAuth.instance.currentUser;
                await FirebaseFirestore.instance.collection('reports').add({
                  'reporterId': user?.uid,
                  'reporterEmail': user?.email,
                  'targetType': 'app_issue',
                  'reason': 'דיווח על בעיה',
                  'details': text,
                  'status': 'pending',
                  'createdAt': FieldValue.serverTimestamp(),
                });
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('הדיווח נשלח בהצלחה. נחזור אליך בהקדם'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('שגיאה בשליחת הדיווח: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('שלח'),
          ),
        ],
      ),
    );
  }
}

class _FAQItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FAQItem({required this.question, required this.answer});

  @override
  State<_FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<_FAQItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() => _isExpanded = !_isExpanded);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 12),
                Text(
                  widget.answer,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
