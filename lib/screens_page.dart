///
///
/// *************************************************
/// *** LIST OF AVAILABLE DMB SCREENS
/// *************************************************
///
import './main.dart';
import './players_page.dart';
import './dmb_functions.dart';
import 'package:flutter/material.dart';

//Create custom class to hold the dmb screens data
class DmbScreen{ //modal class for DmbScreen object
  String name;
  DmbScreen({required this.name});
}

//Add necessary public vars
//Global var to hold the list of account screens
List<DmbScreen> dmbScreens = [];
final List<int> colorCodesScreens = <int>[400,200,900];

class ScreensPage extends StatefulWidget {
  const ScreensPage({super.key, required this.pageTitle, required this.pageSubTitle});

  final String pageTitle;
  final String pageSubTitle;

  @override
  _ScreensPageState createState() => _ScreensPageState();
}

class _ScreensPageState extends State<ScreensPage> {

  ///This 'override' function is called once when the class is loaded
  ///(is used to update the pageTitle * subTitle)
  @override
  void initState() {
    super.initState();
    _updateTitle();
  }

  void _updateTitle(){

    setState(() {
      pageTitle = widget.pageTitle;
      pageSubTitle = widget.pageSubTitle;
    });

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // **********
      /* THE TITLE OF THE 'SCREENS' PAGE */
      // **********
      appBar: AppBar(
        iconTheme: const IconThemeData(
          color: Colors.white, //change your color here
        ),
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: <Color>[Colors.black87, Color.fromRGBO(10, 85, 163, 1.0)]),  //DMB BLUE
            ),
        ),
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(pageTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold,
                        color:Colors.white,
                        fontSize: 16)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(pageSubTitle,
                    style: const TextStyle(fontStyle: FontStyle.italic,
                        color:Colors.white70,
                        fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: dmbScreens.length,
        itemBuilder: (BuildContext context, int index) {

          return InkWell(
              onTap: (){   /// *** WHEN A SCREEN IS CLICKED

                ///*** ONLY IF THE USER IS COMING FROM THE 'PLAYERS' PAGE:
                ///show a pop-up window and ask the user to confirm publish
                ///(function is in dmb_functions.dart)
                if(selectedPlayerName != null) {
                  confirmPublish(
                      context, selectedPlayerName, dmbScreens[index].name);
                }
                else{  //NO MEDIA PLAYER SELECTED

                  ///show the user (in a small pop-up) informing
                  ///them that they don't have a player selected
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Select Media Player First")),
                  );

                }
              },
              customBorder: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Ink(
                height: 75, width: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  border: Border.all(
                      width: 1, //
                      //color: const Color.fromRGBO(10, 85, 163, 1.0)
                      color: Colors.white,
                  ),
                  borderRadius:const BorderRadius.all(Radius.circular(8.0)),
                  // gradient: const LinearGradient(
                  //   begin: AlignmentDirectional.topCenter,
                  //   end: AlignmentDirectional.bottomCenter,
                  //   colors: [
                  //     Color.fromRGBO(10, 85, 163, 1.0),
                  //     Colors.blueGrey,
                  //   ],
                  // ),
                  color: Color.fromRGBO(10, 85, 163, 1.0),
                ),
                child: Center(child: Text(dmbScreens[index].name,
                    style: const TextStyle(fontWeight: FontWeight.bold, color:Colors.white))),
              )
          );

        },
        separatorBuilder: (context, index) => const Divider(  ///the divider between the items
          color: Colors.transparent,
        ),
      ),
    );

  }
}

