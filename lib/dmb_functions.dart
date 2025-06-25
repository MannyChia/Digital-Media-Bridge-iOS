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
import 'package:flutter_dotenv/flutter_dotenv.dart';
import './players_page.dart';
import './screens_page.dart';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart'; // for MediaType
import '/Models/playlist_preview.dart';


List<PlaylistPreview> cachedPlaylistPreviews = [];
bool hasLoadedPlaylistPreviews = false;

Future<List<PlaylistPreview>> fetchPlaylistPreviews(String userEmail) async {
  // Fetch the JSON of screens -> playlists
  final metaResp = await http.get(
      Uri.parse('https://digitalmediabridge.tv/screenbuilder-server/api/GetPlaylist/$userEmail')
  );
  if (metaResp.statusCode != 200) {
    throw Exception('Failed to load playlist metadata');
  }
  final Map<String, dynamic> meta = jsonDecode(metaResp.body);
  final List<dynamic> screens = meta['data'] as List<dynamic>;

  final List<PlaylistPreview> previews = [];

  for (final screenEntry in screens) {
    final screenName    = screenEntry['screenName'] as String;
    final playlistFiles = screenEntry['playLists']  as List<dynamic>;

    for (final rawName in playlistFiles) {
      final fileName      = rawName as String;
      final encodedScreen = Uri.encodeComponent(screenName);

      final plUrl =
          'https://digitalmediabridge.tv/screen-builder/assets/content/${Uri.encodeComponent(userEmail)}/others/$encodedScreen/$fileName';

      final plResp = await http.get(Uri.parse(plUrl));
      if (plResp.statusCode != 200) continue;

      final lines = LineSplitter()
          .convert(plResp.body)
          .where((l) => l.trim().isNotEmpty)
          .toList();

      final String? previewUrl = lines.isNotEmpty
          ? 'https://digitalmediabridge.tv/screen-builder/assets/content/${Uri.encodeComponent(userEmail)}/images/${Uri.encodeComponent(lines.first.split(",").first)}'
          : null;

      // add screenName into the model for mapping in players_page
      previews.add(PlaylistPreview(
        screenName:      screenName,
        name:            fileName,
        previewImageUrl: previewUrl,
        itemCount:       lines.length,
      ));
    }
  }

  return previews;
}


Future<void> preloadPlaylistPreviews(String userEmail) async {
  if (!hasLoadedPlaylistPreviews) {
    cachedPlaylistPreviews = await fetchPlaylistPreviews(userEmail);
    hasLoadedPlaylistPreviews = true;
  }
}


Future<List<String>> fetchAllUserImages(String userEmail) async {
  final url = 'https://digitalmediabridge.tv/screen-builder/assets/api/get_images.php?email=$userEmail';
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final List<dynamic> data = jsonDecode(response.body);
    return List<String>.from(data);
  } else {
    throw Exception('Failed to fetch user image filenames');
  }
}

Future<Map<String, dynamic>> uploadImage(File imageFile, String username) async {
  var uri = Uri.parse('https://digitalmediabridge.tv/screenbuilder-server/api/upload');

  var request = http.MultipartRequest('POST', uri)
    ..fields['filetype'] = 'images'
    ..fields['username'] = username
    ..files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: MediaType('image', 'jpeg'), // or adjust if needed
      ),
    );

  try {
    var response = await request.send();
    final responseBody = await response.stream.bytesToString();
    final decoded = json.decode(responseBody);

    print("Server Response Body: $decoded");

    if (response.statusCode == 200 && decoded['status'] == 'success') {
      return {'success': true, 'message': 'Image uploaded successfully'};
    } else {
      return {
        'success': false,
        'message': decoded['message'] ?? 'Unknown error occurred'
      };
    }
  } catch (e) {
    print("Upload exception: $e");
    return {'success': false, 'message': 'Upload failed with exception'};
  }
}

Future<bool> updatePlaylist({
  required String userEmail,
  required String playlistFileName,    // now this includes “ScreenName/Playlist.pl”
  required List<String> selectedFilenames,
}) async {
  final url = Uri.parse(
      'https://digitalmediabridge.tv/screenbuilder-server/api/file/updateplaylist'
  );

  final body = jsonEncode({
    "userName": userEmail,
    "fileName": playlistFileName,
    "images": selectedFilenames,
  });

  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    final decoded = json.decode(response.body);
    print("Server status: ${response.statusCode}");
    print("Server response: $decoded");

    // Only succeed if HTTP 200 AND backend says “success”
    // watch for errors
    return response.statusCode == 200 && decoded['status'] == 'success';
  } catch (e) {
    print("Update playlist exception: $e");
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
  final lightGreyTheme = dotenv.env['LIGHT_GREY_THEME'];
  final int colorNum = int.parse(lightGreyTheme!, radix: 16); // parse the number in base 16
  final double vw = MediaQuery.of(context).size.width / 100; // width of screen (by percentage)
  final double vh = MediaQuery.of(context).size.height / 100; // height of screen (by percentage)


  // set up the buttons
  Widget cancelButton = OutlinedButton(
    child:  Text(
      "CANCEL",
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: vw * 4),
    ),
    onPressed:(){
      Navigator.of(context).pop();  //close confirmation pop-up
    },
  );
  Widget continueButton = OutlinedButton(
    child: Text(
      "PUBLISH",
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: vw * 4),
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

  // // Confirm Publish Button
  // AlertDialog alert = AlertDialog(
  //   shape: const RoundedRectangleBorder(
  //       borderRadius: BorderRadius.all(Radius.circular(0.0)),
  //       side: BorderSide(
  //           width: 5,
  //           color: Colors.white
  //       )
  //   ),
  //   backgroundColor: Color(colorNum),
  //   title: const Text(
  //     "CONFIRM PUBLISH",
  //     style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
  //   ),
  //   content: Text(
  //     "Do you want to play screen '$screenname' on player $playername?",
  //     style: TextStyle(color: Colors.white, fontWeight: FontWeight.normal, fontSize: vw * 4),
  //   ),
  //   actions: [
  //     cancelButton,
  //     continueButton,
  //   ],
  // );
  // // show the dialog
  // showDialog(
  //   context: context,
  //   builder: (BuildContext context) {
  //     return alert;
  //   },
  // );

  // Confirm Publish Button
  showDialog(
    context: context,
    barrierDismissible: false, // prevents tapping outside to dismiss
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Center(
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "CONFIRM PUBLISH",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: vw * 7,
                    ),
                  ),
                  SizedBox(height: vh * 2),
                  Text(
                    "Do you want to play screen '$screenname' on player $playername?",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.normal,
                      fontSize: vw * 4,
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end, // left align
                    children: [
                      cancelButton,
                      SizedBox(width: 10),
                      continueButton,
                    ],
                  ),
                ]
              )
            )
          ),
        );
      }
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
  final lightGreyTheme = dotenv.env['LIGHT_GREY_THEME'];
  final int colorNum = int.parse(lightGreyTheme!, radix: 16); // parse the number in base 16
  final double vw = MediaQuery.of(context).size.width / 100; // width of screen (by percentage)
  final double vh = MediaQuery.of(context).size.height / 100; // height of screen (by percentage)

  // set up the buttons
  Widget okButton = OutlinedButton(
    child: const Text(
      "OK",
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
    onPressed:(){
      Navigator.of(context).pop();
    },
  );

  // Publish Success Button
  showDialog(
    context: context,
    barrierDismissible: false, // prevents tapping outside to dismiss
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.green,
                width: 5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "PUBLISH SUCCESS",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: vw * 7,
                  ),
                ),
                SizedBox(height: vh * 2),
                Text(
                  "Note: It may take up to 30 seconds for the screen change to take effect",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.normal,
                    fontSize: vw * 4,
                  ),
                ),
                SizedBox(height: 20),
                okButton,
              ]
            )
          )
        ),

      );
    }
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
  final lightGreyTheme = dotenv.env['LIGHT_GREY_THEME'];
  final int colorNum = int.parse(lightGreyTheme!, radix: 16); // parse the number in base 16

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
    backgroundColor: Color(colorNum),
    title: Text(
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