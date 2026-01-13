import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_markdown_selectionarea/flutter_markdown_selectionarea.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const NotesLensApp());

class NotesLensApp extends StatelessWidget {
  const NotesLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
      ),
      home: const NotesLensHome(),
    );
  }
}

class NotesLensHome extends StatefulWidget {
  const NotesLensHome({super.key});

  @override
  State<NotesLensHome> createState() => _NotesLensHomeState();
}

class _NotesLensHomeState extends State<NotesLensHome> {
  Uint8List? _selectedImage;
  String _aiResponse = "";
  List<String> _flashcardsList = [];
  bool _isProcessing = false;

  // FIXED: standalone YouTube Launcher with smart fallback
  Future<void> _launchYouTube() async {
    String query = "";

    if (_aiResponse.contains("TOPIC_FOR_SEARCH:")) {
      query = _aiResponse.split("TOPIC_FOR_SEARCH:").last.trim();
    } else if (_aiResponse.isNotEmpty) {
      // Clean the first line of any markdown or noise
      query = _aiResponse.split('\n').first.replaceAll(RegExp(r'[#*]'), '').trim();
      if (query.length < 3) query = "Study Lesson";
    } else {
      query = "Study Lesson";
    }

    final String url = "https://www.youtube.com/results?search_query=${Uri.encodeComponent(query + " tutorial")}";
    final Uri uri = Uri.parse(url);

    try {
      // Launch in external application for better user experience
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error opening YouTube: $e")),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedImage = bytes;
        _isProcessing = true;
        _aiResponse = "";
        _flashcardsList = [];
      });
      _askGemini(bytes);
    }
  }

  Future<void> _askGemini(Uint8List bytes) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-3-flash-preview', 
        apiKey: 'AIzaSyARyLUvKsR97fCI5qZn5YeVeB08GQxUGs0', 
      );
      
      final prompt = TextPart(
        "Explain these notes like a tutor. At the very end, provide exactly 4 flashcards. "
        "Format flashcards exactly like this: Q: Question? | A: Answer. "
        "End with TOPIC_FOR_SEARCH: followed by the topic name."
      );
      
      final content = [Content.multi([prompt, DataPart('image/jpeg', bytes)])];
      final response = await model.generateContent(content);
      
      if (mounted) {
        setState(() {
          String res = response.text ?? "";
          
          if (res.contains("Q:")) {
            var parts = res.split(RegExp(r'Q:'));
            _aiResponse = parts[0].split("TOPIC_FOR_SEARCH:")[0];
            
            for (var i = 1; i < parts.length; i++) {
              String card = parts[i].split("TOPIC_FOR_SEARCH:")[0].trim();
              if (card.isNotEmpty) _flashcardsList.add("Q: $card");
            }
          } else {
            _aiResponse = res.split("TOPIC_FOR_SEARCH:")[0];
          }
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _aiResponse = "Error: $e"; _isProcessing = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      drawer: _buildDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("NotesLens", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.indigo)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeHeader(),
            const SizedBox(height: 25),
            
            if (_selectedImage == null) _buildUploadBox(),
            if (_selectedImage != null) _buildImagePreview(),
            if (_isProcessing) _buildLoadingState(),

            if (_aiResponse.isNotEmpty && !_isProcessing) ...[
              _buildStatsRow(),
              const SizedBox(height: 20),
              _buildMainContentCard(),
              const SizedBox(height: 20),
              _buildActionButtons(),
            ],
            
            const SizedBox(height: 100),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickImage,
        label: const Text("SCAN NOTES", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        icon: const Icon(Icons.document_scanner_rounded),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildWelcomeHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Hello, Vitians!", style: TextStyle(fontSize: 16, color: Colors.indigo, fontWeight: FontWeight.w500)),
        Text("Transform your scribbles.", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
      ],
    );
  }

  Widget _buildUploadBox() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.indigo.withOpacity(0.1), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo_rounded, size: 40, color: Colors.indigo),
            const SizedBox(height: 15),
            const Text("Upload Study Material", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.indigo)),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        image: DecorationImage(image: MemoryImage(_selectedImage!), fit: BoxFit.cover),
      ),
      alignment: Alignment.bottomRight,
      padding: const EdgeInsets.all(16),
      child: IconButton.filled(onPressed: _pickImage, icon: const Icon(Icons.edit, size: 20)),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40.0),
        child: Column(
          children: [
            CircularProgressIndicator(strokeWidth: 6),
            SizedBox(height: 20),
            Text("AI is reading your handwriting...", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard("Accuracy", "98%", Icons.auto_awesome, Colors.indigo),
        const SizedBox(width: 12),
        _buildStatCard("Complexity", "High", Icons.psychology, Colors.deepPurple),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMainContentCard() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
            child: const TabBar(
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(color: Colors.indigo, borderRadius: BorderRadius.all(Radius.circular(18))),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.indigo,
              tabs: [
                Tab(child: Text("Explanation", style: TextStyle(fontWeight: FontWeight.bold))),
                Tab(child: Text("Flashcards", style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 420,
            child: TabBarView(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
                  child: SingleChildScrollView(child: MarkdownBody(data: _aiResponse)),
                ),
                _flashcardsList.isEmpty 
                  ? const Center(child: Text("No flashcards found."))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      itemCount: _flashcardsList.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _buildInteractiveFlashcard(_flashcardsList[index]),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveFlashcard(String rawContent) {
    List<String> qa = rawContent.split("|");
    String question = qa[0].replaceAll("Q:", "").trim();
    String answer = qa.length > 1 ? qa[1].replaceAll("A:", "").trim() : "See answer below";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.indigo.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("QUESTION", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.indigo, fontSize: 10)),
          const SizedBox(height: 8),
          Text(question, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const Divider(height: 30),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text("REVEAL ANSWER", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.teal, fontSize: 10)),
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(answer, style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return ElevatedButton.icon(
      onPressed: _launchYouTube,
      icon: const Icon(Icons.play_circle_fill_rounded, size: 28),
      label: const Text("Watch Video Tutorials", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFF0000),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 64),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.indigo),
            child: Text("Anish Ranjan", style: TextStyle(color: Colors.white, fontSize: 24)),
          ),
          ListTile(leading: const Icon(Icons.history), title: const Text("Recent Scans"), onTap: () {}),
          ListTile(leading: const Icon(Icons.settings), title: const Text("Settings"), onTap: () {}),
        ],
      ),
    );
  }
}