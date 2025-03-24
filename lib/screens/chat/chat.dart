import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rideshare/providers/user_state.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_parsed_text/flutter_parsed_text.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatScreen extends StatefulWidget {
  final UserState userState;
  final types.Room room;
  const ChatScreen({super.key, required this.userState, required this.room});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  Timer? _timer;
  Stream<QuerySnapshot>? _messagesStream;
  late List<types.Message> _messages;
  late types.User _user;

  @override
  void initState() {
    super.initState();
    _messagesStream = FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.userState.currentUser!.companyName)
        .collection('chatRooms')
        .doc(widget.room.id)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();
    _user = widget.userState.currentUser!.toChatUser();
    _messages = widget.room.lastMessages ?? [];
    _startTimer();
  }

  @override
  void dispose() {
    _cancelTimer();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      widget.userState.setStoredChatRoom(
          widget.room.id, widget.room.copyWith(lastMessages: _messages));
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
  }

  Future<void> _sendMessage(types.Message message) async {
    if (message.type == types.MessageType.text) {
      message = message.copyWith(status: types.Status.sending);
      setState(() {
        _messages.insert(0, message);
      });
    }
    try {
      final messagesRef = FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.userState.currentUser!.companyName)
          .collection('chatRooms')
          .doc(widget.room.id)
          .collection('messages');
      final messageData = message.toJson();
      await messagesRef.add(messageData).timeout(
            const Duration(seconds: 10),
            onTimeout: () =>
                throw TimeoutException('Sending message timed out'),
          );
      setState(() {
        final index = _messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          _messages[index] = message.copyWith(status: types.Status.sent);
        }
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (message.type == types.MessageType.text) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == message.id);
          if (index != -1) {
            _messages[index] = message.copyWith(status: types.Status.error);
          }
        });
      }
    }
  }

  void _handleSendPressed(types.PartialText message) {
    final textMessage = types.TextMessage(
      author: types.User(id: _user.id),
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: message.text,
    );
    _sendMessage(textMessage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.name ?? 'Chat'),
        actions: [
          // Voice Call Button
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CallPage(
                    userId: _user.id,
                    userName: _user.firstName ?? 'User',
                    callId: widget.room.id,
                    isVideoCall: false,
                  ),
                ),
              );
            },
            tooltip: 'Voice Call',
          ),
          // Video Call Button
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CallPage(
                    userId: _user.id,
                    userName: _user.firstName ?? 'User',
                    callId: widget.room.id,
                    isVideoCall: true,
                  ),
                ),
              );
            },
            tooltip: 'Video Call',
          ),
        ],
      ),
      body: _messagesStream == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.active) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final newMessages = snapshot.data?.docs
                    .map((doc) {
                      final messageData = doc.data() as Map<String, dynamic>;
                      types.Message message =
                          types.Message.fromJson(messageData);
                      return message.author.id == _user.id
                          ? message.copyWith(status: types.Status.sent)
                          : message.copyWith(status: types.Status.seen);
                    })
                    .where((message) =>
                        message.createdAt! >
                        (_messages.isNotEmpty ? _messages.first.createdAt! : 0))
                    .toList();

                _messages.insertAll(0, newMessages ?? []);
                _messages = _fetchUsersByMessages(_messages);

                return Chat(
                  messages: _messages,
                  onAttachmentPressed: _handleAttachmentPressed,
                  onMessageTap: _handleMessageTap,
                  onPreviewDataFetched: _handlePreviewDataFetched,
                  onSendPressed: _handleSendPressed,
                  showUserAvatars:
                      widget.room.type == types.RoomType.channel ? false : true,
                  showUserNames: true,
                  timeFormat: DateFormat('h:mm a'),
                  user: _user,
                  imageMessageBuilder: (imageMessage,
                          {required messageWidth}) =>
                      CachedNetworkImage(
                    imageUrl: imageMessage.uri,
                    width: messageWidth * 0.8,
                    placeholder: (context, url) =>
                        const CircularProgressIndicator(),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error),
                  ),
                  customBottomWidget: widget.room.type == types.RoomType.channel
                      ? const SizedBox(height: 16)
                      : null,
                  textMessageOptions: TextMessageOptions(matchers: [
                    MatchText(
                      pattern: '```[^`]+```',
                      style: PatternStyle.code.textStyle,
                      renderText:
                          ({required String str, required String pattern}) => {
                        'display': str.replaceAll('```', ''),
                      },
                    ),
                  ]),
                );
              },
            ),
    );
  }

  types.Message _fetchUserByMessage(types.Message message) {
    if (widget.userState.storedUsers.containsKey(message.author.id)) {
      final user = widget.userState.storedUsers[message.author.id];
      return message.copyWith(author: user!.toChatUser());
    } else if (message.author.id == 'notifications') {
      return message.copyWith(author: const types.User(id: 'notifications'));
    } else {
      widget.userState.getStoredUserByEmail(message.author.id);
      return message;
    }
  }

  List<types.Message> _fetchUsersByMessages(List<types.Message> messages) {
    return messages.map(_fetchUserByMessage).toList();
  }

  void _handleAttachmentPressed() {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: SizedBox(
          height: 144,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleImageSelection();
                },
                child: const Row(children: [
                  Icon(Icons.photo),
                  SizedBox(width: 8),
                  Text('Photo'),
                ]),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleFileSelection();
                },
                child: const Row(children: [
                  Icon(Icons.attach_file),
                  SizedBox(width: 8),
                  Text('File'),
                ]),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Row(children: [
                  Icon(Icons.cancel),
                  SizedBox(width: 8),
                  Text('Cancel'),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleFileSelection() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.single.path == null) return;

    final placeholderMessage = types.FileMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      mimeType: lookupMimeType(result.files.single.path!),
      name: result.files.single.name,
      size: result.files.single.size,
      uri: result.files.single.path!,
      status: types.Status.sending,
    );
    setState(() => _messages.insert(0, placeholderMessage));

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_files')
          .child(widget.userState.currentUser!.companyName)
          .child(widget.room.id)
          .child(_generateUniqueFileName(result.files.single.name));

      final uploadTask = storageRef.putFile(
        File(result.files.single.path!),
        SettableMetadata(
            contentType: lookupMimeType(result.files.single.path!)),
      );
      final snapshot = await uploadTask.timeout(const Duration(seconds: 120),
          onTimeout: () => throw TimeoutException('File upload timed out'));
      final downloadUrl = await snapshot.ref.getDownloadURL();

      final message = placeholderMessage.copyWith(
          uri: downloadUrl, status: types.Status.sent);
      _sendMessage(message);
    } catch (e) {
      debugPrint('Error sending file: $e');
      setState(() {
        final index =
            _messages.indexWhere((m) => m.id == placeholderMessage.id);
        if (index != -1) {
          _messages[index] =
              placeholderMessage.copyWith(status: types.Status.error);
        }
      });
    }
  }

  Future<void> _handleImageSelection() async {
    final result = await ImagePicker().pickImage(
      imageQuality: 70,
      maxWidth: 1440,
      source: ImageSource.gallery,
    );
    if (result == null) return;

    final bytes = await result.readAsBytes();
    final image = await decodeImageFromList(bytes);
    final placeholderMessage = types.ImageMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      height: image.height.toDouble(),
      id: const Uuid().v4(),
      name: result.name,
      size: bytes.length,
      uri: result.path,
      width: image.width.toDouble(),
      status: types.Status.sending,
    );
    setState(() => _messages.insert(0, placeholderMessage));

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child(widget.userState.currentUser!.companyName)
          .child(widget.room.id)
          .child(result.name);

      final uploadTask = storageRef.putData(bytes);
      final snapshot = await uploadTask.timeout(const Duration(seconds: 120),
          onTimeout: () => throw TimeoutException('Image upload timed out'));
      final downloadUrl = await snapshot.ref.getDownloadURL();

      final message = placeholderMessage.copyWith(
          uri: downloadUrl, status: types.Status.sent);
      _sendMessage(message);
    } catch (e) {
      debugPrint('Error sending image: $e');
      setState(() {
        final index =
            _messages.indexWhere((m) => m.id == placeholderMessage.id);
        if (index != -1) {
          _messages[index] =
              placeholderMessage.copyWith(status: types.Status.error);
        }
      });
    }
  }

  void _handleMessageTap(BuildContext _, types.Message message) async {
    if (message is types.FileMessage) {
      var localPath = message.uri;
      if (message.uri.startsWith('http')) {
        try {
          final index =
              _messages.indexWhere((element) => element.id == message.id);
          setState(
              () => _messages[index] = (message).copyWith(isLoading: true));

          final documentsDir = (await getApplicationDocumentsDirectory()).path;
          localPath = '$documentsDir/${message.name}';
          if (!File(localPath).existsSync()) {
            final request = await http.Client().get(Uri.parse(message.uri));
            await File(localPath).writeAsBytes(request.bodyBytes);
          }
        } finally {
          final index =
              _messages.indexWhere((element) => element.id == message.id);
          setState(
              () => _messages[index] = (message).copyWith(isLoading: null));
        }
      }
      await OpenFilex.open(localPath);
    }
  }

  void _handlePreviewDataFetched(
      types.TextMessage message, types.PreviewData previewData) {
    final index = _messages.indexWhere((element) => element.id == message.id);
    if (index != -1) {
      setState(
          () => _messages[index] = message.copyWith(previewData: previewData));
    }
  }

  String _generateUniqueFileName(String originalName) {
    final dotIndex = originalName.lastIndexOf('.');
    final hasExtension = dotIndex != -1;
    final extension = hasExtension ? originalName.substring(dotIndex) : '';
    final baseName =
        hasExtension ? originalName.substring(0, dotIndex) : originalName;
    return '$baseName${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}$extension';
  }
}

// ZEGOCLOUD Call Page Widget
class CallPage extends StatelessWidget {
  final String userId;
  final String userName;
  final String callId;
  final bool isVideoCall;

  const CallPage({
    super.key,
    required this.userId,
    required this.userName,
    required this.callId,
    required this.isVideoCall,
  });

  @override
  Widget build(BuildContext context) {
    // Create the call configuration
    final callConfig = isVideoCall
        ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
        : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();

    // Set the onHangUp callback to navigate back when the call ends

    return ZegoUIKitPrebuiltCall(
      appID: int.parse(dotenv.env['ZEGO_APP_ID'] ?? '0'), // Load from .env
      appSign: dotenv.env['ZEGO_APP_SIGN'] ?? '', // Load from .env
      userID: userId,
      userName: userName,
      callID: callId,
      config: callConfig,
    );
  }
}
