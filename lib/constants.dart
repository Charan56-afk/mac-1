import 'utils.dart'; // To access the dynamic baseUrl

class AppConstants {
  // API Endpoints
  static String get posts => '$baseUrl/api/posts';
  static String get reels => '$baseUrl/api/reels';
  static String get reviews => '$baseUrl/api/reviews';
  static String get industryBuzz => '$baseUrl/api/industry-buzz';
  static String get me => '$baseUrl/api/profile';
  static String get tollywoodTech => '$baseUrl/api/tollywood-tech';
  static String get hub => '$baseUrl/api/hub';
  static String get movies => '$baseUrl/api/movies';
  static String get directorsCut => '$baseUrl/api/directors-cut';
}
