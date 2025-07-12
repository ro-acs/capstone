import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart'; // You'll build this next

class ChatListScreen extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _getOtherParticipant(List participants, String currentUid) {
    return participants.firstWhere((id) => id != currentUid, orElse: () => '');
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      appBar: AppBar(title: Text('Messages')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('chats')
            .where('participants', arrayContains: currentUser.uid)
            .orderBy('lastTimestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());

          final chats = snapshot.data!.docs;

          if (chats.isEmpty)
            return Center(child: Text('No conversations yet.'));

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final data = chat.data() as Map<String, dynamic>;
              final otherUserId = _getOtherParticipant(
                data['participants'],
                currentUser.uid,
              );
              final lastMessage = data['lastMessage'] ?? '';
              final lastTime = (data['lastTimestamp'] as Timestamp?)?.toDate();

              return FutureBuilder<DocumentSnapshot>(
                future: _db.collection('users').doc(otherUserId).get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) return SizedBox();
                  final userData =
                      userSnap.data!.data() as Map<String, dynamic>;
                  final name = userData['email'] ?? 'User';
                  final profileUrl = userData['profileUrl'] ?? '';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: profileUrl.isNotEmpty
                          ? NetworkImage(profileUrl)
                          : null,
                      child: profileUrl.isEmpty
                          ? Icon(Icons.person, color: Colors.white)
                          : null,
                      backgroundColor: Colors.deepPurple.shade200,
                    ),
                    title: Text(name),
                    subtitle: Text(lastMessage),
                    trailing: Text(
                      lastTime != null
                          ? '${lastTime.hour}:${lastTime.minute.toString().padLeft(2, '0')}'
                          : '',
                      style: TextStyle(fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            chatId: chat.id,
                            otherUserId: otherUserId,
                            otherUserEmail: name,
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
