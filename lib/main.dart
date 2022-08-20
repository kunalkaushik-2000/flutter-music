import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_music/constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late TextEditingController _controller;
  bool uploading = false;

  play(link) async {
    Uri url = Uri.parse(link);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      await showDialog(
        context: context,
        builder: (BuildContext context){
          return const AlertDialog(
            content: Text('Could not play audio'),
          );
        },
      );
    }
  }

  void addMusic(String data) async {
    if(_controller.text.isNotEmpty) {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3'],
      );

      if(result != null) {
        setState(() {
          uploading = true;
        });
        File file = File(result.files.single.path!);
        final storageRef = FirebaseStorage.instance.ref();
        final music_ref = storageRef.child("music/${_controller.text}.mp3");
        music_ref.putFile(file).whenComplete(() async {
          var downloadUrl = await music_ref.getDownloadURL();
          await FirebaseFirestore.instance.collection('Music').add(
              {'title': _controller.text, 'link': downloadUrl});
          FocusManager.instance.primaryFocus?.unfocus();
          _controller.clear();
          setState(() {
            uploading = false;
          });
        });
      } else {
        // User canceled the picker
      }
    } else{
      await showDialog(
        context: context,
        builder: (BuildContext context){
          return const AlertDialog(
            content: Text('Please enter title'),
          );
        },
      );
    }
  }

  @override
  void initState() {
    _controller = TextEditingController();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: secondary,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: secondary,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: uploading ? SizedBox(height: height, width: width, child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20,),
              Text('Uploading...', style: GoogleFonts.ptSans(fontSize: 20, fontWeight: FontWeight.bold, color: accent),)
            ],
          )) : Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: width*0.55,
                    height: height*0.15,
                    child: TextField(
                        textCapitalization: TextCapitalization.sentences,
                        style: GoogleFonts.ptSans(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Music Title',
                          hintStyle: GoogleFonts.ptSans(fontSize: 24, fontWeight: FontWeight.bold, color: accent),
                          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: accent),),
                          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: accent),),
                        ),
                        controller: _controller,
                        onSubmitted: (String value)=> addMusic(_controller.text)
                    ),
                  ),
                  const SizedBox(width: 20,),
                  ElevatedButton(
                    onPressed: ()=> addMusic(_controller.text),
                    child: Text('Upload', style: GoogleFonts.ptSans(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),),
                    style: ButtonStyle(
                      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18.0),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                alignment: Alignment.topCenter,
                height: height,
                child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection("Music").orderBy('title').snapshots(),
                    builder: (context, snapshot){
                      return !snapshot.hasData ? Text('Loading...', style: GoogleFonts.ptSans(fontSize: 20, fontWeight: FontWeight.bold, color: accent),) : ListView.builder(
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (BuildContext context, int index){
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                              decoration: BoxDecoration(
                                  color: primary,
                                  borderRadius: BorderRadius.circular(20)
                              ),
                              child: ListTile(
                                leading: const Icon(Icons.music_note_rounded, color: accent,),
                                trailing: IconButton(
                                  onPressed: ()=> play(snapshot.data!.docs[index]['link']),
                                  icon: const Icon(Icons.play_circle_fill_rounded, color: tertiary, size: 30,),
                                ),
                                title: Text(snapshot.data!.docs[index]['title'], style: GoogleFonts.ptSans(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis,),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
