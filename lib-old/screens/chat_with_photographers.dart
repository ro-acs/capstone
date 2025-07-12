import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class ChatWithPhotographersScreen extends StatelessWidget {
  final currentUser = FirebaseAuth.instance.currentUser!;

  String getChatId(String uid1, String uid2) {
    List<String> uids = [uid1, uid2];
    uids.sort();
    return '${uids[0]}_${uids[1]}';
  }

  void _startNewChat(BuildContext context) async {
    final photographersQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'photographer')
        .get();

    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        children: photographersQuery.docs.map((doc) {
          final data = doc.data();
          final name = data['name'];
          final avatar = data['avatarUrl'];
          final receiverId = doc.id;

          return ListTile(
            leading: CircleAvatar(
              backgroundImage: avatar != null ? NetworkImage(avatar) : null,
              child: avatar == null ? Icon(Icons.person) : null,
            ),
            title: Text(name ?? 'Photographer'),
            onTap: () {
              Navigator.pop(context);
              final chatId = getChatId(currentUser.uid, receiverId);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    chatId: chatId,
                    receiverId: receiverId,
                    receiverName: name,
                    receiverAvatar: avatar,
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Messages"),
        actions: [
          IconButton(
            icon: Icon(Icons.add_comment),
            onPressed: () => _startNewChat(context),
          ),
        ],
      ),
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

          if (chats.isEmpty)
            return Center(child: Text("No conversations yet."));

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
                  if (!userSnapshot.hasData || !userSnapshot.data!.exists)
                    return SizedBox.shrink();

                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>;
                  if (userData['role'] != 'photographer')
                    return SizedBox.shrink(); // Only show photographers

                  final name = userData['name'] ?? 'Photographer';
                  final avatarUrl = userData['avatarUrl'];

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: avatarUrl != null
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl == null ? Icon(Icons.person) : null,
                    ),
                    title: Text(name),
                    subtitle: Text(lastMessage),
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
                            receiverAvatar: avatarUrl,
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
