class Movie {
  final String movieTitle;
  final String releaseYear;
  final double rating;
  final String posterUrl;
  final String genre;
  final String synopsis;
  final String budget;
  final String boxOffice;
  final String ottPlatform;
  final bool isStreaming;
  final List<dynamic> cast;
  final int likes;
  final List<dynamic> commentsList;

  Movie({
    required this.movieTitle,
    required this.releaseYear,
    required this.rating,
    required this.posterUrl,
    required this.genre,
    required this.synopsis,
    required this.budget,
    required this.boxOffice,
    required this.ottPlatform,
    required this.isStreaming,
    required this.cast,
    required this.likes,
    required this.commentsList,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      movieTitle: json['movieTitle'] ?? "Unknown Title",
      // Ensure this line is exactly like this:
      releaseYear: json['releaseYear']?.toString() ?? "Year Unknown",
      rating:
          (json['rating'] as num?)?.toDouble() ??
          0.0, // This fixes your red screen error too!
      posterUrl: json['posterUrl'] ?? "",
      genre: json['genre'] ?? "General",
      synopsis: json['synopsis'] ?? "No synopsis available.",
      budget: json['budget'] ?? "N/A",
      boxOffice: json['boxOffice'] ?? "N/A",
      ottPlatform: json['ottPlatform'] ?? "Netflix",
      isStreaming: json['isStreaming'] ?? false,
      cast: json['cast'] ?? [],
      likes: json['likes'] ?? 0,
      commentsList: json['commentsList'] ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'movieTitle': movieTitle,
      'releaseYear': releaseYear,
      'rating': rating,
      'posterUrl': posterUrl,
      'genre': genre,
      'synopsis': synopsis,
      'budget': budget,
      'boxOffice': boxOffice,
      'ottPlatform': ottPlatform,
      'isStreaming': isStreaming,
      'cast': cast,
      'likes': likes,
      'commentsList': commentsList,
    };
  }
}
