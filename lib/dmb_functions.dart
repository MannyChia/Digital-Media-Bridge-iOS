///
///
/// *************************************************
/// *** FUNCTIONS FOR GETTING FROM & PUBLISHING DATA
/// TO THE DMB SERVER (INCLUDING USER LOGIN)
/// *************************************************
///
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
///
import './main.dart';
import './players_page.dart';
import './screens_page.dart';
import 'package:flutter/material.dart';

import 'package:http_parser/http_parser.dart'; // for MediaType

Future<bool> uploadImage(File imageFile, String username) async {
  var uri = Uri.parse('https://digitalmediabridge.tv/screenbuilderserver-test/api/upload');

  var request = http.MultipartRequest('POST', uri)
    ..fields['filetype'] = 'images'
    ..fields['username'] = username
    ..files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: MediaType('image', 'jpeg'), // or use `image/png` as needed
      ),
    );

  try {
    var response = await request.send();

    if (response.statusCode == 200) {
      print("Upload successful");
      return true;
    } else {
      print("Upload failed with status: ${response.statusCode}");
      return false;
    }
  } catch (e) {
    print("Upload exception: $e");
    return false;
  }
}

/// *************************************************
/// *** AFTER THE USER PROVIDES A DMB USERNAME & PASSWORD ***
/// *************************************************
getUserData(String username, String password, String requestType) async {

  final response = await http.post(
    Uri.parse('https://digitalmediabridge.tv/ScreenBuilder-Server/api/Resource/GetUserResources'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, String>{
      'UserName': username,
      'Password': password
    }),
  );

  //if we're able to get to the URL (not necessarily a successful login)
  if(response.statusCode == 200){

    //JSON decode the response data
    Map<String, dynamic> myData = json.decode(response.body);

    //*** return if invalid login
    if(myData["status"] == "error"){
      return "invalid_login";
    }

    //Login is valid, so get the list of screens ....
    List<dynamic> screenInfo = myData["data"]["screens"];

    //*** return if there are no screens to show
    if(screenInfo.isEmpty){
      return "no_screens";
    }

    //each time we re-load the players or screens page, need to re-set the values
    dmbMediaPlayers = [];
    dmbScreens = [];
    activeDMBPlayers = 0;  //currently we don't show the user the 'active' players count (number)

    //get the list of players ...
    List<dynamic> playerInfo = myData["data"]["players"];

    //*** return if there are no players to show
    if(playerInfo.isEmpty){
      return "no_players";
    }

    //*** populate global <dmbMediaPlayers> with the list of players and needed data about each
    playerInfo.forEach((player) {
      var dPlayerName = player["playerName"];
      var dPlayerStatus = player["status"];
      var dPlayerCurrentScreen = player["currentScreen"];

      if(dPlayerCurrentScreen.length > 13){  //if the name of the screen is too long ...
        dPlayerCurrentScreen = dPlayerCurrentScreen.substring(0, 12)+"...";  //trim it
      }

      //if this player is 'active' add it to the count ...
      if(dPlayerStatus == "Active"){
        activeDMBPlayers++;
      }

      //*** add player to array of account players
      dmbMediaPlayers.add(MediaPlayer(name:"$dPlayerName", status:"$dPlayerStatus", currentScreen:"$dPlayerCurrentScreen"));
    });

    //*** populate global <dmbScreens> with the list of screens
    screenInfo.forEach((screen) {
      var dScreenName = screen["screenName"];

      //*** add screen to array of account screens
      dmbScreens.add(DmbScreen(name:"$dScreenName"));
    });

    if(requestType == "user-login" || requestType == "bypass-login") {
      return true; //*** RETURN SUCCESS!
    }
    else if(requestType == "players-refresh"){
      return dmbMediaPlayers;  //*** RETURN LIST OF DMB MEDIA PLAYERS
    }
  }
  else{
    return false;   //*** COULD NOT REACH THE URL ON THE DMB SERVER
  }
}

/// *************************************************
/// *** AFTER A PLAYER & SCREEN IS SELECTED ***
/// *************************************************
confirmPublish(BuildContext context, String playername, String screenname) {

  // set up the buttons
  Widget cancelButton = OutlinedButton(
    child: const Text(
      "CANCEL",
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
    onPressed:(){
      Navigator.of(context).pop();  //close confirmation pop-up
    },
  );
  Widget continueButton = OutlinedButton(
    child: const Text(
      "PUBLISH",
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
    onPressed:(){

      Navigator.of(context).pop();  //close confirmation pop-up
      publishScreen(loginUsername, playername, screenname).then((result){
        if(result){  ///*** IF SUCCESSFUL PUBLISH!
          publishSuccess(context);
        }
      });
    },
  );
  // set up the AlertDialog
  AlertDialog alert = AlertDialog(
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(0.0)),
        side: BorderSide(
            width: 5,
            color: Colors.white
        )
    ),
    backgroundColor: const Color.fromRGBO(10, 85, 163, 1.0),
    title: const Text(
      "CONFIRM PUBLISH",
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
    content: Text(
      "Do you want to play screen '$screenname' on player $playername?",
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.normal),
    ),
    actions: [
      cancelButton,
      continueButton,
    ],
  );
  // show the dialog
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
  );

}

/// *************************************************
/// *** AFTER THE USER CONFIRMS THAT THEY WANT TO PUBLISH
/// SELECTED SCREEN TO SELECTED PLAYER ***
/// *************************************************
publishScreen(String userName, String playerName, String screenName) async {

  var publishData = {
    "UserName": userName,
    "screenName": screenName,
    "players": [
      playerName
    ]
  };

  final response = await http.post(
    Uri.parse('https://digitalmediabridge.tv/ScreenBuilder-Server/api/screen/publishToPlayers'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(publishData),
  );

  //if we're able to get to the URL (not necessarily a successful login)
  if(response.statusCode == 200){
    return true;  //*** RETURN SUCCESS!
  }
  else{
    return false;   //*** COULD NOT REACH THE URL ON THE DMB SERVER
  }
}

/// *************************************************
/// *** AFTER A SCREEN HAS BEEN SUCCESSFULLY PUBLISHED
/// TO A PLAYER, TELL THE USER ***
/// *************************************************
publishSuccess(BuildContext context) {

  // set up the buttons
  Widget okButton = OutlinedButton(
    child: const Text(
      "OK",
      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
    ),
    onPressed:(){
      Navigator.of(context).pop();
    },
  );

  // set up the AlertDialog
  AlertDialog alert = AlertDialog(
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(0.0)),
    ),
    backgroundColor: Colors.lightGreen,
    title: const Text(
      "PUBLISH SUCCESS",
      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
    ),
    content: const Text(
      "Note: It may take up to 30 seconds for the screen change to take effect",
      style: TextStyle(color: Colors.black, fontWeight: FontWeight.normal),
    ),
    actions: [
      okButton
    ],
  );
  // show the dialog
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
  );

}

//On user logout, remove all of the system storage
//values (username & password)
void _deleteStorage() async {

  await systemStorage.deleteAll();
}

/// *************************************************
/// *** WHEN A USER SELECTS THE 'LOGOUT' ICON ***
/// *************************************************
confirmLogout(BuildContext context) {

  // set up the buttons
  Widget cancelButton = OutlinedButton(
    child: const Text(
      "CANCEL",
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
    onPressed:(){  //NO, DON"T LOGOUT

      Navigator.of(context).pop();  //close confirmation pop-up
    },
  );
  Widget continueButton = OutlinedButton(
    child: const Text(
      "LOGOUT",
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
    onPressed:(){  //YES, LOGOUT

      Navigator.of(context).pop();  //close confirmation pop-up
      _deleteStorage();
      loginUsername = "none";
      loginPassword = "none";
      selectedIndex = 0;
      dmbMediaPlayers = [];
      dmbScreens = [];
      Navigator.of(context).pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
    },
  );
  // set up the AlertDialog
  AlertDialog alert = AlertDialog(
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(0.0)),
        side: BorderSide(
            width: 5,
            color: Colors.white
        )
    ),
    backgroundColor: const Color.fromRGBO(10, 85, 163, 1.0),
    title: const Text(
      "CONFIRM LOGOUT",
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
    content: const Text(
      "Do you want to log out of the DMB App?",
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.normal),
    ),
    actions: [
      cancelButton,
      continueButton,
    ],
  );
  // show the dialog
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
  );
}
