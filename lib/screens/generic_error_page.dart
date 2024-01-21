import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/core/icon_button.dart';
import 'package:xplore/utilities/utilities.dart';

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Stack(
            children: [
              Header(
                leadingWidget: XploreIconBtn(
                  bgColor: XploreColors.darkBg,
                  onTapCallback: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 45),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: paddingUnit * 2, vertical: paddingUnit),
                    child: SvgPicture.asset(
                      'assets/illustrations/error.svg',
                      semanticsLabel: 'Error illustration',
                      height: getScreenHeight(context: context, percent: 0.5),
                    ),
                  ),
                  Text(
                    'Oops! Something went wrong.',
                    style: context.pText.bodyMedium,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
