import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/avatar_map_icon.dart';
import 'package:xplore/core/glass.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/features/location/bloc/location_cubit.dart';
import 'package:xplore/features/map/bloc/map_cubit.dart';
import 'package:xplore/features/profile/bloc/profile_cubit.dart';
import 'package:xplore/utilities/utilities.dart';

class MapCanvas extends StatefulWidget {
  const MapCanvas({super.key});

  @override
  State<MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<MapCanvas> {
  /// Key that checks whether a rerender is necessary
  late Object redrawKey;

  /// Controller for [GoogleMap]
  late GoogleMapController mapController;

  Timer? debounce;

  @override
  void initState() {
    super.initState();
    redrawKey = Object();
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }

  //! -------------------------------------------------------------------------
  //! Widgets Methods
  //! -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final locations = context
        .watch<LocationCubit>()
        .state
        .locations
        .values
        .toList();
    context.read<MapCubit>().updateUserMarkers(locations);

    final viewPadding = MediaQuery.viewPaddingOf(context);
    final topInset = viewPadding.top;
    // Space the map controls need to clear the floating glass nav bar (its
    // height + the device's bottom safe-area inset).
    final bottomClearance = viewPadding.bottom + navBarHeight;
    // Gap between the status bar and the header controls.
    const headerTopGap = paddingUnit * 0.75;
    final headerZone = topInset + headerTopGap + Header.padding;

    // Pure content for the RootShell's IndexedStack: the surrounding Scaffold,
    // background colour and floating glass nav bar live in RootShell. The map
    // runs full-bleed so the glass nav bar has live content to refract.
    return Stack(
      children: [
        // Live map, full-height behind the pinned header and floating chrome.
        Positioned.fill(
          child: BlocListener<MapCubit, MapStates>(
            listener: (context, state) async {
              if (state is LoadProfileOnMapState) {
                await showModalBottomSheet(
                  context: context,
                  isDismissible: false,
                  builder: (context) {
                    return BlocBuilder<ProfileCubit, ProfileState>(
                      builder: (context, state) {
                        return SizedBox(
                          width: getScreenWidth(context: context),
                          height: getScreenHeight(
                            context: context,
                            percent: 0.9,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AvatarMapIcon(
                                size: 100,
                                image: state.profilePicture != null
                                    ? Image.memory(state.profilePicture!).image
                                    : null,
                              ),
                              const Text('Hello'),
                              OutlinedButton(
                                onPressed: () async {
                                  await context
                                      .read<MapCubit>()
                                      .initialMarkerUpdate()
                                      .then((value) async {
                                        final locations = context
                                            .read<LocationCubit>()
                                            .state
                                            .locations
                                            .values
                                            .toList();
                                        await context
                                            .read<MapCubit>()
                                            .updateUserMarkers(locations);
                                      })
                                      .then((value) => Navigator.pop(context));
                                },
                                child: const Text('Sounds good!'),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              }
            },
            child: BlocBuilder<MapCubit, MapStates>(
              builder: (context, state) {
                if (state is! LoadedMapState) {
                  return const Center(child: CircularProgressIndicator());
                }

                return GoogleMap(
                  key: ValueKey<Object>(redrawKey),
                  onMapCreated: onMapCreated,
                  initialCameraPosition: MapCubit.initialCameraPosition,
                  onCameraMove: onCameraMove,
                  markers: state.markers,
                  // Replaced by the glass recenter control below so the map
                  // chrome stays consistent with the rest of the app.
                  myLocationButtonEnabled: false,
                  // Keep the native Google logo / attribution clear of the
                  // pinned header and the floating glass nav bar.
                  padding: EdgeInsets.only(
                    top: headerZone,
                    bottom: bottomClearance,
                  ),
                  onTap: (_) {},
                  style: context.read<MapCubit>().mapStyle,
                );
              },
            ),
          ),
        ),
        // Floating glass recenter control, pinned just above the nav bar.
        Positioned(
          right: paddingUnit * 1.5,
          bottom: bottomClearance + paddingUnit,
          child: GlassIconButton(
            icon: Icons.my_location_rounded,
            tooltip: 'Recenter',
            iconColor: XploreColors.alternate,
            onTap: recenterToCurrentLocation,
          ),
        ),
        // Top scrim: blends the status-bar area into the base colour and keeps
        // the header legible over the bright, busy map underneath.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Container(
              height: headerZone + paddingUnit * 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    XploreColors.primaryBg,
                    XploreColors.primaryBg.withValues(alpha: 0.6),
                    XploreColors.primaryBg.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.6, 1],
                ),
              ),
            ),
          ),
        ),
        // Pinned header, sitting just below the status bar.
        Positioned(
          top: topInset + headerTopGap,
          left: 0,
          right: 0,
          child: Header(titleWidget: const _MapTitle()),
        ),
      ],
    );
  }

  //! -------------------------------------------------------------------------
  //! Callback Methods
  //! -------------------------------------------------------------------------

  /// Sets [GoogleMapController] and map style
  void onMapCreated(GoogleMapController controller) {
    mapController = controller;

    initialZoomAnimation();
  }

  Future<void> initialZoomAnimation() async {
    final currentPosition = await context
        .read<LocationCubit>()
        .getCurrentLocation();
    if (debounce?.isActive == true) debounce!.cancel();

    debounce = Timer(const Duration(milliseconds: 1000), () {
      final update = CameraUpdate.newCameraPosition(
        CameraPosition(target: currentPosition, zoom: 16),
      );
      mapController.animateCamera(update);
    });
  }

  /// Animates the camera back to the user's current location. Backs the glass
  /// recenter control that replaces the native "my location" button.
  Future<void> recenterToCurrentLocation() async {
    final currentPosition = await context
        .read<LocationCubit>()
        .getCurrentLocation();
    final update = CameraUpdate.newCameraPosition(
      CameraPosition(target: currentPosition, zoom: 16),
    );
    await mapController.animateCamera(update);
  }

  void onCameraMove(CameraPosition position) {
    final newCenter = LatLng(
      position.target.latitude,
      position.target.longitude,
    );
    context.read<MapCubit>().updateCenter(newCenter);
  }
}

class _MapTitle extends StatelessWidget {
  const _MapTitle();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Live map',
          style: context.pText.labelSmall?.copyWith(
            color: XploreColors.subtleText,
          ),
        ),
        Text(
          'Your group, right now',
          style: context.pText.labelLarge?.copyWith(letterSpacing: -0.2),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
