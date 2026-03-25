// lib/src/services/podcast_notifications_stub.dart
/// Stub de "notificações de novos episódios".
/// Mantém compatibilidade sem Firebase. Caso você já use FCM,
/// adapte para assinar um tópico (ex.: "podcast_novos") e disparar do seu backend.
class PodcastNotifications {
  static Future<void> subscribe() async {
    // No-op por padrão. Integração opcional:
    // await FirebaseMessaging.instance.subscribeToTopic('podcast_novos');
  }

  static Future<void> unsubscribe() async {
    // No-op por padrão. Integração opcional:
    // await FirebaseMessaging.instance.unsubscribeFromTopic('podcast_novos');
  }
}