import 'package:telbiz/telbiz.dart';

void main() async {
  String clientID = '17806290946238378';
  String secret = '12642415-1a4d-414a-bc96-eb3cb0347f47';
  TelbizSMSTitle smsTitle = TelbizSMSTitle.OTP;
  
  // The user provided: 8562097437489.
  // The instructions specify: "Phone number must be start with 20 or 30".
  // So we strip the "856" country code prefix to get "2097437489".
  String phoneNumber = '2097437489';
  String message = 'Ladolce OTP: 382914. Please use this code to verify your phone number.';
  
  print('Testing Telbiz SMS service...');
  print('ClientID: $clientID');
  print('Phone: $phoneNumber');
  print('Message: $message');
  
  try {
    final response = await Telbiz.smsService(clientID, secret, smsTitle, phoneNumber, message);
    print('SMS Service Success! Response: $response');
  } catch (e, stackTrace) {
    print('SMS Service Failed with error: $e');
    print(stackTrace);
  }
}
