import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'services/movie_guess_service.dart';

class GuessMovieGameScreen extends StatefulWidget {
  const GuessMovieGameScreen({super.key});

  @override
  State<GuessMovieGameScreen> createState() => _GuessMovieGameScreenState();
}

class _GuessMovieGameScreenState extends State<GuessMovieGameScreen>
    with TickerProviderStateMixin {
  late MovieGuessService _service;
  GuessMovie? _movie;
  bool _loaded = false;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final List<String> _guesses = [];
  bool _won = false;
  bool _lost = false;
  bool _alreadyPlayed = false;
  int _streak = 0;
  final _messages = <_Message>[];

  late AnimationController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _init();
  }

  Future<void> _init() async {
    _service = await MovieGuessService.getInstance();
    final played = await _service.hasPlayedToday();
    final movie = _service.getTodaysMovie();
    final streak = await _service.getStreak();

    if (played) {
      final won = await _service.didWinToday();
      setState(() {
        _movie = movie;
        _alreadyPlayed = true;
        _won = won;
        _lost = !won;
        _loaded = true;
        _streak = streak;
      });
      if (won) _confettiController.forward();
      return;
    }

    setState(() {
      _movie = movie;
      _loaded = true;
      _streak = streak;
    });
  }

  void _submitGuess() {
    final text = _controller.text.trim();
    if (text.isEmpty || _won || _lost || _movie == null) return;

    final normalizedGuess = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '');
    final normalizedTitle = _movie!.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '');

    setState(() => _controller.clear());

    if (normalizedGuess == normalizedTitle) {
      _won = true;
      _service.markPlayed(won: true);
      _service.getStreak().then((s) => setState(() => _streak = s));
      _confettiController.forward();
      setState(() {
        _messages.insert(0, _Message(text: _movie!.title, type: _MessageType.correct));
      });
      return;
    }

    if (_guesses.length >= 4) {
      _lost = true;
      _service.markPlayed(won: false);
      _service.getStreak().then((s) => setState(() => _streak = s));
      setState(() {
        _messages.insert(0, _Message(text: _movie!.title, type: _MessageType.reveal));
      });
      return;
    }

    setState(() {
      _guesses.add(text);
      _messages.insert(0, _Message(text: text, type: _MessageType.wrong));
    });
  }

  double _blurSigma() {
    if (_won || _lost) return 0;
    final wrong = _guesses.length;
    switch (wrong) {
      case 0: return 20;
      case 1: return 14;
      case 2: return 8;
      case 3: return 4;
      case 4: return 1;
      default: return 0;
    }
  }

  String? _hintText() {
    if (_won || _lost) return null;
    final wrong = _guesses.length;
    if (_movie == null) return null;
    switch (wrong) {
      case 0: return null;
      case 1: return 'Released: ${_movie!.year}';
      case 2: return 'Starring: ${_movie!.leadActor}';
      case 3: return 'Genre: ${_movie!.genre}';
      case 4: return 'Director: ${_movie!.director}';
      default: return null;
    }
  }

  String _attemptsLeft() {
    final left = 5 - _guesses.length;
    return '$left/${_movie != null ? 5 : 0}';
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context) ),
        title: Text(
          '🎬 GUESS THE MOVIE',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 2 ) ),
        centerTitle: true ),
      body: _loaded ? _buildBody() : const Center(
        child: CircularProgressIndicator(color: Color(0xFF00F0FF)) ) );
  }

  Widget _buildBody() {
    return Column(
      children: [
        const SizedBox(height: 8),
        _buildStreakBar(),
        const SizedBox(height: 8),
        _buildPosterArea(),
        const SizedBox(height: 12),
        _buildHintArea(),
        const SizedBox(height: 8),
        _buildInputArea(),
        const SizedBox(height: 12),
        _buildMessageList(),
        const Spacer(),
        if (_won || _lost) _buildResultOverlay(),
        const SizedBox(height: 16),
      ] );
  }

  Widget _buildStreakBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFF8C00)] ),
            borderRadius: BorderRadius.circular(20) ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                '$_streak',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18 ) ),
              const SizedBox(width: 4),
              Text(
                'day streak',
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 13 ) ),
            ] ) ),
      ] );
  }

  Widget _buildPosterArea() {
    final blur = _blurSigma();
    final movie = _movie!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        height: 320,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _won
                ? const Color(0xFF00FF88)
                : _lost
                    ? const Color(0xFFFF0055)
                    : Colors.white12,
            width: 2 ),
          boxShadow: [
            if (_won)
              BoxShadow(
                color: const Color(0xFF00FF88).withValues(alpha: 0.4),
                blurRadius: 30,
                spreadRadius: 2 ),
          ] ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: movie.imageUrl,
                fit: BoxFit.cover ),
              if (blur > 0)
                Positioned.fill(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 400),
                    opacity: blur > 0 ? 1 : 0,
                    child: BackdropFilter(
                      filter: blur > 0
                          ? ColorFilter.mode(
                              Colors.black.withValues(alpha: 0.4),
                              BlendMode.srcOver )
                          : ColorFilter.mode(Colors.transparent, BlendMode.srcOver),
                      child: Container(color: Colors.transparent) ) ) ),
              if (blur > 0)
                Positioned.fill(
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                    child: CachedNetworkImage(
                      imageUrl: movie.imageUrl,
                      fit: BoxFit.cover ) ) ),
              if (_won)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF00FF88).withValues(alpha: 0.2),
                          Colors.transparent,
                        ] ) ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🎉', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 8),
                          Text(
                            'CORRECT!',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF00FF88),
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3 ) ),
                        ] ) ) ) ),
              if (_lost)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    child: Center(
                      child: Text(
                        movie.title,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800 ),
                        textAlign: TextAlign.center ) ) ) ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12) ),
                  child: Text(
                    _attemptsLeft(),
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600 ) ) ) ),
            ] ) ) ) );
  }

  Widget _buildHintArea() {
    final hint = _hintText();
    if (hint == null) return const SizedBox(height: 20);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF9D00FF).withValues(alpha: 0.2),
              const Color(0xFF00F0FF).withValues(alpha: 0.1),
            ] ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF9D00FF).withValues(alpha: 0.3)) ),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline, color: Color(0xFFFFD700), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hint,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500 ) ) ),
          ] ) ) );
  }

  Widget _buildInputArea() {
    if (_won || _lost || _alreadyPlayed) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Type movie name...',
                hintStyle: GoogleFonts.outfit(color: Colors.white24),
                filled: true,
                fillColor: const Color(0xFF0A0A14),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white12) ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white12) ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00F0FF)) ) ),
              onSubmitted: (_) => _submitGuess() ) ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _submitGuess,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00F0FF), Color(0xFF0080FF)] ),
                borderRadius: BorderRadius.circular(12) ),
              child: const Icon(Icons.arrow_forward, color: Colors.white, size: 22) ) ),
        ] ) );
  }

  Widget _buildMessageList() {
    return Expanded(
      child: ListView.builder(
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 40),
        itemCount: _messages.length,
        itemBuilder: (_, i) {
          final msg = _messages[i];
          final isCorrect = msg.type == _MessageType.correct;
          final isReveal = msg.type == _MessageType.reveal;
          Color bgColor;
          IconData icon;
          if (isCorrect) {
            bgColor = const Color(0xFF00FF88).withValues(alpha: 0.15);
            icon = Icons.check_circle_rounded;
          } else if (isReveal) {
            bgColor = const Color(0xFFFF0055).withValues(alpha: 0.15);
            icon = Icons.visibility_rounded;
          } else {
            bgColor = Colors.white.withValues(alpha: 0.05);
            icon = Icons.close_rounded;
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCorrect
                      ? const Color(0xFF00FF88).withValues(alpha: 0.4)
                      : isReveal
                          ? const Color(0xFFFF0055).withValues(alpha: 0.4)
                          : Colors.white12 ) ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: isCorrect ? const Color(0xFF00FF88) : isReveal ? const Color(0xFFFF0055) : Colors.white38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      msg.text,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: isCorrect ? FontWeight.w700 : FontWeight.w400 ) ) ),
                ] ) ) );
        } ) );
  }

  Widget _buildResultOverlay() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _won
                    ? [const Color(0xFF00FF88), const Color(0xFF00CC66)]
                    : [const Color(0xFFFF0055), const Color(0xFFCC0044)] ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (_won ? const Color(0xFF00FF88) : const Color(0xFFFF0055)).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8) ),
              ] ),
            child: GestureDetector(
              onTap: () {
                final sb = StringBuffer();
                sb.writeln('🎬 CineSocial - Guess the Movie!');
                sb.writeln(_won ? '✅ Won! $_streak🔥' : '❌ Lost');
                sb.writeln('Movie: ${_movie!.title}');
                final count = _guesses.length;
                sb.writeln('Guesses: $count/5');
                for (final g in _guesses) {
                  sb.writeln('⬜ $g');
                }
                sb.writeln('');
                sb.writeln('Play at CineSocial!');
                _copyToClipboard(sb.toString());
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _won ? Icons.share_rounded : Icons.share_rounded,
                    color: Colors.white,
                    size: 20 ),
                  const SizedBox(width: 8),
                  Text(
                    _won ? 'SHARE RESULT' : 'SHARE RESULT',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: 1 ) ),
                ] ) ) ),
          const SizedBox(height: 8),
          Text(
            _won
                ? 'Come back tomorrow for a new movie!'
                : 'The answer was: ${_movie!.title}',
            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12) ),
        ] ) );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied to clipboard!', style: GoogleFonts.outfit(color: Colors.white)),
        backgroundColor: const Color(0xFF1A1A2E),
        behavior: SnackBarBehavior.floating ) );
  }
}

enum _MessageType { correct, wrong, reveal }

class _Message {
  final String text;
  final _MessageType type;
  _Message({required this.text, required this.type});
}
