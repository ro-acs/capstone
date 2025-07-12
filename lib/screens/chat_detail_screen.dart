import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserPhotoUrl;

  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserPhotoUrl,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final currentUser = FirebaseAuth.instance.currentUser!;
  final messageController = TextEditingController();
  final scrollController = ScrollController();
  bool isTyping = false;

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
    messageController.addListener(_handleTyping);
  }

  @override
  void dispose() {
    messageController.removeListener(_handleTyping);
    messageController.dispose();
    super.dispose();
  }

  void _handleTyping() {
    final typingNow = messageController.text.trim().isNotEmpty;
    if (isTyping != typingNow) {
      isTyping = typingNow;
      FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
        'typing.${currentUser.uid}': isTyping,
      });
    }
  }

  Future<void> _markMessagesAsRead() async {
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({'unreadCount.${currentUser.uid}': 0});
  }

  Future<void> _sendMessage({
    String? text,
    String? imageUrl,
    String? fileUrl,
    String? fileName,
  }) async {
    if ((text == null || text.trim().isEmpty) &&
        imageUrl == null &&
        fileUrl == null)
      return;

    final timestamp = Timestamp.now();
    final messagesRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages');

    await messagesRef.add({
      'senderId': currentUser.uid,
      'senderName': currentUser.displayName ?? 'User',
      'senderPhotoUrl': currentUser.photoURL ?? '',
      'timestamp': timestamp,
      'text': text ?? '',
      'imageUrl': imageUrl ?? '',
      'fileUrl': fileUrl ?? '',
      'fileName': fileName ?? '',
      'readBy': [currentUser.uid],
      'reactions': [],
    });

    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).set(
      {
        'lastMessageText': text ?? '[Image/File]',
        'lastUpdated': timestamp,
        'senderId': currentUser.uid,
        'senderName': currentUser.displayName ?? 'User',
        'participants': [currentUser.uid, widget.otherUserId],
        'unreadCount.${widget.otherUserId}': FieldValue.increment(1),
        'typing.${currentUser.uid}': false,
      },
      SetOptions(merge: true),
    );

    messageController.clear();
    _scrollToBottom();
  }

  Future<void> _scrollToBottom() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final ref = FirebaseStorage.instance.ref(
        'chat_images/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();
      await _sendMessage(imageUrl: url);
    }
  }

  Future<void> _addReaction(DocumentSnapshot doc, String emoji) async {
    final data = doc.data() as Map<String, dynamic>;
    final reactions = List<String>.from(data['reactions'] ?? []);
    reactions.add('$emoji:${currentUser.uid}');
    await doc.reference.update({'reactions': reactions});
  }

  Widget _buildMessage(DocumentSnapshot doc) {
    final msg = doc.data() as Map<String, dynamic>;
    final isMe = msg['senderId'] == currentUser.uid;
    final time = (msg['timestamp'] as Timestamp).toDate();
    final timeStr = DateFormat.jm().format(time);

    return GestureDetector(
      onLongPress: () async {
        final emoji = await showDialog<String>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("React to message"),
            content: Wrap(
              spacing: 10,
              children: ['❤️', '😂', '👍', '😮', '😢', '👏'].map((e) {
                return GestureDetector(
                  onTap: () => Navigator.pop(context, e),
                  child: Text(e, style: const TextStyle(fontSize: 24)),
                );
              }).toList(),
            ),
          ),
        );
        if (emoji != null) await _addReaction(doc, emoji);
      },
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          padding: const EdgeInsets.all(10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          decoration: BoxDecoration(
            color: isMe ? Colors.blue[100] : Colors.grey[300],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((msg['imageUrl'] ?? '').isNotEmpty)
                Image.network(msg['imageUrl'], height: 150),
              if ((msg['fileUrl'] ?? '').isNotEmpty)
                InkWell(
                  onTap: () async => launchUrl(Uri.parse(msg['fileUrl'])),
                  child: Text(
                    '📎 ${msg['fileName']}',
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              if ((msg['text'] ?? '').isNotEmpty) Text(msg['text']),
              Text(
                timeStr,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
              if ((msg['reactions'] ?? []).isNotEmpty)
                Wrap(
                  spacing: 4,
                  children: List<String>.from(
                    msg['reactions'],
                  ).map((r) => Text(r.split(':').first)).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final ref = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId);
    return StreamBuilder<DocumentSnapshot>(
      stream: ref.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final typing = data['typing']?[widget.otherUserId] ?? false;
        return typing
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text('Typing...', style: TextStyle(color: Colors.grey)),
              )
            : const SizedBox.shrink();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesStream = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(widget.otherUserPhotoUrl),
            ),
            const SizedBox(width: 8),
            Text(widget.otherUserName),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildTypingIndicator(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: messagesStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!.docs;
                return ListView.builder(
                  controller: scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) =>
                      _buildMessage(messages[index]),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image),
                  onPressed: _pickImage,
                ),

                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendMessage(text: messageController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
