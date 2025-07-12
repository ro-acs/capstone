import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';

class ChatService {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  Stream<List<ChatMessage>> getMessages(String chatRoomId) {
    return _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessage.fromMap(doc.data()))
              .toList(),
        );
  }

  Future<void> sendMessage(String chatRoomId, ChatMessage message) async {
    await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add(message.toMap());

    await _firestore.collection('chats').doc(chatRoomId).set({
      'users': FieldValue.arrayUnion([message.senderId]),
      'lastMessage': message.text ?? '📷 Image',
      'lastTimestamp': message.timestamp.toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<String> uploadImage(File file, String chatRoomId) async {
    String fileName = const Uuid().v4();
    TaskSnapshot uploadTask = await _storage
        .ref('chat_images/$chatRoomId/$fileName.jpg')
        .putFile(file);
    return await uploadTask.ref.getDownloadURL();
  }

  Stream<QuerySnapshot> getChatRooms(String userId) {
    return _firestore
        .collection('chats')
        .where('users', arrayContains: userId)
        .orderBy('lastTimestamp', descending: true)
        .snapshots();
  }

  static String getChatRoomId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return "${sorted[0]}_${sorted[1]}";
  }
}
