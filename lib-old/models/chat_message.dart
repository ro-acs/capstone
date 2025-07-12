class ChatMessage {
  final String senderId;
  final String senderRole;
  final String? text;
  final String? imageUrl;
  final DateTime timestamp;

  ChatMessage({
    required this.senderId,
    required this.senderRole,
    this.text,
    this.imageUrl,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderRole': senderRole,
      'text': text,
      'imageUrl': imageUrl,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      senderId: map['senderId'],
      senderRole: map['senderRole'],
      text: map['text'],
      imageUrl: map['imageUrl'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}
