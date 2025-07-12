import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatWithClientsScreen extends StatelessWidget {
  const ChatWithClientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text("Chats with Clients")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: userId)
            .orderBy('lastTimestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final chats = snapshot.data!.docs;

          if (chats.isEmpty) {
            return const Center(child: Text("No chats yet."));
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final data = chats[index].data() as Map<String, dynamic>;
              final chatId = chats[index].id;
              final lastMessage = data['lastMessage'] ?? '';
              final participants = List<String>.from(
                data['participants'] ?? [],
              );
              final otherUserId = participants.firstWhere((id) => id != userId);

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(otherUserId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const ListTile(title: Text("Loading..."));
                  }

                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>;
                  final name = userData['fullName'] ?? 'Unknown';
                  final photoUrl = userData['photoUrl'];

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: photoUrl != null
                          ? NetworkImage(photoUrl)
                          : const AssetImage('assets/avatar_placeholder.png')
                                as ImageProvider,
                    ),
                    title: Text(name),
                    subtitle: Text(lastMessage),
                    trailing: const Icon(Icons.message),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/chat_screen',
                        arguments: {
                          'chatId': chatId,
                          'otherUserId': otherUserId,
                          'otherUserName': name,
                          'photoUrl': photoUrl,
                        },
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
