import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth/login_screen.dart';
import 'home_screen.dart';
import 'interest_chat_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool forceComplete;

  /// Called when the user saves new interests, so HomeScreen can refresh For You.
  final void Function(List<String> interests)? onInterestsUpdated;

  const ProfileScreen({
    super.key,
    this.forceComplete = false,
    this.onInterestsUpdated,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _educationController = TextEditingController();
  final List<TextEditingController> _favoriteControllers =
  List.generate(5, (_) => TextEditingController());
  String? _profilePicUrl;
  File? _imageFile;
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final ref = FirebaseDatabase.instance.ref('users/$uid');
      try {
        final event = await ref.once();
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          _userData = Map<String, dynamic>.from(data);
          _nameController.text = _userData!['name'] ?? '';
          _ageController.text = _userData!['age']?.toString() ?? '';
          _educationController.text = _userData!['education'] ?? '';
          _profilePicUrl = _userData!['profilePic'];
          final favorites = _userData!['favorites'] as List? ?? [];
          for (int i = 0; i < 5; i++) {
            _favoriteControllers[i].text = i < favorites.length ? favorites[i] : '';
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile: $e. Retrying...'),
            backgroundColor: Colors.orange,
          ),
        );
        await Future.delayed(const Duration(seconds: 5));
        return _loadProfile();
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return null;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      final supabase = Supabase.instance.client;
      final bytes = await _imageFile!.readAsBytes();
      final filePath = 'profiles/$uid.jpg';
      await supabase.storage.from('profile-pics').uploadBinary(
        filePath,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );
      return supabase.storage.from('profile-pics').getPublicUrl(filePath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload failed: $e'), backgroundColor: Colors.red),
        );
      }
      return null;
    }
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final ref = FirebaseDatabase.instance.ref('users/$uid');
      try {
        final picUrl = await _uploadImage() ?? _profilePicUrl;

        // Build the new interests list
        final newInterests = _favoriteControllers
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList();

        await ref.update({
          'name': _nameController.text,
          'age': int.tryParse(_ageController.text) ?? 0,
          'education': _educationController.text,
          'favorites': newInterests,
          'profilePic': picUrl ?? '',
        });

        // Notify HomeScreen about updated interests
        widget.onInterestsUpdated?.call(newInterests);

        if (widget.forceComplete) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _loadProfile();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
        );
      }
    }

    setState(() => _isSaving = false);
  }

  void _openAiChat() {
    final currentInterests = _favoriteControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InterestChatScreen(
          currentInterests: currentInterests,
          onInterestsSelected: (suggested) {
            // Fill empty slots with suggested interests
            int slotIndex = 0;
            List<String> addedInterests = [];
            for (final interest in suggested) {
              // Find next empty slot
              while (slotIndex < 5 && _favoriteControllers[slotIndex].text.trim().isNotEmpty) {
                slotIndex++;
              }
              if (slotIndex >= 5) break;
              _favoriteControllers[slotIndex].text = interest;
              addedInterests.add(interest);
              slotIndex++;
            }

            if (addedInterests.isNotEmpty) {
              setState(() {});
              _updateProfile();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Added ${addedInterests.length} interest(s) from AI 🎉'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.blue[700],
            title: const Text(
              'My Profile',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.forceComplete) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange[700]),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Complete your profile to continue',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Profile Picture
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              )
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 55,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: _imageFile != null
                                ? FileImage(_imageFile!)
                                : (_profilePicUrl != null && _profilePicUrl!.isNotEmpty
                                ? NetworkImage(_profilePicUrl!)
                                : null) as ImageProvider?,
                            child: (_imageFile == null &&
                                (_profilePicUrl == null || _profilePicUrl!.isEmpty))
                                ? Icon(Icons.person, size: 40, color: Colors.grey[400])
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue[700],
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  )
                                ],
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  _buildSectionTitle('Personal Information'),
                  const SizedBox(height: 12),
                  _buildTextField(
                      controller: _nameController, label: 'Full Name', icon: Icons.person_outline),
                  const SizedBox(height: 12),
                  _buildTextField(
                      controller: _ageController,
                      label: 'Age',
                      icon: Icons.cake_outlined,
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  _buildTextField(
                      controller: _educationController,
                      label: 'Education',
                      icon: Icons.school_outlined),

                  const SizedBox(height: 20),

                  // Career Interests header row with AI button
                  Row(
                    children: [
                      Expanded(child: _buildSectionTitle('Career Interests')),
                      GestureDetector(
                        onTap: _openAiChat,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue[700]!, Colors.blue[500]!],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                              SizedBox(width: 5),
                              Text(
                                'AI Suggest',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Add up to 5 job titles you\'re interested in',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 12),

                  ...List.generate(
                    5,
                        (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildTextField(
                        controller: _favoriteControllers[i],
                        label: 'Interest #${i + 1}',
                        icon: Icons.work_outline,
                        hint: 'e.g. Software Engineer, Designer',
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _updateProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                          : Text(
                        widget.forceComplete ? 'Save & Continue' : 'Save Changes',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  if (!widget.forceComplete) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout),
                        label: const Text('Logout',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red[300]!),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.blue[700]),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _educationController.dispose();
    for (var c in _favoriteControllers) c.dispose();
    super.dispose();
  }
}