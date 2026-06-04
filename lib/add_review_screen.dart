import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';

import 'movie_details_screen.dart';
import 'package:flutter_application_1/constants.dart';

import 'services/http_cache_service.dart';
// [New] Import utils

class AddReviewScreen extends StatefulWidget {
  const AddReviewScreen({super.key});
  @override
  State<AddReviewScreen> createState() => _AddReviewScreenState();
}

class _AddReviewScreenState extends State<AddReviewScreen> {
  bool _isManualMode = false;
  List<Map<String, dynamic>> _existingMovies = [];
  List<Map<String, dynamic>> _filteredMovies = [];
  bool _isLoadingMovies = true;

  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _searchController = TextEditingController();
  final _titleController = TextEditingController();
  final _posterController = TextEditingController();
  final _synopsisController = TextEditingController();
  final _budgetController = TextEditingController();
  final _boxOfficeController = TextEditingController();
  final _commentController = TextEditingController();
  final _releaseYearController = TextEditingController();

  double _rating = 5.0;
  bool _isSubmitting = false;
  String _selectedGenre = "General";
  final List<String> _genres = [
    "Action",
    "Sci-Fi",
    "Drama",
    "Comedy",
    "Horror",
    "Romance",
    "Thriller",
    "General",
  ];

  // --- MANUAL CAST LIST ---
  final List<Map<String, String>> _manualCast = [];

  @override
  void initState() {
    super.initState();
    _fetchExistingMovies();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _fetchExistingMovies() async {
    try {
      final response = await HttpCacheService.get(Uri.parse(AppConstants.reviews));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final uniqueMovies = <String, Map<String, dynamic>>{};
        for (var item in data) {
          uniqueMovies[item['movieTitle'].toString()] =
              item as Map<String, dynamic>;
        }
        setState(() {
          _existingMovies = uniqueMovies.values.toList();
          _filteredMovies = _existingMovies;
          _isLoadingMovies = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingMovies = false);
    }
  }

  void _onSearchChanged() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredMovies = _existingMovies
          .where(
            (movie) =>
                movie['movieTitle'].toString().toLowerCase().contains(query) )
          .toList();
    });
  }

  // --- ADD ACTOR DIALOG ---
  void _showAddActorDialog() {
    TextEditingController nameCtrl = TextEditingController();
    TextEditingController roleCtrl = TextEditingController();
    TextEditingController imgCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: Text(
            "Add Cast Member",
            style: GoogleFonts.outfit(color: Colors.white) ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogInput(nameCtrl, "Actor Name (e.g. Prabhas)"),
              const SizedBox(height: 10),
              _buildDialogInput(roleCtrl, "Role (e.g. Bhairava)"),
              const SizedBox(height: 10),
              _buildDialogInput(imgCtrl, "Photo URL (Optional)"),
            ] ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel") ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00F0FF) ),
              onPressed: () {
                if (nameCtrl.text.isNotEmpty && roleCtrl.text.isNotEmpty) {
                  setState(() {
                    _manualCast.add({
                      "name": nameCtrl.text,
                      "role": roleCtrl.text,
                      "imageUrl": imgCtrl.text.isNotEmpty
                          ? imgCtrl.text
                          : "https://i.pravatar.cc/150?img=${_manualCast.length + 10}",
                    });
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text(
                "Add",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold ) ) ),
          ] );
      } );
  }

  Widget _buildDialogInput(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.black26,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)) ) );
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSubmitting = true);

    String finalPosterUrl = _posterController.text.trim();
    if (finalPosterUrl.isEmpty) {
      finalPosterUrl =
          "https://via.placeholder.com/300?text=${_titleController.text.replaceAll(' ', '+')}";
    }

    final newReview = {
      "movieTitle": _titleController.text,
      "rating": _rating,
      "comment": _commentController.text,
      "user": "Mobile_User_1",
      "posterUrl": finalPosterUrl,
      "genre": _selectedGenre,
      // --- SEND MANUAL DATA ---
      "synopsis": _synopsisController.text.isNotEmpty
          ? _synopsisController.text
          : "No synopsis provided.",
      "budget": _budgetController.text.isNotEmpty
          ? _budgetController.text
          : "N/A",
      "boxOffice": _boxOfficeController.text.isNotEmpty
          ? _boxOfficeController.text
          : "N/A",
      "releaseYear": _releaseYearController.text.isNotEmpty
          ? _releaseYearController.text
          : DateTime.now().year.toString(),
      "cast": _manualCast, // Send the list we built
      "likes": 0,
      "likedBy": [],
      "commentsList": [],
    };

    try {
      final response = await http.post(
        Uri.parse(AppConstants.reviews),
        headers: {"Content-Type": "application/json"},
        body: json.encode(newReview) );

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Review Added Successfully! 🚀")) );
          Navigator.pop(context);
        }
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red) );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      appBar: AppBar(
        title: Text(
          _isManualMode ? "CREATE ENTRY" : "SEARCH MOVIE",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white ) ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => _isManualMode
              ? setState(() => _isManualMode = false)
              : Navigator.pop(context) ) ),
      body: _isManualMode ? _buildManualForm() : _buildSearchScreen() );
  }

  Widget _buildSearchScreen() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: Color(0xFF00F0FF)),
              hintText: "Search existing movies...",
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15) ) ) ) ),
        Expanded(
          child: _isLoadingMovies
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _filteredMovies.length > 3
                      ? 3
                      : _filteredMovies.length,
                  itemBuilder: (context, index) {
                    final movie = _filteredMovies[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8 ),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: movie['posterUrl'] ?? "",
                          width: 50,
                          height: 75,
                          fit: BoxFit.cover, 
                          errorWidget: (c, u, e) => const Icon(Icons.error) ) ),
                      title: Text(
                        movie['movieTitle'],
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16 ) ),
                      subtitle: Text(
                        "Rating: ${movie['rating']}/5",
                        style: const TextStyle(color: Colors.white54) ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white24,
                        size: 16 ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MovieDetailsScreen(
                              movie: movie,
                              heroTag: "search_${movie['_id']}" ) ) );
                      } );
                  } ) ),
        GestureDetector(
          onTap: () {
            setState(() {
              _isManualMode = true;
              _titleController.text = _searchController.text;
            });
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00F0FF), Color(0xFF0088FF)] ),
              borderRadius: BorderRadius.circular(15) ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_circle_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Add a new movie manually",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16 ),
                    overflow: TextOverflow.ellipsis ) ),
              ] ) ) ),
      ] );
  }

  Widget _buildManualForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputHeader("Movie Title"),
            TextFormField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDeco("e.g. Kalki 2898 AD"),
              validator: (v) => v!.isEmpty ? "Required" : null ),
            const SizedBox(height: 20),

            _buildInputHeader("Genre"),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white24) ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedGenre,
                  dropdownColor: const Color(0xFF1A1A2E),
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: Color(0xFF00F0FF) ),
                  isExpanded: true,
                  style: const TextStyle(color: Colors.white),
                  items: _genres
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedGenre = v!) ) ) ),
            const SizedBox(height: 20),

            _buildInputHeader("Synopsis"),
            TextFormField(
              controller: _synopsisController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDeco("Write the plot summary here...") ),
            const SizedBox(height: 20),

            _buildInputHeader("Release Year"),
            TextFormField(
              controller: _releaseYearController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDeco("e.g. 2024"),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return null;
                } // optional
                final yr = int.tryParse(v);
                if (yr == null || yr < 1900 || yr > DateTime.now().year + 5) {
                  return "Enter a valid year";
                }
                return null;
              } ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInputHeader("Budget"),
                      TextFormField(
                        controller: _budgetController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDeco("\$600Cr") ),
                    ] ) ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInputHeader("Box Office"),
                      TextFormField(
                        controller: _boxOfficeController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDeco("\$1200Cr") ),
                    ] ) ),
              ] ),
            const SizedBox(height: 20),

            // --- CAST SECTION ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInputHeader("Cast Members"),
                TextButton.icon(
                  onPressed: _showAddActorDialog,
                  icon: const Icon(
                    Icons.add,
                    color: Color(0xFF00F0FF),
                    size: 18 ),
                  label: const Text(
                    "ADD ACTOR",
                    style: TextStyle(
                      color: Color(0xFF00F0FF),
                      fontWeight: FontWeight.bold ) ) ),
              ] ),
            if (_manualCast.isEmpty)
              const Text(
                "No actors added yet.",
                style: TextStyle(color: Colors.grey) ),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _manualCast.length,
              itemBuilder: (context, index) {
                final actor = _manualCast[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(actor['imageUrl']!) ),
                  title: Text(
                    actor['name']!,
                    style: const TextStyle(color: Colors.white) ),
                  subtitle: Text(
                    actor['role']!,
                    style: const TextStyle(color: Colors.white54) ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () =>
                        setState(() => _manualCast.removeAt(index)) ) );
              } ),
            const SizedBox(height: 20),

            _buildInputHeader("Poster URL"),
            TextFormField(
              controller: _posterController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDeco("http://image.jpg") ),
            const SizedBox(height: 20),

            _buildInputHeader("Rating: ${_rating.toInt()} Stars"),
            Slider(
              value: _rating,
              min: 1,
              max: 5,
              divisions: 4,
              activeColor: const Color(0xFFFF0055),
              onChanged: (val) => setState(() => _rating = val) ),
            const SizedBox(height: 20),

            _buildInputHeader("Your Review"),
            TextFormField(
              controller: _commentController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDeco("Short review...") ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00F0FF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15) ) ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.black)
                    : Text(
                        "POST REVIEW",
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 18 ) ) ) ),
          ] ) ) );
  }

  Widget _buildInputHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: GoogleFonts.outfit(color: const Color(0xFF00F0FF), fontSize: 16) ) );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15) );
  }
}
