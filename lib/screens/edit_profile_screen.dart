import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:visitar_teste/l10n/app_localizations.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final Color kPrimaryGreen = const Color(0xFF0F9D58);
  bool isLoading = false;
  File? _selectedImage; 

  late TextEditingController _nameController;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _newPassController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();
  
  late String _selectedGender;
  late String _selectedLanguage;

  final List<String> _genders = ['Masculino', 'Feminino', 'Outro', 'Prefiro não dizer'];
  final Map<String, String> _languageMap = {
    'Portuguesa': 'pt',
    'Inglesa': 'en',
    'Espanhola': 'es',
    'Francesa': 'fr',
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userData['nome'] ?? '');
    _emailController.text = widget.userData['email'] ?? '';
    
    String dbGender = widget.userData['genero'] ?? _genders.first;
    _selectedGender = _genders.contains(dbGender) ? dbGender : _genders.first;
        
    String dbLangCode = widget.userData['linguagem'] ?? 'pt';
    _selectedLanguage = _languageMap.keys.firstWhere(
      (k) => _languageMap[k] == dbLangCode, 
      orElse: () => 'Portuguesa'
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      String langCode = _languageMap[_selectedLanguage] ?? 'pt';
      String? photoUrl = widget.userData['urlFoto'];

      if (_selectedImage != null) {
        final storageRef = FirebaseStorage.instance.ref().child('user_images').child('$uid.jpg');
        await storageRef.putFile(_selectedImage!);
        photoUrl = await storageRef.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'nome': _nameController.text.trim(),
        'genero': _selectedGender,
        'linguagem': langCode,
        'urlFoto': photoUrl,
      });

      if (_newPassController.text.isNotEmpty) {
         if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.reauthRequired)));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: kPrimaryGreen, content: Text(AppLocalizations.of(context)!.profileUpdated)));
        Navigator.pop(context);
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text("Erro: $e")));
    } finally {
       if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Estilo partilhado para os campos de texto
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.grey[100], 
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: kPrimaryGreen, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
      hintStyle: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500, fontSize: 14),
    );

    ImageProvider? backgroundImage;
    if (_selectedImage != null) {
      backgroundImage = FileImage(_selectedImage!);
    } else if (widget.userData['urlFoto'] != null && widget.userData['urlFoto'].isNotEmpty) {
      backgroundImage = CachedNetworkImageProvider(widget.userData['urlFoto']);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.editProfile, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 10),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kPrimaryGreen, width: 2)),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: backgroundImage,
                          child: backgroundImage == null
                              ? Icon(Icons.camera_alt, size: 35, color: Colors.grey)
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 25),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 15, bottom: 5),
                      child: Text(AppLocalizations.of(context)!.name, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(fontSize: 15),
                      decoration: inputDecoration.copyWith(
                        hintText: AppLocalizations.of(context)!.name, 
                        prefixIcon: Icon(Icons.person_outline, color: kPrimaryGreen)
                      ),
                      validator: (val) => val!.isEmpty ? AppLocalizations.of(context)!.nameCannotBeEmpty : null,
                    ),
                  ],
                ),
                SizedBox(height: 15),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 15, bottom: 5),
                      child: Text(AppLocalizations.of(context)!.email, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    TextFormField(
                      controller: _emailController,
                      readOnly: true,
                      style: const TextStyle(fontSize: 15),
                      decoration: inputDecoration.copyWith(
                        hintText: AppLocalizations.of(context)!.email, 
                        prefixIcon: Icon(Icons.email_outlined, color: Colors.grey), 
                        fillColor: Colors.grey[200]
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 15, bottom: 5),
                      child: Text(AppLocalizations.of(context)!.gender, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    ButtonTheme(
                      alignedDropdown: true,
                      child: DropdownButtonFormField<String>(
                        value: _selectedGender,
                        borderRadius: BorderRadius.circular(20),
                        isExpanded: true,
                        decoration: inputDecoration.copyWith(
                          hintText: AppLocalizations.of(context)!.gender,
                          prefixIcon: Icon(Icons.people_outline, color: kPrimaryGreen),
                        ),
                        icon: Icon(Icons.arrow_drop_down, color: Colors.grey),
                        dropdownColor: Colors.white,
                        items: _genders.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value, style: const TextStyle(fontSize: 15))
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedGender = val!),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 15),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 15, bottom: 5),
                      child: Text(AppLocalizations.of(context)!.nationality, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    ButtonTheme(
                      alignedDropdown: true,
                      child: DropdownButtonFormField<String>(
                        value: _selectedLanguage,
                        borderRadius: BorderRadius.circular(20),
                        isExpanded: true,
                        decoration: inputDecoration.copyWith(
                          hintText: AppLocalizations.of(context)!.nationality,
                          prefixIcon: Icon(Icons.flag_outlined, color: kPrimaryGreen),
                        ),
                        icon: Icon(Icons.arrow_drop_down, color: Colors.grey),
                        dropdownColor: Colors.white,
                        items: _languageMap.keys.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value, style: const TextStyle(fontSize: 15))
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedLanguage = val!),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 25),
                const Divider(height: 20, thickness: 1),
                SizedBox(height: 10),
                
                Text(AppLocalizations.of(context)!.changePassword, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 15),

                TextFormField(
                  controller: _newPassController,
                  obscureText: true,
                  style: const TextStyle(fontSize: 15),
                  decoration: inputDecoration.copyWith(
                    hintText: AppLocalizations.of(context)!.newPassword, 
                    prefixIcon: Icon(Icons.lock_outline, color: kPrimaryGreen)
                  ),
                ),
                SizedBox(height: 15),
                
                TextFormField(
                  controller: _confirmPassController,
                  obscureText: true,
                  style: const TextStyle(fontSize: 15),
                  decoration: inputDecoration.copyWith(
                    hintText: AppLocalizations.of(context)!.confirmNewPassword, 
                    prefixIcon: Icon(Icons.lock_outline, color: kPrimaryGreen)
                  ),
                  validator: (val) {
                    if (_newPassController.text.isNotEmpty && val != _newPassController.text) return AppLocalizations.of(context)!.passwordsDoNotMatch;
                    return null;
                  },
                ),
                SizedBox(height: 30),

                isLoading 
                ? CircularProgressIndicator(color: kPrimaryGreen)
                : SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 5,
                      shadowColor: Colors.green.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: Text(AppLocalizations.of(context)!.saveChanges, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}