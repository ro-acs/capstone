import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';

class ChatWithClients extends StatefulWidget {
  final String userType;
  const ChatWithClients({super.key, required this.userType});

  @override
  State<ChatWithClients> createState() => _ChatWithClientsState();
}

class _ChatWithClientsState extends State<ChatWithClients> {
  final currentUser = FirebaseAuth.instance.currentUser;
  final _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients You Messaged'),
        backgroundColor: const Color(0xFF7F00FF),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('chats')
            .where('users', arrayContains: currentUser?.uid)
            .orderBy('lastTimestamp', descending: true)
            .snapshots(),
        builder: (context, chatSnapshot) {
          if (chatSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final chats = chatSnapshot.data?.docs ?? [];

          if (chats.isEmpty) {
            return const Center(child: Text("No messages yet."));
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final chatData = chat.data() as Map<String, dynamic>;
              final participants = chatData['users'] as List<dynamic>;

              final otherUserId = participants.firstWhere(
                (id) => id != currentUser?.uid,
                orElse: () => null,
              );

              return FutureBuilder<DocumentSnapshot>(
                future: _db.collection('users').doc(otherUserId).get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const ListTile(title: Text("Loading..."));
                  }

                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>?;

                  if (userData == null) {
                    return const ListTile(title: Text("User not found."));
                  }

                  final displayName = userData['name'] ?? 'Client';
                  final profileUrl = userData['profileImageUrl'] ?? '';
                  final unreadCount =
                      (chatData['unread_${currentUser?.uid}'] ?? 0) as int;
                  final lastTimestamp = chatData['lastTimestamp'] as Timestamp?;

                  String subtitleText = chatData['lastMessage'] ?? '';
                  if (lastTimestamp != null) {
                    final formattedTime = DateFormat(
                      'MMM d, hh:mm a',
                    ).format(lastTimestamp.toDate());
                    subtitleText += "\n$formattedTime";
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: profileUrl.isNotEmpty
                          ? NetworkImage(profileUrl)
                          : const AssetImage('assets/default_profile.png')
                                as ImageProvider,
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(displayName)),
                        if (unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(subtitleText),
                    isThreeLine: true,
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            chatId: chat.id,
                            receiverId: otherUserId,
                            receiverName: displayName,
                            receiverAvatar: profileUrl,
                          ),
                        ),
                      );
                    },
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
