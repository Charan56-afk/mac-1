import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils.dart';

/// A self-contained account search result tile with real-time follow/unfollow.
class AccountSearchTile extends StatefulWidget {
  final Map<String, dynamic> account;
  final String localHandle;
  final bool isOwnAccount;
  final VoidCallback onTap;

  const AccountSearchTile({
    super.key,
    required this.account,
    required this.localHandle,
    required this.isOwnAccount,
    required this.onTap,
  });

  @override
  State<AccountSearchTile> createState() => _AccountSearchTileState();
}

class _AccountSearchTileState extends State<AccountSearchTile> {
  bool _isFollowing = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    if (widget.isOwnAccount) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/users/${widget.localHandle}/following'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(res.body);
        final List following = data['following'] ?? [];
        // API stores handle in 'userId' field (e.g. "@handle")
        setState(() {
          _isFollowing = following.any((u) => u['userId'] == widget.account['userHandle']);
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final handle = widget.account['userHandle'] as String;

    // Show unfollow confirmation
    if (_isFollowing) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: const Color(0xFF16181C),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: CacheUtility.getAvatarProvider(
                      widget.account['userAvatar'] ?? ''),
                ),
                const SizedBox(height: 14),
                Text(
                  'Unfollow ${widget.account['userName']}?',
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        ),
                        child: Text('Cancel',
                            style: GoogleFonts.outfit(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF0055),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                        child: Text('Unfollow',
                            style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      if (confirm != true) return;
    }

    // Optimistic update — store previous state for reliable revert
    final prevState = _isFollowing;
    setState(() {
      _isLoading = true;
      _isFollowing = !_isFollowing;
    });

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/users/$handle/follow'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userHandle': widget.localHandle}),
      );
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(res.body);
        // Backend confirmed to return 'isFollowing'
        setState(() => _isFollowing = data['isFollowing'] ?? !prevState);
      } else {
        if (mounted) setState(() => _isFollowing = prevState);
      }
    } catch (_) {
      if (mounted) setState(() => _isFollowing = prevState);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final acc = widget.account;
    final isVerified = acc['isVerified'] == true;
    final avatar = acc['userAvatar'] as String? ?? '';
    final followersCount = acc['followersCount'] as int? ?? 0;
    final bio = acc['bio'] as String? ?? '';

    return InkWell(
      onTap: widget.onTap,
      splashColor: const Color(0xFF00F0FF).withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar with neon ring for verified users
            Container(
              padding: isVerified ? const EdgeInsets.all(2) : EdgeInsets.zero,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isVerified
                    ? const LinearGradient(
                        colors: [Color(0xFF00F0FF), Color(0xFFB06EFF)])
                    : null,
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundImage: CacheUtility.getAvatarProvider(avatar),
                backgroundColor: Colors.grey[800],
              ),
            ),
            const SizedBox(width: 12),

            // Name / handle / bio / followers
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          acc['userName'] as String? ?? '',
                          style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF00F0FF), Color(0xFFB06EFF)],
                            ),
                          ),
                          child: const Icon(Icons.verified,
                              color: Colors.white, size: 11),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    acc['userHandle'] as String? ?? '',
                    style: GoogleFonts.outfit(
                        color: Colors.white38, fontSize: 13),
                  ),
                  if (bio.isNotEmpty)
                    Text(
                      bio,
                      style: GoogleFonts.outfit(
                          color: Colors.white54, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (followersCount > 0)
                    Text(
                      '$followersCount followers',
                      style: GoogleFonts.outfit(
                          color: Colors.white30, fontSize: 11),
                    ),
                ],
              ),
            ),

            // Follow / Following button (hidden for own account)
            if (!widget.isOwnAccount) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _isLoading ? null : _toggleFollow,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: _isFollowing
                        ? Colors.transparent
                        : const Color(0xFF00F0FF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isFollowing
                          ? Colors.white24
                          : const Color(0xFF00F0FF).withValues(alpha: 0.8),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _isFollowing
                                ? Colors.white38
                                : const Color(0xFF00F0FF),
                          ),
                        )
                      : Text(
                          _isFollowing ? 'Following' : 'Follow',
                          style: GoogleFonts.outfit(
                            color: _isFollowing
                                ? Colors.white38
                                : const Color(0xFF00F0FF),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

