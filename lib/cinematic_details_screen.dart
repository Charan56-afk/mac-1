import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

// =========================================================
// --- THE "OVERLAP / FLOATING POSTER" DETAILS SCREEN (Embedded) ---
// =========================================================
class CinematicDetailsScreen extends StatelessWidget {
  final Map movie;
  final String heroTag;

  const CinematicDetailsScreen({
    super.key,
    required this.movie,
    required this.heroTag,
  });

  // Theme Colors
  final Color kBgColor = const Color(0xFF0A0A0A);
  final Color kCardColor = const Color(0xFF1E1E1E);
  final Color kAccent = const Color(0xFFFF3366);

  Future<void> _launchBookingUrl(BuildContext context) async {
    const String bookingUrl = 'https://www.ticketnew.com';
    final Uri url = Uri.parse(bookingUrl);

    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: Cannot open booking link. ($e)"),
            backgroundColor: Colors.red ) );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = movie['movieTitle'] ?? "Untitled";
    final String poster = movie['posterUrl'] ?? "";
    final String synopsis = movie['synopsis'] ?? "No synopsis available.";
    final String rating = "${movie['rating'] ?? 0}";
    final List cast = movie['cast'] ?? [];
    // --- FIX: Define the runtime variable here! ---
    final String runtime = movie['runtime'] ?? "2h 30m";

    return Scaffold(
      backgroundColor: kBgColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 480,
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 300,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: poster,
                          fit: BoxFit.cover, 
                          errorWidget: (c, u, e) =>
                              Container(color: kCardColor) ),
                        Container(color: Colors.black.withValues(alpha: 0.6)),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, kBgColor],
                              stops: const [0.5, 1.0] ) ) ),
                      ] ) ),
                  Positioned(
                    top: 50,
                    left: 20,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white ),
                      onPressed: () => Navigator.pop(context) ) ),
                  Positioned(
                    top: 120,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Hero(
                        tag: heroTag,
                        child: Container(
                          height: 320,
                          width: 220,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: kAccent.withValues(alpha: 0.3),
                                blurRadius: 40,
                                offset: const Offset(0, 10) ),
                            ],
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1 ) ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: CachedNetworkImage(
                              imageUrl: poster,
                              fit: BoxFit.cover ) ) ) ) ) ),
                ] ) ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(
                    title.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.antonio(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5 ) ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildInfoPill("IMDb $rating", Icons.star, Colors.amber),
                      const SizedBox(width: 10),
                      // --- FIX: Now $runtime will work ---
                      _buildInfoPill(
                        runtime,
                        Icons.access_time,
                        Colors.white70 ),
                      const SizedBox(width: 10),
                      _buildInfoPill("4K", Icons.hd, kAccent),
                    ] ),
                ] ) ),

            const SizedBox(height: 30),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "THE STORY",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold ) ),
                  const SizedBox(height: 10),
                  Text(
                    synopsis,
                    style: GoogleFonts.outfit(
                      color: Colors.grey[400],
                      fontSize: 16,
                      height: 1.6 ) ),
                  const SizedBox(height: 30),
                  Text(
                    "CAST & CREW",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold ) ),
                  const SizedBox(height: 15),
                  cast.isEmpty
                      ? const Text(
                          "Loading Cast...",
                          style: TextStyle(color: Colors.grey) )
                      : SizedBox(
                          height: 90,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: cast.length,
                            itemBuilder: (context, index) {
                              final actor = cast[index];
                              return Container(
                                margin: const EdgeInsets.only(right: 20),
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: kCardColor,
                                      backgroundImage: NetworkImage(
                                        actor['imageUrl'] ?? "" ) ),
                                    const SizedBox(height: 8),
                                    Text(
                                      actor['name'] ?? "",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold ) ),
                                  ] ) );
                            } ) ),
                ] ) ),
            const SizedBox(height: 100),
          ] ) ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        width: double.infinity,
        height: 60,
        child: ElevatedButton(
          onPressed: () => _launchBookingUrl(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: kAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20) ),
            elevation: 10 ),
          child: const Text(
            "BOOK TICKETS",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1 ) ) ) ) );
  }

  Widget _buildInfoPill(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10) ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold ) ),
        ] ) );
  }
}
