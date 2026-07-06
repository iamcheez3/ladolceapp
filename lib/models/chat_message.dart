class ChatMessage {
  final int id;
  final String senderType; // 'customer' or 'rider'
  final String senderName;
  final String messageType; // 'text' or 'image'
  final String message;
  final String? imageUrl;
  final DateTime createdAt;
  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.senderType,
    required this.senderName,
    required this.messageType,
    required this.message,
    this.imageUrl,
    required this.createdAt,
    required this.isRead,
  });

  bool get isImage => messageType == 'image';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawUrl = (json['image_url'] ?? '').toString().trim();
    return ChatMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      senderType: (json['sender_type'] ?? '').toString(),
      senderName: (json['sender_name'] ?? '').toString(),
      messageType: (json['message_type'] ?? 'text').toString(),
      message: (json['message'] ?? '').toString(),
      imageUrl: rawUrl.isNotEmpty ? rawUrl : null,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString())?.toLocal() ?? DateTime.now(),
      isRead: json['is_read'] == true,
    );
  }
}
