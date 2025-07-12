import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_detail_screen.dart';

class ChatListScreen extends StatefulWidget {
  final String userType; // 'client' or 'photographer'
  const ChatListScreen({super.key, required this.userType});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final currentUser = FirebaseAuth.instance.currentUser!;

  @override
  Widget build(BuildContext context) {
    final chatsRef = FirebaseFirestore.instance
        .collection('chats')
        .where('${widget.userType}Id', isEqualTo: currentUser.uid)
        .orderBy('lastUpdated', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: StreamBuilder<QuerySnapshot>(
        stream: chatsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading chats."));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final chats = snapshot.data!.docs;

          if (chats.isEmpty) {
            return const Center(child: Text('No conversations yet.'));
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chatDoc = chats[index];
              final chat = chatDoc.data() as Map<String, dynamic>;
              final chatId = chatDoc.id;
              final lastMessage = chat['lastMessageText'] ?? '';
              final lastSender = chat['lastSenderName'] ?? '';
              final timestamp = (chat['lastUpdated'] as Timestamp?)?.toDate();
              final timeText = timestamp != null
                  ? TimeOfDay.fromDateTime(timestamp).format(context)
                  : '';

              // Determine unread count field
              final unreadCountField = widget.userType == 'client'
                  ? 'clientUnreadCount'
                  : 'photographerUnreadCount';
              final unreadCount = chat[unreadCountField] ?? 0;

              final chatPartnerName = widget.userType == 'client'
                  ? chat['photographerName'] ?? 'Photographer'
                  : chat['clientName'] ?? 'Client';

              final chatPartnerId = widget.userType == 'client'
                  ? chat['photographerId']
                  : chat['clientId'];

              final chatPartnerPhoto = widget.userType == 'client'
                  ? chat['photographerPhotoUrl'] ?? ''
                  : chat['clientPhotoUrl'] ?? '';

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: chatPartnerPhoto.isNotEmpty
                      ? NetworkImage(chatPartnerPhoto)
                      : null,
                  child: chatPartnerPhoto.isEmpty
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(chatPartnerName),
                subtitle: Text(
                  lastMessage.isNotEmpty
                      ? '$lastSender: $lastMessage'
                      : 'No messages yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (timeText.isNotEmpty)
                      Text(
                        timeText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    if (unreadCount > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatDetailScreen(
                        chatId: chatId,
                        otherUserId: chatPartnerId,
                        otherUserName: chatPartnerName,
                        otherUserPhotoUrl: chatPartnerPhoto,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
