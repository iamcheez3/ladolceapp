import 'dart:async';
import 'package:ladolce/l10n/app_localizations.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/chat_message.dart';
import '../services/api_service.dart';
import '../theme/ld.dart';

/// Full-screen per-order chat between Customer ↔ Rider.
///
/// [orderId]        — the pos_backend.order id
/// [orderRef]       — human-readable ref, e.g. "POS-2024-0001"
/// [currentRole]    — 'customer' or 'rider' (who is opening this screen)
/// [otherPartyName] — display name of the other party
class OrderChatScreen extends StatefulWidget {
  final int orderId;
  final String orderRef;
  final String currentRole;
  final String otherPartyName;

  const OrderChatScreen({
    super.key,
    required this.orderId,
    required this.orderRef,
    required this.currentRole,
    required this.otherPartyName,
  });

  @override
  State<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends State<OrderChatScreen> {
  static const Color _navy = Ld.navy;
  static const Color _bubbleMe = Ld.navy;
  static const Color _bubbleThem = Ld.surface;
  static const Color _bgPage = Ld.ground;

  final ApiService _apiService = ApiService();
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();

  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;
  Timer? _pollTimer;

  // Image pending preview (before sending)
  File? _pendingImage;
  String _pendingCaption = '';

  // Per-message upload progress indicator set
  String? _uploadingLabel;

  @override
  void initState() {
    super.initState();
    _loadChat();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadChat(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<void> _loadChat({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoading = true);
    try {
      final data = await _apiService.fetchOrderChat(widget.orderId);
      final rawMessages = data['messages'] as List<dynamic>? ?? [];
      final msgs = rawMessages
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList();
      if (mounted) {
        final hadNewMessages = msgs.length != _messages.length;
        setState(() {
          _messages = msgs;
          _isLoading = false;
          _errorMessage = null;
        });
        if (hadNewMessages) _scrollToBottom();
      }
      _apiService.markOrderChatRead(widget.orderId);
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load messages.';
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Sending — text
  // ---------------------------------------------------------------------------

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _inputCtrl.clear();

    try {
      final msg = await _apiService.sendOrderChatMessage(widget.orderId, text);
      if (mounted) {
        setState(() {
          _messages = [..._messages, msg];
          _isSending = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSending = false);
        _inputCtrl.text = text;
        _showError(
        AppLocalizations.of(context)?.failedToSendMessagePleaseTry ??
            'Failed to send message. Please try again.');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Sending — image
  // ---------------------------------------------------------------------------

  Future<void> _pickImage(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (picked == null) return;
    setState(() {
      _pendingImage = File(picked.path);
      _pendingCaption = '';
    });
  }

  void _clearPendingImage() {
    setState(() {
      _pendingImage = null;
      _pendingCaption = '';
    });
  }

  Future<void> _sendImage() async {
    final file = _pendingImage;
    if (file == null || _isSending) return;

    final caption = _pendingCaption.trim();
    setState(() {
      _isSending = true;
      _uploadingLabel = caption.isEmpty ? (AppLocalizations.of(context)?.sendingImage ?? '📷 Sending image…') : '📷 $caption';
      _pendingImage = null;
      _pendingCaption = '';
    });

    try {
      final msg = await _apiService.sendOrderChatImage(
        widget.orderId,
        file.path,
        caption: caption,
      );
      if (mounted) {
        setState(() {
          _messages = [..._messages, msg];
          _isSending = false;
          _uploadingLabel = null;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _uploadingLabel = null;
        });
        _showError(
        AppLocalizations.of(context)?.failedToSendImagePleaseTry ??
            'Failed to send image. Please try again.');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  bool _isMyMessage(ChatMessage msg) => msg.senderType == widget.currentRole;

  String _formatTime(DateTime dt) => DateFormat('HH:mm').format(dt);

  String _formatDateSeparator(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    if (msgDay == today) return (AppLocalizations.of(context)?.today ?? 'Today');
    if (msgDay == yesterday) return (AppLocalizations.of(context)?.yesterday ?? 'Yesterday');
    return DateFormat('d MMM yyyy').format(dt);
  }

  void _showImagePicker() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Ld.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const LdIconTile(Icons.photo_library_outlined),
              title: Text(AppLocalizations.of(context)?.chooseFromGallery ?? (AppLocalizations.of(context)?.chooseFromGallery ?? 'Choose from gallery')),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const LdIconTile(Icons.camera_alt_outlined),
              title: Text(AppLocalizations.of(context)?.takeAPhoto ?? (AppLocalizations.of(context)?.takeAPhoto ?? 'Take a photo')),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildOrderHeader(),
          Expanded(child: _buildMessageList()),
          if (_pendingImage != null) _buildImagePreview(),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return LdHeader(
      title: widget.otherPartyName.isNotEmpty
          ? widget.otherPartyName
          : (widget.currentRole == 'customer' ? (AppLocalizations.of(context)?.roleRider ?? 'Rider') : (AppLocalizations.of(context)?.roleCustomer ?? 'Customer')),
      subtitle: widget.orderRef,
      actions: [
        LdNavIconButton(
          icon: Icons.refresh_rounded,
          onPressed: () => _loadChat(),
          tooltip: AppLocalizations.of(context)?.refresh ?? (AppLocalizations.of(context)?.refresh ?? 'Refresh'),
        ),
      ],
    );
  }

  Widget _buildOrderHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Ld.surface,
        border: Border(bottom: BorderSide(color: Ld.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline_rounded, size: 14, color: Ld.muted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'This chat is for order ${widget.orderRef} only',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Ld.small,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Message list
  // ---------------------------------------------------------------------------

  Widget _buildMessageList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LdIconTile(Icons.error_outline_rounded, size: 56, background: Ld.dangerWash, color: Ld.danger),
            const SizedBox(height: 12),
            Text(_errorMessage!, style: Ld.label),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadChat, child: Text(AppLocalizations.of(context)?.retry ?? (AppLocalizations.of(context)?.retry ?? 'Retry'))),
          ],
        ),
      );
    }
    if (_messages.isEmpty && _uploadingLabel == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LdIconTile(Icons.chat_bubble_outline_rounded, size: 64, background: Ld.surface),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)?.noMessagesYet ?? (AppLocalizations.of(context)?.noMessagesYet ?? 'No messages yet'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Ld.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)?.startTheConversationBelow ?? (AppLocalizations.of(context)?.startTheConversationBelow ?? 'Start the conversation below'),
              style: Ld.small,
            ),
          ],
        ),
      );
    }

    final items = <_ChatItem>[];
    DateTime? lastDay;
    for (final msg in _messages) {
      final msgDay =
          DateTime(msg.createdAt.year, msg.createdAt.month, msg.createdAt.day);
      if (lastDay == null || msgDay != lastDay) {
        items.add(_ChatItem.separator(_formatDateSeparator(msg.createdAt)));
        lastDay = msgDay;
      }
      items.add(_ChatItem.message(msg));
    }

    // Uploading placeholder at the bottom
    if (_uploadingLabel != null) {
      items.add(_ChatItem.uploading(_uploadingLabel!));
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item.isSeparator) return _buildDateSeparator(item.label!);
        if (item.isUploading) return _buildUploadingBubble(item.label!);
        return _buildBubble(item.message!);
      },
    );
  }

  Widget _buildDateSeparator(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: LdPill(
          label,
          background: Ld.surface,
          foreground: Ld.muted,
        ),
      ),
    );
  }

  Widget _buildUploadingBubble(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _bubbleMe.withValues(alpha: 0.6),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                // The label carries a camera emoji; show a real icon instead.
                if (label.startsWith('📷')) ...[
                  const Icon(Icons.photo_camera_outlined, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label.startsWith('📷')
                        ? label.substring('📷'.length).trim()
                        : label,
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _buildAvatar(widget.currentRole),
        ],
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    final isMe = _isMyMessage(msg);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            _buildAvatar(msg.senderType),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      msg.senderName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Ld.muted,
                      ),
                    ),
                  ),
                msg.isImage
                    ? _buildImageBubble(msg, isMe)
                    : _buildTextBubble(msg, isMe),
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(msg.createdAt),
                        style: const TextStyle(fontSize: 11, color: Ld.muted),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          msg.isRead ? Icons.done_all : Icons.done,
                          size: 13,
                          color: msg.isRead ? Ld.info : Ld.faint,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 6),
            _buildAvatar(widget.currentRole),
          ],
        ],
      ),
    );
  }

  Widget _buildTextBubble(ChatMessage msg, bool isMe) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? _bubbleMe : _bubbleThem,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMe ? 18 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 18),
        ),
        border: isMe ? null : Border.all(color: Ld.line),
      ),
      child: Text(
        msg.message,
        style: TextStyle(
          fontSize: 15,
          color: isMe ? Colors.white : Ld.ink,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildImageBubble(ChatMessage msg, bool isMe) {
    final maxW = MediaQuery.of(context).size.width * 0.72;
    final imageUrl = msg.imageUrl;

    return GestureDetector(
      onTap: imageUrl != null ? () => _openFullscreen(imageUrl) : null,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxW),
        decoration: BoxDecoration(
          color: isMe ? _bubbleMe : _bubbleThem,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          border: isMe ? null : Border.all(color: Ld.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (imageUrl != null)
              _buildNetworkImage(imageUrl, maxW)
            else
              Container(
                height: 120,
                color: Ld.ground,
                child: const Center(
                  child: Icon(Icons.broken_image_outlined, size: 40, color: Ld.faint),
                ),
              ),
            if (msg.message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Text(
                  msg.message,
                  style: TextStyle(
                    fontSize: 13,
                    color: isMe ? Ld.onNavyMuted : Ld.muted,
                    height: 1.3,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkImage(String relativeUrl, double maxW) {
    // Build absolute URL. baseUrl may end with '/api'; Odoo's /web/image route
    // lives at the root, so we strip any '/api' suffix before appending.
    return FutureBuilder<String>(
      future: _apiService.getBaseUrl(),
      builder: (context, snap) {
        final raw = snap.data ?? '';
        final base = raw.endsWith('/api')
            ? raw.substring(0, raw.length - 4)
            : raw;
        final fullUrl = base.isNotEmpty ? '$base$relativeUrl' : '';
        if (fullUrl.isEmpty) {
          return const SizedBox(
            height: 140,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return Image.network(
          fullUrl,
          width: maxW,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Container(
              height: 160,
              width: maxW,
              color: Ld.ground,
              child: const Center(child: CircularProgressIndicator()),
            );
          },
          errorBuilder: (_, __, ___) => Container(
            height: 120,
            width: maxW,
            color: Ld.ground,
            child: const Center(
              child: Icon(Icons.broken_image_outlined, size: 40, color: Ld.faint),
            ),
          ),
        );
      },
    );
  }

  void _openFullscreen(String relativeUrl) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullscreenImageScreen(
          relativeUrl: relativeUrl,
          getBaseUrl: _apiService.getBaseUrl,
        ),
      ),
    );
  }

  Widget _buildAvatar(String role) {
    final isCustomer = role == 'customer';
    return CircleAvatar(
      radius: 14,
      backgroundColor: isCustomer ? Ld.goldWash : Ld.infoWash,
      child: Icon(
        isCustomer ? Icons.person_rounded : Icons.delivery_dining_rounded,
        size: 16,
        color: isCustomer ? Ld.goldWashInk : Ld.navy,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Image preview panel
  // ---------------------------------------------------------------------------

  Widget _buildImagePreview() {
    return Container(
      decoration: const BoxDecoration(
        color: Ld.surface,
        border: Border(top: BorderSide(color: Ld.line)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.image_outlined, size: 18, color: _navy),
              const SizedBox(width: 6),
              Expanded(
                child: Text(AppLocalizations.of(context)?.imageReadyToSend ?? (AppLocalizations.of(context)?.imageReadyToSend ?? 'Image ready to send'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _navy,
                  ),
                ),
              ),
              IconButton(
                onPressed: _clearPendingImage,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: const Icon(Icons.close_rounded, size: 20, color: Ld.muted),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Ld.rSm),
                child: Image.file(
                  _pendingImage!,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)?.addACaptionOptional ?? (AppLocalizations.of(context)?.addACaptionOptional ?? 'Add a caption (optional)'),
                    hintStyle: const TextStyle(color: Ld.faint, fontSize: 14),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onChanged: (v) => _pendingCaption = v,
                  maxLines: 3,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
            ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _sendImage,
              icon: const Icon(Icons.send_rounded, size: 16),
              label: Text(AppLocalizations.of(context)?.sendImage ?? (AppLocalizations.of(context)?.sendImage ?? 'Send Image')),
            ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Input bar
  // ---------------------------------------------------------------------------

  Widget _buildInputBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Ld.surface,
        border: Border(top: BorderSide(color: Ld.line)),
      ),
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0
            ? 10
            : 10 + Ld.navInset(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Camera / gallery button
          _isSending
              ? const SizedBox(width: 44)
              : IconButton(
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 24),
                  color: _navy,
                  onPressed: _showImagePicker,
                  tooltip: AppLocalizations.of(context)?.sendImage2 ?? (AppLocalizations.of(context)?.sendImage2 ?? 'Send image'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                ),
          const SizedBox(width: 4),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: TextField(
                controller: _inputCtrl,
                focusNode: _focusNode,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)?.typeAMessage ?? (AppLocalizations.of(context)?.typeAMessage ?? 'Type a message…'),
                  hintStyle:
                      const TextStyle(color: Ld.faint, fontSize: 15),
                  filled: true,
                  fillColor: Ld.ground,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: Ld.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: Ld.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: _navy, width: 1.5),
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _isSending
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _navy,
                    ),
                  ),
                )
              : Semantics(
                  button: true,
                  child: Material(
                    color: _navy,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: _sendMessage,
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full-screen image viewer
// ---------------------------------------------------------------------------

class _FullscreenImageScreen extends StatelessWidget {
  final String relativeUrl;
  final Future<String> Function() getBaseUrl;

  const _FullscreenImageScreen({
    required this.relativeUrl,
    required this.getBaseUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<String>(
        future: getBaseUrl(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          final raw = snap.data!;
          final base = raw.endsWith('/api')
              ? raw.substring(0, raw.length - 4)
              : raw;
          final fullUrl = '$base$relativeUrl';
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: Center(
              child: Image.network(
                fullUrl,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (_, __, ___) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, size: 64, color: Colors.white38),
                      SizedBox(height: 12),
                      Text(AppLocalizations.of(context)?.couldNotLoadImage ?? (AppLocalizations.of(context)?.couldNotLoadImage ?? 'Could not load image'),
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal list item discriminated union
// ---------------------------------------------------------------------------

class _ChatItem {
  final ChatMessage? message;
  final String? label;
  final bool _uploading;

  const _ChatItem.message(this.message)
      : label = null,
        _uploading = false;
  const _ChatItem.separator(this.label)
      : message = null,
        _uploading = false;
  const _ChatItem.uploading(this.label)
      : message = null,
        _uploading = true;

  bool get isSeparator => !_uploading && label != null;
  bool get isUploading => _uploading;
}
