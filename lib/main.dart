import 'dart:typed_data'; 
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart'; 
import 'package:image_picker/image_picker.dart';           
import 'package:flutter_markdown_selectionarea/flutter_markdown_selectionarea.dart';
import 'package:url_launcher/url_launcher.dart'; 

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NotesLens AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const NotesLens(),
    );
  }
}

class NotesLens extends StatefulWidget {
  const NotesLens({super.key});

  @override
  State<NotesLens> createState() => _NotesLensState();
}

class _NotesLensState extends State<NotesLens> {
  Uint8List? _webImage; 
  String _aiResponse = "";
  bool _isProcessing = false;

  // 1. YouTube Launcher Logic
  Future<void> _launchYouTube() async {
    String topic = "Study Topic";
    if (_aiResponse.contains("TOPIC_FOR_SEARCH:")) {
      topic = _aiResponse.split("TOPIC_FOR_SEARCH:").last.trim();
    }

    final String searchUrl = "https://www.youtube.com/results?search_query=${Uri.encodeComponent(topic)}";
    final Uri uri = Uri.parse(searchUrl);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not launch YouTube")),
      );
    }
  }

  // 2. Photo Picker Logic
  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 70,
    );
    
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _webImage = bytes;
        _isProcessing = true;
        _aiResponse = ""; 
      });
      _askGemini(bytes);
    }
  }

  // 3. Gemini AI Logic
  Future<void> _askGemini(Uint8List bytes) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-3-flash-preview', // Updated to the most stable model name
        apiKey: 'AIzaSyDYE_jspWEmEyRuj-iupq9afcDbhqEjj20', 
      );

      final prompt = TextPart("You are a student tutor. Explain these notes in plain text. "
          "At the very end of your response, add a section called 'TOPIC_FOR_SEARCH:' followed by "
          "the 3-4 word name of the main subject in the image.");
      
      final content = [
        Content.multi([prompt, DataPart('image/jpeg', bytes)])
      ];

      final response = await model.generateContent(content);
      
      setState(() {
        _aiResponse = response.text ?? "AI couldn't read this image clearly.";
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _aiResponse = "Error: $e. Please check your internet connection.";
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("📝 NotesLens AI", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.blue.shade100,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (_webImage != null) 
              Container(
                margin: const EdgeInsets.all(15),
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.blue, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Image.memory(_webImage!, fit: BoxFit.contain),
                ),
              )
            else
              const SizedBox(height: 20),
            
            if (_isProcessing) 
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(child: CircularProgressIndicator()),
              ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _aiResponse.isEmpty && !_isProcessing
                    ? const Text("Upload a study note to begin!")
                    : MarkdownBody(data: _aiResponse, selectable: true),
                  
                  const SizedBox(height: 20),

                  if (_aiResponse.isNotEmpty && !_isProcessing)
                    ElevatedButton.icon(
                      onPressed: _launchYouTube,
                      icon: const Icon(Icons.play_circle_fill, color: Colors.red),
                      label: const Text("Watch Tutorials on YouTube"),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Colors.red.shade50,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 100), 
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _takePhoto,
        label: const Text("Upload Notes"),
        icon: const Icon(Icons.add_a_photo),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}