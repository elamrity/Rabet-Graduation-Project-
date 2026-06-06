import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart'; // مكتبة التسجيل
import 'package:audioplayers/audioplayers.dart'; // مكتبة التشغيل
import 'package:path_provider/path_provider.dart'; // لتحديد مكان حفظ الصوت مؤقتاً
import 'package:intl/intl.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart'; // مكتبة الإيموجي

class ChatScreen extends StatefulWidget {
  final String? receiverId;
  final String? receiverName;

  const ChatScreen({super.key, this.receiverId, this.receiverName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode(); // التحكم في الفوكس والمؤشر

  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  final String currentName = FirebaseAuth.instance.currentUser!.displayName ?? "User";
  late DatabaseReference _chatRef;

  bool _isUploading = false;
  bool _isRecording = false; // حالة التسجيل الحالية
  bool _showEmoji = false; // متغير للتحكم في عرض قائمة الإيموجي
  late AudioRecorder _audioRecorder; // كائن التسجيل

  final String _imgbbApiKey = "8c7299bb1d2a54975921077cd52c2e81";

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();

    if (widget.receiverId == null) {
      _chatRef = FirebaseDatabase.instance.ref("public_chat");
    } else {
      List<String> ids = [currentUid, widget.receiverId!];
      ids.sort();
      _chatRef = FirebaseDatabase.instance.ref("private_chats/${ids.join('_')}");
    }

    // الاستماع لحالة الفوكس: لو المستخدم ضغط على حقل النص يختفي الإيموجي تلقائياً ويظهر الكيبورد العادي
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _showEmoji = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _msgController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // 🎙️ دالة بدء تسجيل الـ Voice Note
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        String filePath = '${dir.path}/vn_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: filePath);
        setState(() { _isRecording = true; });
      }
    } catch (e) {
      debugPrint("Error starting record: $e");
    }
  }

  // 🛑 دالة إيقاف التسجيل والرفع الفوري لـ Catbox
  Future<void> _stopAndSendRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() { _isRecording = false; });

      if (path != null) {
        setState(() { _isUploading = true; });
        File audioFile = File(path);

        var request = http.MultipartRequest('POST', Uri.parse('https://catbox.moe/user/api.php'));
        request.fields['reqtype'] = 'fileupload';
        request.files.add(await http.MultipartFile.fromPath('fileToUpload', audioFile.path));

        var response = await request.send();
        if (response.statusCode == 200) {
          String voiceUrl = await response.stream.bytesToString(); // رابط الصوت المباشر

          _chatRef.push().set({
            'senderId': currentUid,
            'senderName': currentName,
            'text': voiceUrl.trim(),
            'timestamp': ServerValue.timestamp,
            'type': 'audio',
            'status': 'sent',
          });
        }
        setState(() { _isUploading = false; });
        _scrollToBottom();
      }
    } catch (e) {
      setState(() { _isUploading = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ في إرسال الفويس: $e")));
    }
  }

  void _sendText() {
    if (_msgController.text.trim().isEmpty) return;
    final msgText = _msgController.text.trim();
    _msgController.clear();

    _chatRef.push().set({
      'senderId': currentUid,
      'senderName': currentName,
      'text': msgText,
      'timestamp': ServerValue.timestamp,
      'type': 'text',
      'status': 'sent',
    });
    setState(() {}); // إعادة البناء ليرجع الزرار مايك فوراً
    _scrollToBottom();
  }

  Future<void> _pickAndUploadToImgbb() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) {
        setState(() { _isUploading = true; });
        File file = File(result.files.single.path!);

        var request = http.MultipartRequest('POST', Uri.parse('https://api.imgbb.com/1/upload?key=$_imgbbApiKey'));
        request.files.add(await http.MultipartFile.fromPath('image', file.path));
        var response = await request.send();

        if (response.statusCode == 200) {
          var responseData = await response.stream.bytesToString();
          var jsonResponse = jsonDecode(responseData);
          String directImageUrl = jsonResponse['data']['url'];

          _chatRef.push().set({
            'senderId': currentUid,
            'senderName': currentName,
            'text': directImageUrl,
            'timestamp': ServerValue.timestamp,
            'type': 'image',
            'status': 'sent',
          });
        }
        setState(() { _isUploading = false; });
        _scrollToBottom();
      }
    } catch (e) {
      setState(() { _isUploading = false; });
    }
  }

  void _deleteMessage(String messageId, bool deleteForEveryone) {
    if (deleteForEveryone) {
      _chatRef.child(messageId).update({'text': '🚫 تم حذف هذه الرسالة', 'type': 'deleted'});
    } else {
      _chatRef.child(messageId).remove();
    }
  }

  void _showDeleteDialog(String messageId, bool isMyMessage) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2C34),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(15))),
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.white70),
              title: const Text("الحذف من عندي", style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _deleteMessage(messageId, false); },
            ),
            if (isMyMessage)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                title: const Text("الحذف لدى الجميع", style: TextStyle(color: Colors.redAccent)),
                onTap: () { Navigator.pop(context); _deleteMessage(messageId, true); },
              ),
          ],
        );
      },
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2C34),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(15))),
      builder: (context) {
        return SizedBox(
          height: 120,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _attachmentItem(Icons.image, "معرض الصور", Colors.purple, () {
                Navigator.pop(context);
                _pickAndUploadToImgbb();
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _attachmentItem(IconData icon, String text, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 25, backgroundColor: color, child: Icon(icon, color: Colors.white)),
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<bool> _onWillPop() {
    if (_showEmoji) {
      setState(() {
        _showEmoji = false;
      });
      return Future.value(false);
    }
    return Future.value(true);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B141A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1F2C34),
          title: Text(widget.receiverName ?? "GLOBAL CHAT", style: const TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Column(
          children: [
            if (_isUploading) const LinearProgressIndicator(color: Color(0xFF00A884), backgroundColor: Colors.transparent),
            Expanded(
              child: StreamBuilder<DatabaseEvent>(
                stream: _chatRef.onValue,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                    return const Center(child: Text("لا توجد رسائل بعد", style: TextStyle(color: Colors.white38)));
                  }
                  final Map data = snapshot.data!.snapshot.value as Map;
                  final msgs = data.entries.toList()..sort((a, b) => (a.value['timestamp'] ?? 0).compareTo(b.value['timestamp'] ?? 0));

                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: msgs.length,
                    itemBuilder: (context, i) {
                      final m = msgs[i].value;
                      final msgId = msgs[i].key!;
                      bool isMe = m['senderId'] == currentUid;

                      return GestureDetector(
                        onLongPress: () => _showDeleteDialog(msgId, isMe),
                        child: _Bubble(
                          text: m['text'] ?? '',
                          isMe: isMe,
                          name: m['senderName'] ?? '',
                          status: m['status'] ?? 'sent',
                          type: m['type'] ?? 'text',
                          timestamp: m['timestamp'],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            _buildInput(),

            // لوحة الإيموجي - مطابقة 100% لتعديلات كلاسات 4.4.0 الموضحة بالصورة
            if (_showEmoji)
              SizedBox(
                height: 250,
                child: EmojiPicker(
                  onEmojiSelected: (category, emoji) {
                    _msgController.text = _msgController.text + emoji.emoji;
                    setState(() {});
                  },
                  config: Config(
                    height: 250,
                    checkPlatformCompatibility: true,
                    emojiViewConfig: EmojiViewConfig(
                      columns: 7,
                      emojiSizeMax: 32,
                      verticalSpacing: 0,
                      horizontalSpacing: 0,
                      gridPadding: EdgeInsets.zero,
                      backgroundColor: const Color(0xFF1F2C34), // تم التعديل من bgColor إلى backgroundColor
                      loadingIndicator: const SizedBox.shrink(),
                      noRecents: const Text(
                        'لا توجد إيموجي مستخدمة مؤخراً',
                        style: TextStyle(fontSize: 16, color: Colors.white24),
                        textAlign: TextAlign.center,
                      ),
                      recentsLimit: 28,
                    ),
                    categoryViewConfig: const CategoryViewConfig(
                      initCategory: Category.RECENT,
                      backgroundColor: Color(0xFF1F2C34),
                      indicatorColor: Color(0xFF00A884),
                      iconColor: Colors.white30,
                      iconColorSelected: Color(0xFF00A884),
                      backspaceColor: Color(0xFF00A884),
                    ),
                    skinToneConfig: const SkinToneConfig(
                      dialogBackgroundColor: Color(0xFF2A3942), // تم التعديل من dialogBgColor إلى dialogBackgroundColor
                      indicatorColor: Colors.white30,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: const Color(0xFF1F2C34),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: const Color(0xFF2A3942), borderRadius: BorderRadius.circular(25)),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  // زرار الإيموجي / الكيبورد التفاعلي الذكي
                  IconButton(
                    icon: Icon(
                      _showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined,
                      color: Colors.white70,
                    ),
                    onPressed: () {
                      if (_showEmoji) {
                        setState(() {
                          _showEmoji = false;
                        });
                        _focusNode.requestFocus();
                      } else {
                        _focusNode.unfocus();
                        FocusScope.of(context).unfocus();

                        Future.delayed(const Duration(milliseconds: 150), () {
                          setState(() {
                            _showEmoji = true;
                          });
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _isRecording
                        ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Text("🔴 جاري تسجيل الفويس نوت...", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    )
                        : TextField(
                      controller: _msgController,
                      focusNode: _focusNode,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (val) {
                        setState(() {});
                      },
                      decoration: const InputDecoration(hintText: "مراسلة", hintStyle: TextStyle(color: Colors.white30), border: InputBorder.none),
                    ),
                  ),
                  if (!_isRecording)
                    IconButton(
                      icon: const Icon(Icons.attach_file, color: Colors.white30),
                      onPressed: _showAttachmentMenu,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: _msgController.text.trim().isNotEmpty ? _sendText : null,
            onLongPress: (_msgController.text.trim().isEmpty && !_isRecording) ? _startRecording : null,
            onLongPressUp: _isRecording ? _stopAndSendRecording : null,
            child: CircleAvatar(
              radius: 24,
              backgroundColor: _isRecording ? Colors.redAccent : const Color(0xFF00A884),
              child: Icon(
                  _isRecording
                      ? Icons.stop
                      : (_msgController.text.trim().isNotEmpty ? Icons.send : Icons.mic),
                  color: Colors.white,
                  size: 20
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text, name, status, type;
  final bool isMe;
  final int? timestamp;

  const _Bubble({required this.text, required this.isMe, required this.name, required this.status, required this.type, this.timestamp});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: type == 'deleted' ? Colors.transparent : (isMe ? const Color(0xFF005C4B) : const Color(0xFF202C33)),
          borderRadius: BorderRadius.circular(12),
          border: type == 'deleted' ? Border.all(color: Colors.white12) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe && type != 'deleted') Text(name, style: const TextStyle(color: Color(0xFF53BDEB), fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            _buildMessageContent(context),
            const SizedBox(height: 4),
            if (type != 'deleted')
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(timestamp != null ? DateFormat('hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(timestamp!)) : "...", style: const TextStyle(color: Colors.white54, fontSize: 10)),
                  const SizedBox(width: 4),
                  if (isMe) const Icon(Icons.check, size: 14, color: Colors.white38),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    if (type == 'image') {
      return GestureDetector(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => FullScreenImage(imageUrl: text)));
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(text, errorBuilder: (c, e, s) => const Text("خطأ في تحميل الصورة")),
        ),
      );
    } else if (type == 'audio') {
      return _VoicePlayer(audioUrl: text, isMe: isMe);
    } else if (type == 'deleted') {
      return Text(text, style: const TextStyle(color: Colors.white38, fontSize: 14, fontStyle: FontStyle.italic));
    } else {
      return Text(text, style: const TextStyle(color: Colors.white, fontSize: 15));
    }
  }
}

class _VoicePlayer extends StatefulWidget {
  final String audioUrl;
  final bool isMe;
  const _VoicePlayer({required this.audioUrl, required this.isMe});

  @override
  State<_VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<_VoicePlayer> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() { _isPlaying = state == PlayerState.playing; });
    });
    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() { _duration = newDuration; });
    });
    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() { _position = newPosition; });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(UrlSource(widget.audioUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.cyanAccent),
          onPressed: _playPause,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5)),
                child: Slider(
                  activeColor: Colors.cyanAccent,
                  inactiveColor: Colors.white24,
                  min: 0.0,
                  max: _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
                  value: _position.inMilliseconds.toDouble(),
                  onChanged: (v) async {
                    await _audioPlayer.seek(Duration(milliseconds: v.toInt()));
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                "${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}",
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            )
          ],
        ),
        const SizedBox(width: 4),
        const CircleAvatar(radius: 16, backgroundColor: Colors.white12, child: Icon(Icons.mic, size: 16, color: Colors.white)),
      ],
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final String imageUrl;
  const FullScreenImage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(child: InteractiveViewer(child: Image.network(imageUrl, fit: BoxFit.contain))),
    );
  }
}