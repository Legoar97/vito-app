// lib/models/chat_message.dart

// 1. Definimos el enum aquí para que todos puedan usarlo
enum MessageType { vito, user }

class ChatMessage {
  final String text;
  // 2. Usamos el enum en lugar del booleano 'isUser'
  final MessageType type; 
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.type,
    required this.timestamp,
  });
}