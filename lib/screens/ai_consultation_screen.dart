import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/session_provider.dart';
import '../theme/clinic_theme.dart';
import '../widgets/dent_card.dart';
import '../widgets/glass_container.dart';

class _ChatMessage {
  _ChatMessage({required this.text, required this.isUser});
  final String text;
  final bool isUser;
}

class AiConsultationScreen extends StatefulWidget {
  const AiConsultationScreen({super.key});

  @override
  State<AiConsultationScreen> createState() => _AiConsultationScreenState();
}

class _AiConsultationScreenState extends State<AiConsultationScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  static const _suggestions = [
    'Болит зуб при жевании, что делать?',
    'Как часто нужно посещать стоматолога?',
    'Почему кровоточат дёсны?',
    'Как правильно чистить зубы?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send([String? text]) async {
    final question = (text ?? _controller.text).trim();
    if (question.isEmpty || _isLoading) return;

    _controller.clear();
    HapticFeedback.lightImpact();

    setState(() {
      _messages.add(_ChatMessage(text: question, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final api = context.read<SessionProvider>().apiService;
      final answer = await api.aiConsult(question);
      if (!mounted) return;
      setState(() => _messages.add(_ChatMessage(text: answer, isUser: false)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_ChatMessage(
        text: 'Не удалось получить ответ. Проверьте соединение и попробуйте снова.',
        isUser: false,
      )));
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClinicTheme.mist,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: ClinicTheme.heroGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(LucideIcons.bot, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            const Text('ИИ-ассистент'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildWelcome()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _TypingBubble();
                      }
                      return _MessageBubble(message: _messages[index]);
                    },
                  ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: ClinicTheme.heroGradient,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: ClinicTheme.azure.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(LucideIcons.bot, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 20),
          Text(
            'ИИ-консультант',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Задайте вопрос о стоматологии — расскажу о симптомах, гигиене и профилактике.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ClinicTheme.slate),
          ),
          const SizedBox(height: 8),
          DentCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(LucideIcons.alertCircle, size: 16, color: ClinicTheme.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ИИ не ставит диагнозы. При болях обратитесь к врачу.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ClinicTheme.slate),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Популярные вопросы',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          ..._suggestions.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => _send(s),
              child: DentCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    const Icon(LucideIcons.messageCircle, size: 16, color: ClinicTheme.azure),
                    const SizedBox(width: 10),
                    Expanded(child: Text(s)),
                    const Icon(LucideIcons.arrowRight, size: 16, color: ClinicTheme.slate),
                  ],
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return GlassContainer(
      borderRadius: 0,
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Напишите вопрос…',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: _isLoading ? null : ClinicTheme.heroGradient,
              color: _isLoading ? Colors.white12 : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              onPressed: _isLoading ? null : () => _send(),
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                    )
                  : const Icon(LucideIcons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: ClinicTheme.heroGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(LucideIcons.bot, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? ClinicTheme.azure : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isUser ? Colors.white : ClinicTheme.midnight,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: ClinicTheme.heroGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.bot, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(delay: 0),
                const SizedBox(width: 4),
                _Dot(delay: 150),
                const SizedBox(width: 4),
                _Dot(delay: 300),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.delay});
  final int delay;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: ClinicTheme.slate,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
