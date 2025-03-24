import 'package:rideshare/cloud_functions/firebase_function.dart';
import 'package:rideshare/models/ride_offer_model.dart';
import 'package:rideshare/models/types/requested_offer_status.dart';
import 'package:rideshare/models/vehicle_model.dart';
import 'package:rideshare/providers/user_state.dart';
import 'package:rideshare/utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

class UserModel {
  final String email;
  String firstName;
  String lastName;
  late final String companyName;
  String? profileImage;
  final DateTime? createdAt;
  VehicleModel? vehicle;
  List<String> myOfferIds;
  List<String> requestedOfferIds;
  List<String> chatRoomIds;
  bool? showFullName; // Removed 'final' to allow modification

  UserModel({
    this.createdAt,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.profileImage,
    this.vehicle,
    this.myOfferIds = const [],
    this.requestedOfferIds = const [],
    this.chatRoomIds = const [],
    required this.showFullName,
  }) : companyName = email.split("@")[1];

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      email: json['email'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      profileImage: json['profileImage'],
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      vehicle: json['vehicle'] != null
          ? VehicleModel.fromJson(json['vehicle'])
          : null,
      myOfferIds: json['myOfferIds'] != null
          ? List<String>.from(json['myOfferIds'])
          : [],
      requestedOfferIds: json['requestedOfferIds'] != null
          ? List<String>.from(json['requestedOfferIds'])
          : [],
      chatRoomIds: json['chatRoomIds'] != null
          ? List<String>.from(json['chatRoomIds'])
          : [],
      showFullName: json['showFullName'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        "email": email,
        "firstName": firstName,
        "lastName": lastName,
        "profileImage": profileImage,
        "createdAt": createdAt?.toIso8601String(),
        "vehicle": vehicle?.toJson(),
        "myOfferIds": myOfferIds,
        "requestedOfferIds": requestedOfferIds,
        "chatRoomIds": chatRoomIds,
        "showFullName": showFullName,
      };

  String get fullName => '$firstName $lastName';

  types.User toChatUser() => types.User(
        id: email,
        firstName: firstName,
        lastName: lastName,
        imageUrl: profileImage,
      );

  String messageChannelId() => '$email-channel';

  // New method to save name visibility
  Future<String?> saveNameVisibility(UserState userState, bool newValue) async {
    showFullName = newValue; // Update local instance
    userState.setCurrentUser(this); // Sync with UserState
    return null; // Return null to indicate success (consistent with other methods)
  }

  //#region User Intents
  Future<String?> createRideOffer(
      UserState userState, RideOfferModel offer) async {
    final err = await FirebaseFunctions.saveRideOfferByUser(this, offer);
    if (err == null) {
      myOfferIds.add(offer.id);
      userState.setCurrentUser(this);
      return null;
    } else {
      return err;
    }
  }

  Future<String?> saveProfileImage(UserState userState, String imageUrl) async {
    final err = await FirebaseFunctions.saveProfileImageByUser(this, imageUrl);
    if (err == null) {
      profileImage = imageUrl;
      userState.setCurrentUser(this);
      return null;
    } else {
      return err;
    }
  }

  Future<String?> saveVehicle(UserState userState, VehicleModel vehicle) async {
    final err = await FirebaseFunctions.saveVehicleByUser(this, vehicle);
    if (err == null) {
      this.vehicle = vehicle;
      userState.setCurrentUser(this);
      return null;
    } else {
      return err;
    }
  }

  Future<String?> deleteVehicle(UserState userState) async {
    final err = await FirebaseFunctions.deleteVehicleByUser(this);
    if (err == null) {
      vehicle = null;
      userState.setCurrentUser(this);
      return null;
    } else {
      return err;
    }
  }

  Future<String?> requestRide(
      UserState userState, RideOfferModel rideOffer) async {
    final err = await FirebaseFunctions.requestRideByRideOffer(this, rideOffer);
    if (err == null) {
      requestedOfferIds.add(rideOffer.id);
      userState.setCurrentUser(this);
      return null;
    } else {
      return err;
    }
  }

  Future<String?> withdrawRequestRide(
      UserState userState, String rideOfferId) async {
    final err = await FirebaseFunctions.removeRideRequestByRideOfferId(
        this, rideOfferId);
    if (err == null) {
      requestedOfferIds.remove(rideOfferId);
      userState.setCurrentUser(this);
      return null;
    } else {
      return err;
    }
  }

  Future<types.Room?> requestChatWithUser(
      UserState userState, UserModel otherUser) async {
    try {
      String? roomId = Utils.getRoomIdByTwoUser(email, otherUser.email);
      if (!chatRoomIds.contains(roomId)) {
        roomId = await FirebaseFunctions.requestChatWithUser(
            userState, this, otherUser);
      }
      if (roomId != null) {
        if (!chatRoomIds.contains(roomId)) {
          chatRoomIds.add(roomId);
        }
        return await userState.getStoredChatRoomByRoomId(roomId,
            forceUpdate: true);
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('requestChatWithUser: $e');
      return null;
    }
  }

  Future<String?> acceptRideRequest(String rideOfferId, String userId) async {
    final err = await FirebaseFunctions.changeRideRequestStatusWithUserId(
        this, rideOfferId, userId, RequestedOfferStatus.ACCEPTED);
    if (err == null) {
      return null;
    } else {
      return err;
    }
  }

  Future<String?> rejectRideRequest(String rideOfferId, String userId) async {
    final err = await FirebaseFunctions.changeRideRequestStatusWithUserId(
        this, rideOfferId, userId, RequestedOfferStatus.REJECTED);
    if (err == null) {
      return null;
    } else {
      return err;
    }
  }
  //#endregion
}
