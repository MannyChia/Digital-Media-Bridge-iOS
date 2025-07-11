import './players_page.dart';
import './dmb_functions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:marquee/marquee.dart'; // for marquee ef


class DmbScreen {
  String name;
  DmbScreen({required this.name});
}

List<DmbScreen> dmbScreens = [];
final List<int> colorCodesScreens = <int>[400, 200, 900];

class ScreensPage extends StatefulWidget {
  const ScreensPage({
    super.key,
    required this.screensPageTitle,
    required this.screensPageSubTitle,
  });

  final String screensPageTitle;
  final String screensPageSubTitle;

  @override
  State<ScreensPage> createState() => _ScreensPageState();
}

class _ScreensPageState extends State<ScreensPage> {
  late String screensPageTitle;
  late String screensPageSubTitle;
  late String backgroundURL;

  @override
  void initState() {
    super.initState();
    screensPageTitle = widget.screensPageTitle;
    screensPageSubTitle = widget.screensPageSubTitle;
    backgroundURL = dotenv.env['BACKGROUND_IMAGE_URL']!;
  }

  @override
  Widget build(BuildContext context) {
    final double vw = MediaQuery.of(context).size.width / 100;
    final double vh = MediaQuery.of(context).size.height / 100;
    final lightGreyTheme = dotenv.env['LIGHT_GREY_THEME'];
    final int colorNum = int.parse(lightGreyTheme!, radix: 16);

    return CupertinoPageScaffold(
      navigationBar: _appBarBackBtn(context, screensPageTitle),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(backgroundURL),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: vh * 10),
            child: ListView.separated(
              padding: EdgeInsets.symmetric(
                  vertical: vh * 2, horizontal: vw * 3),
              itemCount: dmbScreens.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    if (screensPageTitle != "Available Screens") {
                      if (selectedPlayerName != null) {
                        confirmPublish(
                          context,
                          selectedPlayerName,
                          dmbScreens[index].name,
                        );
                      } 
                      else {
                        _showCupertinoAlert(context, "Select a Player First");
                      }
                    } else {
                      _showCupertinoAlert(context, "Select a Player First");
                    }
                  },
                  child: Container(
                    height: 75,
                    decoration: BoxDecoration(
                      color: Color(colorNum).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        dmbScreens[index].name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.white,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 12),
            ),
          ),
        ],
      ),
    );xs
  }
}


CupertinoNavigationBar _appBarBackBtn(BuildContext context, String title) {
  final double vw = MediaQuery.of(context).size.width / 100;

  return CupertinoNavigationBar(
    backgroundColor: CupertinoColors.black.withOpacity(0.8),
   automaticallyImplyLeading: false,
    leading: CupertinoNavigationBarBackButton(
      color: CupertinoColors.white,
      onPressed: () {
        Navigator.of(context).pop();
      },
    ),
    middle: StatefulBuilder(
      builder: (context, setState) {
        final ScrollController scrollController = ScrollController();
        bool scrollingForward = true;

        // Start the scrolling animation after first frame
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final maxScroll = scrollController.position.maxScrollExtent;
          final minScroll = scrollController.position.minScrollExtent;

          // Initial pause before any scrolling happens
          await Future.delayed(const Duration(seconds: 2));

          while (scrollController.hasClients) {
            if (scrollingForward) {
              await scrollController.animateTo(
                maxScroll,
                duration: const Duration(seconds: 3),
                curve: Curves.linear,
              );
              await Future.delayed(const Duration(seconds: 1));
              scrollingForward = false;
            } else {
              await scrollController.animateTo(
                minScroll,
                duration: const Duration(seconds: 3),
                curve: Curves.linear,
              );
              await Future.delayed(const Duration(seconds: 1));
              scrollingForward = true;
            }
          }
        });


        return SizedBox(
          width: MediaQuery.of(context).size.width * 0.95,
          height: vw * 7,
          child: SingleChildScrollView(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Text(
              title,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: CupertinoColors.white,
                fontSize: vw * 6,
              ),
            ),
          ),
        );
      },
    ),
    trailing: const SizedBox(width: 2),
  );
}


void _showCupertinoAlert(BuildContext context, String message) {
  showCupertinoDialog(
    context: context,
    builder: (BuildContext context) => CupertinoAlertDialog(
      title: Text(message),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          child: const Text("OK"),
          onPressed: () => Navigator.of(context).pop(),
        )
      ],
    ),
  );
}
