import 'package:cached_network_image/cached_network_image.dart';
import 'package:rideshare/cloud_functions/firebase_function.dart';
import 'package:rideshare/providers/user_state.dart';
import 'package:rideshare/screens/login/login.dart';
import 'package:rideshare/screens/profile/add_vehicle_screen.dart';
import 'package:rideshare/screens/profile/user_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Color scheme to match HomeScreen
    final Color primaryPurple = const Color(0xFF6200EE);
    final Color secondaryPurple = const Color(0xFF9C27B0);
    final Color lightPurple = const Color(0xFFE1BEE7);
    final Color background = Colors.white;
    final Color textDark = const Color(0xFF212121);
    final Color textLight = const Color(0xFF757575);

    final userState = Provider.of<UserState>(context);
    final currentUser = userState.currentUser;
    ValueNotifier<String?> profileImageNotifier =
        ValueNotifier<String?>(currentUser?.profileImage);
    ValueNotifier<bool> showFullNameNotifier =
        ValueNotifier<bool>(currentUser?.showFullName ?? true);

    void handleUploadPhoto() async {
      final imagePicker = ImagePicker();
      final pickedImage = await imagePicker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedImage != null) {
        final croppedImage = await ImageCropper().cropImage(
          sourcePath: pickedImage.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          compressQuality: 100,
        );
        if (croppedImage != null) {
          try {
            FirebaseFunctions.uploadProfileImageByUser(
              currentUser!,
              File(croppedImage.path),
            ).then((err) => {
                  if (err == null)
                    {
                      FirebaseFunctions.getProfileImageUrlByUser(currentUser)
                          .then((imageUrl) => {
                                if (imageUrl != null)
                                  {
                                    currentUser.saveProfileImage(
                                        userState, imageUrl),
                                    profileImageNotifier.value = imageUrl,
                                  }
                              })
                    }
                  else
                    {
                      debugPrint('Error uploading image: $err'),
                    }
                });
          } catch (e) {
            debugPrint('Error uploading image: $e');
          }
        } else {
          debugPrint('Image cropping was canceled.');
        }
      } else {
        debugPrint('No image was selected.');
      }
    }

    void handleDeleteAccount(BuildContext context) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Confirm Delete'),
              content: const Text(
                  'Are you sure you want to delete your account? This action cannot be undone.'),
              actions: [
                TextButton(
                  onPressed: () async {
                    try {
                      FirebaseFunctions.deleteUserAccount(currentUser!);
                      debugPrint('Account deleted successfully!');
                      userState.signOff();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Account deleted successfully!'),
                        ),
                      );
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => LoginScreen(
                                  userState: userState,
                                )),
                      );
                    } catch (e) {
                      debugPrint('Error deleting account: $e');
                    }
                  },
                  child:
                      const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      }
    }

    void callEmergencyNumber(String number) async {
      final Uri phoneUri = Uri(scheme: 'tel', path: number);
      try {
        if (await canLaunchUrl(phoneUri)) {
          await launchUrl(phoneUri);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to call $number'),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error calling emergency number: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error calling $number'),
          ),
        );
      }
    }

    void showEmergencyContacts() {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Emergency Contacts',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Call for immediate assistance',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 20),
              _buildEmergencyContactButton(
                icon: Icons.local_police,
                number: '100',
                label: 'Police',
                description: 'For crime, violence or emergency situations',
                onPressed: () => callEmergencyNumber('100'),
              ),
              const SizedBox(height: 12),
              _buildEmergencyContactButton(
                icon: Icons.fire_truck,
                number: '101',
                label: 'Fire Department',
                description: 'For fire emergencies and rescue operations',
                onPressed: () => callEmergencyNumber('101'),
              ),
              const SizedBox(height: 12),
              _buildEmergencyContactButton(
                icon: Icons.medical_services,
                number: '108',
                label: 'Ambulance',
                description: 'For medical emergencies',
                onPressed: () => callEmergencyNumber('108'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    }

    void toggleNameVisibility() {
      showFullNameNotifier.value = !showFullNameNotifier.value;
      FirebaseFunctions.updateNameVisibility(
        currentUser!,
        showFullNameNotifier.value,
      );
      currentUser.saveNameVisibility(userState, showFullNameNotifier.value);
    }

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 160.0,
              floating: true,
              pinned: true,
              elevation: 0,
              backgroundColor: background,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [secondaryPurple, primaryPurple],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'My Profile',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Manage your account settings',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ];
        },
        body: Container(
          color: Colors.grey[50],
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Image and Name Section
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      vertical: 24.0, horizontal: 20.0),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          ValueListenableBuilder<String?>(
                            valueListenable: profileImageNotifier,
                            builder: (context, profileImage, _) {
                              return Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      spreadRadius: 2,
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: lightPurple,
                                  child: profileImage == null
                                      ? Icon(
                                          Icons.person,
                                          size: 50,
                                          color: primaryPurple,
                                        )
                                      : ClipOval(
                                          child: CachedNetworkImage(
                                            imageUrl: profileImage,
                                            width: 100,
                                            height: 100,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    const Icon(Icons.error),
                                          ),
                                        ),
                                ),
                              );
                            },
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: handleUploadPhoto,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: primaryPurple,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                padding: const EdgeInsets.all(8),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // User Information Card
                Container(
                  padding: const EdgeInsets.all(16),
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            color: primaryPurple,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Profile Information',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserProfileScreen(
                                    user: currentUser!,
                                    isCurrentUser: true,
                                  ),
                                ),
                              );
                            },
                            child: Icon(
                              Icons.edit_outlined,
                              color: primaryPurple,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      ValueListenableBuilder<bool>(
                        valueListenable: showFullNameNotifier,
                        builder: (context, showFullName, _) {
                          return Column(
                            children: [
                              _buildInfoRow(
                                'Name',
                                showFullName
                                    ? (currentUser?.fullName ?? 'Unknown Name')
                                    : (currentUser?.fullName
                                            .split(' ')
                                            .map(
                                                (e) => e.isNotEmpty ? e[0] : '')
                                            .join('') ??
                                        'UN'),
                                Icons.person,
                                primaryPurple,
                              ),
                              _buildInfoRow(
                                'Email',
                                currentUser?.email ?? 'Unknown',
                                Icons.email,
                                primaryPurple,
                              ),
                              _buildInfoRow(
                                'Joined',
                                _formatDate(currentUser?.createdAt),
                                Icons.calendar_today,
                                primaryPurple,
                              ),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: toggleNameVisibility,
                                  icon: Icon(
                                    showFullName
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    size: 18,
                                    color: primaryPurple,
                                  ),
                                  label: Text(
                                    showFullName
                                        ? 'Show Initials Only'
                                        : 'Show Full Name',
                                    style: TextStyle(
                                      color: primaryPurple,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Vehicle Information
                Container(
                  padding: const EdgeInsets.all(16),
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.directions_car_outlined,
                            color: primaryPurple,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Vehicle Information',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddVehiclePage(
                                  vehicle: currentUser!.vehicle,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.directions_car),
                          label: const Text('Manage My Vehicle'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Emergency Services
                Container(
                  padding: const EdgeInsets.all(16),
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.emergency,
                            color: Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Emergency Services',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildEmergencyButton(
                              Icons.local_police,
                              'Police',
                              '100',
                              Colors.blue.shade700,
                              () => callEmergencyNumber('100'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildEmergencyButton(
                              Icons.fire_truck,
                              'Fire',
                              '101',
                              Colors.orange,
                              () => callEmergencyNumber('101'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildEmergencyButton(
                              Icons.medical_services,
                              'Ambulance',
                              '108',
                              Colors.red,
                              () => callEmergencyNumber('108'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: showEmergencyContacts,
                          icon: const Icon(Icons.add),
                          label: const Text('View All Emergency Services'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Account Actions
                Container(
                  padding: const EdgeInsets.all(16),
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.settings_outlined,
                            color: primaryPurple,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Account Settings',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            userState.signOff();
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LoginScreen(
                                  userState: userState,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign Out'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade200,
                            foregroundColor: textDark,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Danger Zone',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Deleting your account will remove all your data permanently.',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => handleDeleteAccount(context),
                                icon:
                                    const Icon(Icons.delete_forever, size: 18),
                                label: const Text('Delete Account'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      String label, String value, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: iconColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyButton(IconData icon, String label, String number,
      Color color, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: color,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                number,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyContactButton({
    required IconData icon,
    required String number,
    required String label,
    required String description,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: Colors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';

    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
