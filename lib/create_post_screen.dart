import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'utils.dart';
import 'package:flutter_application_1/constants.dart';


/// A Twitter / Instagram-style compose screen.
///
/// The user can:
/// - Write a text caption
/// - Pick up to 4 photos OR 1 video from the gallery / file manager
/// - Post it — files are uploaded to Cloudinary via the backend
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _captionController = TextEditingController();

  List<PlatformFile> _selectedMedia = [];
  bool _isVideo = false;
  bool _isPosting = false;

  // Dynamic user info fetched from CacheUtility
  String _userName = 'CineUser';
  String _userHandle = '@cineuser';
  String _userAvatar = 'https://i.pravatar.cc/150?img=11';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(_pulseController);
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final name = await CacheUtility.getProfileValue('name');
    final handle = await CacheUtility.getProfileValue(
      'handle',
    ); // Note: handle might not be natively saved by profile screen right now; using default if null
    final avatar = await CacheUtility.getProfileValue('avatar');

    if (mounted) {
      setState(() {
        if (name != null) _userName = name;
        if (handle != null) _userHandle = handle;
        if (avatar != null) _userAvatar = avatar;
      });
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Media picking via FilePicker ──────────────────────────────────
  Future<void> _pickMedia(FileType type) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: type,
        allowMultiple: type == FileType.image,
        withData: kIsWeb, // Needed for web
      );

      if (result == null) return;

      setState(() {
        _isVideo = type == FileType.video;
        if (_isVideo) {
          _selectedMedia = [result.files.first];
        } else {
          _selectedMedia = result.files.take(4).toList();
        }
      });
    } catch (e) {
      debugPrint('Error picking files: $e');
      _showSnack('Could not open file manager.', isError: true);
    }
  }

  void _removeMedia(int index) =>
      setState(() => _selectedMedia.removeAt(index));

  // ── Upload & post ────────────────────────────────────────────────
  Future<void> _submitPost() async {
    final caption = _captionController.text.trim();
    final hasMedia = _selectedMedia.isNotEmpty;

    if (caption.isEmpty && !hasMedia) {
      _showSnack('Add a caption or media before posting.', isError: true);
      return;
    }

    setState(() => _isPosting = true);

    try {
      final uri = Uri.parse('${AppConstants.posts}/upload');
      final request = http.MultipartRequest('POST', uri);

      // User info fields
      request.fields['userName'] = _userName;
      request.fields['userHandle'] = _userHandle;
      request.fields['userAvatar'] = _userAvatar;
      request.fields['caption'] = caption;

      // Attach file
      if (hasMedia) {
        final file = _selectedMedia.first;
        final mimeType =
            lookupMimeType(kIsWeb ? file.name : (file.path ?? file.name)) ??
            'application/octet-stream';
        final typeSplit = mimeType.split('/');

        if (kIsWeb) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              file.bytes!,
              filename: file.name,
              contentType: MediaType(typeSplit[0], typeSplit[1]),
            ),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath(
              'file',
              file.path!,
              filename: file.name,
              contentType: MediaType(typeSplit[0], typeSplit[1]),
            ),
          );
        }
      }

      final streamed = await request.send().timeout(
        const Duration(seconds: 90),
      );
      final status = streamed.statusCode;

      if (status == 201 || status == 200) {
        if (mounted) Navigator.pop(context, true); // signal success
      } else {
        final responseData = await streamed.stream.bytesToString();
        throw Exception('Server returned $status: $responseData');
      }
    } catch (e) {
      debugPrint('Post upload error: $e');
      _showSnack('Server busy. Please try again later.', isError: true);
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.outfit(color: Colors.white)),
        backgroundColor: isError ? Colors.red[700] : const Color(0xFF00F0FF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUserRow(),
                const SizedBox(height: 14),
                _buildCaptionField(),
                const SizedBox(height: 20),
                if (_selectedMedia.isNotEmpty)
                  _isVideo ? _buildVideoBadge() : _buildImagePreviews(),
                const SizedBox(height: 20),
                _buildMediaPickerRow(),
              ],
            ),
          ),
          if (_isPosting) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () => Navigator.pop(context, false),
      ),
      title: Text(
        'New Post',
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: Colors.white10, height: 0.5),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: _isPosting ? null : _submitPost,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isPosting
                      ? [Colors.grey[700]!, Colors.grey[600]!]
                      : [const Color(0xFF00F0FF), const Color(0xFF0072FF)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _isPosting ? 'Posting…' : 'Post',
                style: GoogleFonts.outfit(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserRow() {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundImage: CacheUtility.getAvatarProvider(_userAvatar),
          backgroundColor: Colors.grey[800],
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _userName,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            Text(
              _userHandle,
              style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCaptionField() {
    return TextField(
      controller: _captionController,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      style: GoogleFonts.outfit(color: Colors.white, fontSize: 17, height: 1.5),
      decoration: InputDecoration(
        hintText: "What's on your mind? #cinema #film…",
        hintStyle: GoogleFonts.outfit(color: Colors.white38, fontSize: 17),
        border: InputBorder.none,
      ),
    );
  }

  Widget _buildImagePreviews() {
    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedMedia.length,
        itemBuilder: (context, index) {
          final file = _selectedMedia[index];
          return Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF00F0FF).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: kIsWeb
                      ? Image.memory(file.bytes!, fit: BoxFit.cover)
                      : Image.file(File(file.path!), fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: 4,
                right: 12,
                child: GestureDetector(
                  onTap: () => _removeMedia(index),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black87,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVideoBadge() {
    final file = _selectedMedia.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF00F0FF).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.video_file_rounded,
            color: Color(0xFF00F0FF),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              file.name,
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => _removeMedia(0),
            child: const Icon(Icons.close, color: Colors.grey, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPickerRow() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _mediaButton(
          icon: Icons.image_rounded,
          label: 'Photos',
          color: const Color(0xFF00F0FF), // Cyan
          onTap: () => _pickMedia(FileType.image),
          active: _selectedMedia.isNotEmpty && !_isVideo,
        ),
        _mediaButton(
          icon: Icons.videocam_rounded,
          label: 'Videos',
          color: const Color(0xFF00FF85), // Neon Green
          onTap: () => _pickMedia(FileType.video),
          active: _selectedMedia.isNotEmpty && _isVideo,
        ),
      ],
    );
  }

  Widget _mediaButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.7) : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? color : Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: active ? color : Colors.grey,
                fontSize: 14,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00F0FF), Color(0xFF0072FF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00F0FF).withValues(alpha: 0.5),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.upload_rounded,
                  color: Colors.black,
                  size: 34,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Uploading your post…',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

