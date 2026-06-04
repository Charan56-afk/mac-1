import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../cinematic_details_screen.dart';

class TrendingCarousel extends StatefulWidget {
  final List showing;

  const TrendingCarousel({super.key, required this.showing});

  @override
  State<TrendingCarousel> createState() => _TrendingCarouselState();
}

class _TrendingCarouselState extends State<TrendingCarousel> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.7);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showing.isEmpty) {
      return const Center(
        child: Text(
          "No movies showing",
          style: TextStyle(color: Colors.white54) ) );
    }

    return SizedBox(
      height: 380,
      child: PageView.builder(
        controller: _pageController,
        itemCount: widget.showing.length,
        // physics: const BouncingScrollPhysics(), // Removed to allow default physics (and better nesting)
        itemBuilder: (context, index) {
          return AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              double value = 0;
              if (_pageController.position.haveDimensions) {
                value = index - (_pageController.page ?? 0);
                value = (1 - (value.abs() * 0.3)).clamp(0.0, 1.0);
              } else {
                value = index == 0 ? 1.0 : 0.7; // Initial state
              }
              final curveValue = Curves.easeOut.transform(value);

              return Center(
                child: SizedBox(
                  height: curveValue * 380,
                  width: curveValue * 280,
                  child: child ) );
            },
            child: _CarouselItem(item: widget.showing[index]) );
        } ) );
  }
}

class _CarouselItem extends StatelessWidget {
  final Map item;

  const _CarouselItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _parseColor(item['statusColor']);

    return GestureDetector(
      onTap: () {
        Map movieData = {
          "movieTitle": item['title'],
          "posterUrl": item['imageUrl'],
          "rating": item['rating'] ?? 4.5,
          "genre": item['genre'] ?? "Trending",
          "synopsis": item['synopsis'] ?? "No synopsis available yet.",
          "budget": item['budget'] ?? "N/A",
          "boxOffice": item['boxOffice'] ?? "N/A",
          "runtime": item['runtime'] ?? "2h 30m",
          "cast": item['cast'] ?? [],
        };
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (c) => CinematicDetailsScreen(
              movie: movieData,
              heroTag: "carousel_${item['title']}" ) ) );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: 2 ),
          ] ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: item['imageUrl'] ?? "",
                fit: BoxFit.cover,
                
                
                placeholder: (c, u) => Container(color: Colors.grey[900]),
                errorWidget: (c, u, e) => Container(
                  color: Colors.grey[900],
                  child: const Icon(Icons.error, color: Colors.white) ) ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9)],
                    stops: const [0.6, 1.0] ) ) ),
              Positioned(
                bottom: 20,
                left: 15,
                right: 15,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'] ?? "Unknown",
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4 ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(8) ),
                      child: Text(
                        (item['status'] ?? "").toString().toUpperCase(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 10 ) ) ),
                  ] ) ),
            ] ) ) ) );
  }

  Color _parseColor(String? colorStr) {
    if (colorStr == null) return Colors.grey;
    try {
      return Color(int.parse(colorStr));
    } catch (e) {
      return Colors.grey;
    }
  }
}

