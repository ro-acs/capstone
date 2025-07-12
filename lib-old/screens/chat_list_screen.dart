import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  final currentUser = FirebaseAuth.instance.currentUser!;

  String getChatId(String uid1, String uid2) {
    List<String> uids = [uid1, uid2];
    uids.sort();
    return '${uids[0]}_${uids[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Conversations')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('users', arrayContains: currentUser.uid)
            .orderBy('lastTimestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());

          final chats = snapshot.data!.docs;

          if (chats.isEmpty) {
            return Center(child: Text('No recent conversations.'));
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final users = List<String>.from(chat['users']);
              final otherUserId = users.firstWhere(
                (uid) => uid != currentUser.uid,
              );
              final lastMessage = chat['lastMessage'] ?? '';
              final timestamp = chat['lastTimestamp']?.toDate();

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(otherUserId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return ListTile(title: Text("Unknown User"));
                  }

                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>;
                  final name = userData['name'] ?? 'Unknown';
                  final avatar = userData['avatarUrl'];

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: avatar != null
                          ? NetworkImage(avatar)
                          : null,
                      child: avatar == null ? Icon(Icons.person) : null,
                    ),
                    title: Text(name),
                    subtitle: Text(
                      lastMessage.length > 40
                          ? '${lastMessage.substring(0, 40)}...'
                          : lastMessage,
                    ),
                    trailing: timestamp != null
                        ? Text(
                            TimeOfDay.fromDateTime(timestamp).format(context),
                            style: TextStyle(fontSize: 12),
                          )
                        : null,
                    onTap: () {
                      final chatId = getChatId(currentUser.uid, otherUserId);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            chatId: chatId,
                            receiverId: otherUserId,
                            receiverName: name,
                            receiverAvatar: avatar,
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
