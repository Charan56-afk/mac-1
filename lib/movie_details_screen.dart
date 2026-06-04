import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'utils.dart';
import 'package:flutter_application_1/constants.dart';
import 'services/http_cache_service.dart';


class MovieDetailsScreen extends StatefulWidget {
  final Map movie;
  final String heroTag;

  const MovieDetailsScreen({
    super.key,
    required this.movie,
    required this.heroTag,
  });

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _chatController = TextEditingController();

  // STATE FOR ANIMATIONS
  bool isTriviaRevealed = false;
  late AnimationController _pulseController;

  // DYNAMIC DATA VARIABLES
  late String budget;
  late String boxOffice;
  late String synopsis;
  late List castList;
  late String ottPlatform;
  late bool isStreaming;
  late String releaseYear;

  // LIKES & COMMENTS STATE
  late bool isLiked;
  late int likeCount;
  late List comments;
  String currentUserId = "My_Mobile_User";


  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
      lowerBound: 0.8,
      upperBound: 1.0 )..repeat(reverse: true);

    budget = widget.movie['budget'] ?? "N/A";
    boxOffice = widget.movie['boxOffice'] ?? "N/A";
    synopsis = widget.movie['synopsis'] ?? "No synopsis available.";
    ottPlatform = widget.movie['ottPlatform'] ?? "Netflix";
    isStreaming = widget.movie['isStreaming'] ?? true;
    releaseYear = widget.movie['releaseYear']?.toString() ?? "N/A";

    // Seed from passed data first (instant render)
    // NOTE: isLiked intentionally starts false until currentUserId is known
    isLiked = false;
    likeCount = (widget.movie['likes'] ?? 0) is int
        ? widget.movie['likes'] ?? 0
        : int.tryParse(widget.movie['likes'].toString()) ?? 0;
    comments = List.from(widget.movie['commentsList'] ?? []);

    if (widget.movie['cast'] != null) {
      castList = widget.movie['cast'];
    } else {
      castList = [];
    }

    // Then load user identity and re-fetch latest data from server
    _initAsync();
  }

  Future<void> _initAsync() async {
    // 1. Get real userId from cache
    final handle =
        await CacheUtility.getFromCache('userHandle') ?? "My_Mobile_User";
    if (!mounted) {
      return;
    }
    setState(() {
      currentUserId = handle;
      final likedBy = (widget.movie['likedBy'] as List?)?.cast<String>() ?? [];
      isLiked = likedBy.contains(currentUserId);
    });

    // 2. Re-fetch the actual review from server (fresh likes + comments)
    await _fetchLatestData();
  }

  Future<void> _fetchLatestData() async {
    final id = widget.movie['_id'];
    if (id == null) {
      return;
    }
    try {
      final response = await HttpCacheService.get(
        Uri.parse('${AppConstants.reviews}/$id') );
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final freshLikedBy = List<String>.from(data['likedBy'] ?? []);
        setState(() {
          likeCount = (data['likes'] ?? 0) is int
              ? data['likes'] ?? 0
              : int.tryParse(data['likes'].toString()) ?? 0;
          isLiked = freshLikedBy.contains(currentUserId);
          comments = List.from(data['commentsList'] ?? []);

          // Mutate the passed map so parent screen updates
          widget.movie['likes'] = likeCount;
          widget.movie['likedBy'] = freshLikedBy;
          widget.movie['commentsList'] = comments;
        });
      }
    } catch (e) {
      debugPrint("Fresh fetch failed: $e");
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) {
      return;
    }
    _chatController.clear();

    // Optimistic update
    final optimistic = {"user": currentUserId, "text": text};
    setState(() {
      comments.add(optimistic);
      widget.movie['commentsList'] = comments;
    });

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.reviews}/${widget.movie['_id']}/comment'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"user": currentUserId, "text": text}) );
      if (response.statusCode == 200 && mounted) {
        // Replace optimistic list with authoritative server list
        final data = json.decode(response.body) as Map<String, dynamic>;
        setState(() {
          comments = List.from(data['commentsList'] ?? comments);
          widget.movie['commentsList'] = comments;
        });
      } else {
        _rollbackComment(optimistic);
      }
    } catch (e) {
      debugPrint("Comment failed: $e");
      _rollbackComment(optimistic);
    }
  }

  void _rollbackComment(Map optimistic) {
    if (mounted) {
      setState(() {
        comments.remove(optimistic);
        widget.movie['commentsList'] = comments;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine Rating Color
    double rating = (widget.movie['rating'] ?? 0).toDouble();
    Color ratingColor = rating >= 4.0
        ? Colors.greenAccent
        : (rating >= 2.5 ? Colors.amber : Colors.redAccent);

    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      // CHAT INPUT
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 10,
          left: 15,
          right: 15,
          top: 10 ),
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F1E),
          border: Border(top: BorderSide(color: Colors.white10)) ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _chatController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Join the discussion...",
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black26,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10 ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none ) ) ) ),
            const SizedBox(width: 10),
            CircleAvatar(
              backgroundColor: const Color(0xFF00F0FF),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.black, size: 18),
                onPressed: _addComment ) ),
          ] ) ),

      body: CustomScrollView(
        slivers: [
          // 1. HERO HEADER (Poster)
          SliverAppBar(
            expandedHeight: 400,
            backgroundColor: const Color(0xFF050510),
            pinned: true,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context) ) ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: widget.heroTag,
                    child: CachedNetworkImage(
                      imageUrl: widget.movie['posterUrl'] ?? "",
                      fit: BoxFit.cover,
                       
                      errorWidget: (c, u, e) => const Center(
                        child: Icon(Icons.broken_image, color: Colors.white) ) ) ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, const Color(0xFF050510)],
                        stops: const [0.5, 1.0] ) ) ),
                ] ) ) ),

          // 2. CONTENT BODY
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TITLE & GENRE
                  Text(
                    widget.movie['movieTitle'] ?? "Unknown Title",
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF00F0FF),
                      shadows: [
                        Shadow(
                          color: const Color(0xFF00F0FF).withValues(alpha: 0.5),
                          blurRadius: 20 ),
                      ] ) ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5 ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(20) ),
                        child: Text(
                          releaseYear,
                          style: const TextStyle(color: Colors.white) ) ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.movie['genre'] ?? "General",
                          style: const TextStyle(color: Colors.grey),
                          overflow: TextOverflow.ellipsis ) ),
                    ] ),
                  const SizedBox(height: 30),

                  // SYNOPSIS
                  Text(
                    "SYNOPSIS",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1 ) ),
                  const SizedBox(height: 10),
                  Text(
                    synopsis,
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.5 ) ),
                  const SizedBox(height: 30),

                  // HYPE PULSE
                  Text(
                    "GLOBAL HYPE",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1 ) ),
                  const SizedBox(height: 10),
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        height: 6,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(10) ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: 0.85 * _pulseController.value,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00F0FF), Color(0xFFFF0055)] ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF00F0FF ).withValues(alpha: 0.6),
                                  blurRadius: 10 * _pulseController.value ),
                              ] ) ) ) );
                    } ),
                  const SizedBox(height: 5),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "🔥 Trending Worldwide",
                      style: TextStyle(
                        color: Color(0xFFFF0055),
                        fontSize: 10,
                        fontStyle: FontStyle.italic ) ) ),
                  const SizedBox(height: 25),

                  // REAL STATS ROW
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10) ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStat("RATING", "⭐ $rating", ratingColor),
                        _buildVerticalLine(),
                        _buildStat("BUDGET", budget, const Color(0xFF00F0FF)),
                        _buildVerticalLine(),
                        _buildStat(
                          "BOX OFFICE",
                          boxOffice,
                          const Color(0xFFFF0055) ),
                      ] ) ),
                  const SizedBox(height: 30),

                  // STREAMING HUB
                  Text(
                    "STREAMING HUB",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1 ) ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF00F0FF).withValues(alpha: 0.1),
                          const Color(0xFFFF0055).withValues(alpha: 0.1),
                        ] ),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white12) ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "OTT RIGHTS",
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 10,
                                letterSpacing: 1 ) ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Icon(
                                  Icons.tv,
                                  color: Color(0xFF00F0FF),
                                  size: 18 ),
                                const SizedBox(width: 8),
                                Text(
                                  ottPlatform,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold ) ),
                              ] ),
                          ] ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6 ),
                          decoration: BoxDecoration(
                            color: isStreaming
                                ? const Color(0xFF00F0FF).withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isStreaming
                                  ? const Color(0xFF00F0FF)
                                  : Colors.white24 ) ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isStreaming
                                      ? const Color(0xFF00F0FF)
                                      : Colors.grey,
                                  boxShadow: isStreaming
                                      ? [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF00F0FF ).withValues(alpha: 0.6),
                                            blurRadius: 5 ),
                                        ]
                                      : [] ) ),
                              const SizedBox(width: 6),
                              Text(
                                isStreaming ? "STREAMING NOW" : "COMING SOON",
                                style: TextStyle(
                                  color: isStreaming
                                      ? const Color(0xFF00F0FF)
                                      : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10 ) ),
                            ] ) ),
                      ] ) ),

                  const SizedBox(height: 30),

                  // TRIVIA VAULT
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        isTriviaRevealed = !isTriviaRevealed;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isTriviaRevealed
                            ? const Color(0xFF00F0FF).withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isTriviaRevealed
                              ? const Color(0xFF00F0FF)
                              : Colors.white12 ) ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isTriviaRevealed ? Icons.lock_open : Icons.lock,
                                color: isTriviaRevealed
                                    ? const Color(0xFF00F0FF)
                                    : Colors.white70,
                                size: 18 ),
                              const SizedBox(width: 10),
                              Text(
                                isTriviaRevealed
                                    ? "TRIVIA UNLOCKED"
                                    : "TAP TO DECRYPT TRIVIA",
                                style: GoogleFonts.outfit(
                                  color: isTriviaRevealed
                                      ? const Color(0xFF00F0FF)
                                      : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2 ) ),
                            ] ),
                          if (isTriviaRevealed) ...[
                            const SizedBox(height: 10),
                            Text(
                              "Did you know? This movie was trending #1 on CineSocial for 3 weeks straight!",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 14 ) ),
                          ],
                        ] ) ) ),

                  const SizedBox(height: 30),

                  // --- CINESOCIAL OFFICIAL REVIEW ---
                  if ((widget.movie['cineSocialRating'] ?? 0) > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF00F0FF).withValues(alpha: 0.15),
                            const Color(0xFFFF0055).withValues(alpha: 0.05),
                          ] ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF00F0FF).withValues(alpha: 0.4),
                          width: 1.5 ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF00F0FF ).withValues(alpha: 0.1),
                            blurRadius: 20,
                            spreadRadius: 2 ),
                        ] ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.verified,
                                    color: Color(0xFF00F0FF),
                                    size: 22 ),
                                  const SizedBox(width: 10),
                                  Text(
                                    "CINESOCIAL OFFICIAL",
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF00F0FF),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      letterSpacing: 1.2 ) ),
                                ] ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4 ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00F0FF),
                                  borderRadius: BorderRadius.circular(10) ),
                                child: Text(
                                  "⭐ ${widget.movie['cineSocialRating']}",
                                  style: GoogleFonts.outfit(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14 ) ) ),
                            ] ),
                          const SizedBox(height: 15),
                          Text(
                            widget.movie['cineSocialReview'] ??
                                widget.movie['comment'] ??
                                "No official review provided.",
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                              height: 1.4 ) ),
                        ] ) ),
                    const SizedBox(height: 30),
                  ],

                  // --- UPDATED CAST LIST (ROBUST VERSION) ---
                  Text(
                    "THE CAST",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 1 ) ),
                  const SizedBox(height: 15),

                  castList.isEmpty
                      ? const Center(
                          child: Text(
                            "No cast information added.",
                            style: TextStyle(color: Colors.white54) ) )
                      : SizedBox(
                          height: 120, // Increased height for safety
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: castList.length,
                            itemBuilder: (context, index) {
                              final actor = castList[index];
                              final imageUrl = actor['imageUrl'] ?? "";
                              final name = actor['name'] ?? "Unknown";
                              final role = actor['role'] ?? "Actor";

                              return Container(
                                margin: const EdgeInsets.only(right: 20),
                                width: 80, // Constrain width for neatness
                                child: Column(
                                  children: [
                                    // ROBUST IMAGE CIRCLE
                                    Container(
                                      width: 70,
                                      height: 70,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white10,
                                        border: Border.all(
                                          color: Colors.white24 ) ),
                                      child: ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl: imageUrl,
                                          fit: BoxFit.cover,  
                                          errorWidget:
                                              (context, url, error) {
                                                return const Icon(
                                                  Icons.person,
                                                  color: Colors.white54,
                                                  size: 30 );
                                              },
                                          placeholder:
                                              (context, url) => const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white30 ) ) ) ) ),
                                    const SizedBox(height: 8),
                                    // TEXT
                                    Text(
                                      name,
                                      maxLines: 1,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold ) ),
                                    Text(
                                      role,
                                      maxLines: 1,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 10 ) ),
                                  ] ) );
                            } ) ),

                  const SizedBox(height: 30),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 20),

                  // FANS HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "FANS ASSOCIATION 📣",
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF00F0FF),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          letterSpacing: 1 ) ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5 ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF0055).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10) ),
                        child: Text(
                          "${comments.length} Active",
                          style: const TextStyle(
                            color: Color(0xFFFF0055),
                            fontSize: 12,
                            fontWeight: FontWeight.bold ) ) ),
                    ] ),
                  const SizedBox(height: 20),
                ] ) ) ),

          // FANS LIST
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final chat = comments[index];
              bool isMe = chat['user'] == currentUserId;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8 ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: isMe
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: [
                    if (!isMe)
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.grey[800],
                        child: Text(
                          (chat['user'] ?? "U")[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12 ) ) ),
                    if (!isMe) const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7 ),
                      decoration: BoxDecoration(
                        color: isMe
                            ? const Color(0xFF00F0FF).withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(15),
                          topRight: const Radius.circular(15),
                          bottomLeft: isMe
                              ? const Radius.circular(15)
                              : Radius.zero,
                          bottomRight: isMe
                              ? Radius.zero
                              : const Radius.circular(15) ),
                        border: Border.all(
                          color: isMe
                              ? const Color(0xFF00F0FF).withValues(alpha: 0.5)
                              : Colors.transparent ) ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMe)
                            Text(
                              chat['user']!,
                              style: const TextStyle(
                                color: Color(0xFF00F0FF),
                                fontSize: 10,
                                fontWeight: FontWeight.bold ) ),
                          if (!isMe) const SizedBox(height: 4),
                          Text(
                            chat['text'] ?? chat['msg'] ?? "",
                            style: const TextStyle(color: Colors.white) ),
                        ] ) ),
                  ] ) );
            }, childCount: comments.length) ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ] ) );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color ) ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 10,
            letterSpacing: 1 ) ),
      ] );
  }

  Widget _buildVerticalLine() {
    return Container(height: 30, width: 1, color: Colors.white12);
  }
}
