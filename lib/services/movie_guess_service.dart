import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class GuessMovie {
  final String title;
  final String imageUrl;
  final String year;
  final String leadActor;
  final String genre;
  final String director;
  final String hint;

  const GuessMovie({
    required this.title,
    required this.imageUrl,
    required this.year,
    required this.leadActor,
    required this.genre,
    required this.director,
    required this.hint,
  });
}

class MovieGuessService {
  static MovieGuessService? _instance;
  late SharedPreferences _prefs;

  MovieGuessService._();

  static Future<MovieGuessService> getInstance() async {
    if (_instance == null) {
      _instance = MovieGuessService._();
      _instance!._prefs = await SharedPreferences.getInstance();
    }
    return _instance!;
  }

  GuessMovie _getTodaysMovie() {
    final now = DateTime.now();
    final daySeed = now.year * 10000 + now.month * 100 + now.day;
    final rng = Random(daySeed);
    return _movies[rng.nextInt(_movies.length)];
  }

  GuessMovie getTodaysMovie() => _getTodaysMovie();

  Future<bool> hasPlayedToday() async {
    final today = _todayKey();
    final last = _prefs.getString('guess_last_played') ?? '';
    return last == today;
  }

  Future<void> markPlayed({required bool won}) async {
    final today = _todayKey();
    final yesterday = _yesterdayKey();
    final last = _prefs.getString('guess_last_played') ?? '';

    await _prefs.setString('guess_last_played', today);
    await _prefs.setBool('guess_won_$today', won);

    if (last == yesterday) {
      final streak = _prefs.getInt('guess_streak') ?? 0;
      await _prefs.setInt('guess_streak', won ? streak + 1 : 0);
    } else if (last == today) {
    } else {
      await _prefs.setInt('guess_streak', won ? 1 : 0);
    }
  }

  Future<bool> didWinToday() async {
    final today = _todayKey();
    return _prefs.getBool('guess_won_$today') ?? false;
  }

  Future<int> getStreak() async {
    return _prefs.getInt('guess_streak') ?? 0;
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _yesterdayKey() {
    final y = DateTime.now().subtract(const Duration(days: 1));
    return '${y.year}-${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';
  }

  static const List<GuessMovie> _movies = [
    GuessMovie(
      title: 'Pushpa: The Rise',
      imageUrl: 'https://res.cloudinary.com/do8vmbj7b/image/upload/v1738238474/pushpa1_poster_qjqxa7.jpg',
      year: '2021',
      leadActor: 'Allu Arjun',
      genre: 'Action / Drama',
      director: 'Sukumar',
      hint: 'The rise is wild',
    ),
    GuessMovie(
      title: 'RRR',
      imageUrl: 'https://res.cloudinary.com/do8vmbj7b/image/upload/v1738238474/rrr_poster_jxqxfh.jpg',
      year: '2022',
      leadActor: 'NTR Jr & Ram Charan',
      genre: 'Period Action',
      director: 'SS Rajamouli',
      hint: 'Fire, water, and friendship',
    ),
    GuessMovie(
      title: 'Baahubali 2',
      imageUrl: 'https://res.cloudinary.com/do8vmbj7b/image/upload/v1738238474/bb2_poster_tiqwrw.jpg',
      year: '2017',
      leadActor: 'Prabhas',
      genre: 'Epic Fantasy',
      director: 'SS Rajamouli',
      hint: 'Why did Kattappa kill him?',
    ),
    GuessMovie(
      title: 'Ala Vaikunthapurramuloo',
      imageUrl: 'https://res.cloudinary.com/do8vmbj7b/image/upload/v1738238474/ala_poster_yukppr.jpg',
      year: '2020',
      leadActor: 'Allu Arjun',
      genre: 'Family Drama',
      director: 'Trivikram',
      hint: 'Samajavaragamana',
    ),
    GuessMovie(
      title: 'Salaar',
      imageUrl: 'https://res.cloudinary.com/do8vmbj7b/image/upload/v1738238474/salaar_poster_uzwdin.jpg',
      year: '2023',
      leadActor: 'Prabhas',
      genre: 'Action Thriller',
      director: 'Prashanth Neel',
      hint: 'The rebellion begins',
    ),
    GuessMovie(
      title: 'Kalki 2898 AD',
      imageUrl: 'https://res.cloudinary.com/do8vmbj7b/image/upload/v1738238474/kalki_poster_xozkz4.jpg',
      year: '2024',
      leadActor: 'Prabhas',
      genre: 'Sci-Fi Mythology',
      director: 'Nag Ashwin',
      hint: 'The future meets the past',
    ),
    GuessMovie(
      title: 'Devara',
      imageUrl: 'https://res.cloudinary.com/do8vmbj7b/image/upload/v1738238474/devara_poster_vy6smb.jpg',
      year: '2024',
      leadActor: 'NTR Jr',
      genre: 'Action Drama',
      director: 'Koratala Siva',
      hint: 'Fear the sea',
    ),
    GuessMovie(
      title: 'Baahubali',
      imageUrl: 'https://res.cloudinary.com/do8vmbj7b/image/upload/v1738238474/bb1_poster_izjqnt.jpg',
      year: '2015',
      leadActor: 'Prabhas',
      genre: 'Epic Fantasy',
      director: 'SS Rajamouli',
      hint: 'The beginning of a legend',
    ),
    GuessMovie(
      title: 'Sarileru Neekevvaru',
      imageUrl: 'https://res.cloudinary.com/do8vmbj7b/image/upload/v1738238474/sarileru_poster_ne5pko.jpg',
      year: '2020',
      leadActor: 'Mahesh Babu',
      genre: 'Action Comedy',
      director: 'Anil Ravipudi',
      hint: 'An army major on a mission',
    ),
    GuessMovie(
      title: 'Waltair Veerayya',
      imageUrl: 'https://res.cloudinary.com/do8vmbj7b/image/upload/v1738238474/waltair_poster_qhg3or.jpg',
      year: '2023',
      leadActor: 'Chiranjeevi',
      genre: 'Action Comedy',
      director: 'K. S. Ravi Kumar',
      hint: 'The legend returns',
    ),
    GuessMovie(
      title: 'Game Changer',
      imageUrl: 'https://res.cloudinary.com/do8vmbj7b/image/upload/v1738238474/gamechanger_poster_udbtpn.jpg',
      year: '2025',
      leadActor: 'Ram Charan',
      genre: 'Political Thriller',
      director: 'Shankar',
      hint: 'The rule of the game',
    ),
    GuessMovie(
      title: 'Vikramarkudu',
      imageUrl: 'https://res.cloudinary.com/do8vmbj7b/image/upload/v1738238474/vikramarkudu_poster_f5frtb.jpg',
      year: '2006',
      leadActor: 'Ravi Teja',
      genre: 'Action Drama',
      director: 'S. S. Rajamouli',
      hint: 'Double the action',
    ),
    GuessMovie(
      title: 'Magadheera',
      imageUrl: 'https://res.cloudinary.com/do8vmbj7b/image/upload/v1738238474/magadheera_poster_nxcvza.jpg',
      year: '2009',
      leadActor: 'Ram Charan',
      genre: 'Period Action',
      director: 'S. S. Rajamouli',
      hint: 'A love story across lifetimes',
    ),
    GuessMovie(
      title: 'Maharshi',
      imageUrl: 'https://res.cloudinary.com/do8vmbj7b/image/upload/v1738238474/maharshi_poster_jv7d31.jpg',
      year: '2019',
      leadActor: 'Mahesh Babu',
      genre: 'Drama',
      director: 'Vamsi Paidipally',
      hint: 'From CEO to farmer',
    ),
    GuessMovie(
      title: 'Aravinda Sametha',
      imageUrl: 'https://res.cloudinary.com/do8vmbj7b/image/upload/v1738238474/aravinda_poster_ymjdwp.jpg',
      year: '2018',
      leadActor: 'NTR Jr',
      genre: 'Action Drama',
      director: 'Trivikram',
      hint: 'Blood and redemption',
    ),
    GuessMovie(
      title: 'Jersey',
      imageUrl: 'https://res.cloudinary.com/do8vmbj7b/image/upload/v1738238474/jersey_poster_fzcon0.jpg',
      year: '2019',
      leadActor: 'Nani',
      genre: 'Sports Drama',
      director: 'Gowtam Tinnanuri',
      hint: 'A father\'s dream',
    ),
    GuessMovie(
      title: 'Mahanati',
      imageUrl: 'https://res.cloudinary.com/do8vmbj7b/image/upload/v1738238474/mahanati_poster_ijgq3s.jpg',
      year: '2018',
      leadActor: 'Keerthy Suresh',
      genre: 'Biopic',
      director: 'Nag Ashwin',
      hint: 'The queen of cinema',
    ),
    GuessMovie(
      title: 'Eega',
      imageUrl: 'https://res.cloudinary.com/do8vmbj7b/image/upload/v1738238474/eega_poster_j71qzt.jpg',
      year: '2012',
      leadActor: 'Nani / Sudeep',
      genre: 'Fantasy Revenge',
      director: 'S. S. Rajamouli',
      hint: 'Revenge has wings',
    ),
    GuessMovie(
      title: 'Rangasthalam',
      imageUrl: 'https://res.cloudinary.com/do8vmbj7b/image/upload/v1738238474/rangasthalam_poster_gj7sn1.jpg',
      year: '2018',
      leadActor: 'Ram Charan',
      genre: 'Period Drama',
      director: 'Sukumar',
      hint: 'The village that fought back',
    ),
    GuessMovie(
      title: 'Geetha Govindam',
      imageUrl: 'https://res.cloudinary.com/do8vmbj7b/image/upload/v1738238474/geetha_poster_cnztbm.jpg',
      year: '2018',
      leadActor: 'Vijay Deverakonda',
      genre: 'Romantic Comedy',
      director: 'Parasuram',
      hint: 'A marriage proposal gone wrong',
    ),
  ];
}
