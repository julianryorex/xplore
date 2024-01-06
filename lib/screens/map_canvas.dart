import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:xplore/core/avatar_map_icon.dart';
import 'package:xplore/core/navbar.dart';
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
    final locations = context.watch<LocationCubit>().state.locations.values.toList();
    context.read<MapCubit>().updateUserMarkers(locations);

    return Scaffold(
      bottomNavigationBar: const Navbar(),
      body: Stack(
        children: [
          BlocListener<MapCubit, MapStates>(
            listener: (context, state) async {
              if (state is InitialMapState) {
                print('initial');
              }

              if (state is LoadProfileOnMapState) {
                await showModalBottomSheet(
                  context: context,
                  isDismissible: false,
                  builder: (context) {
                    return BlocBuilder<ProfileCubit, ProfileState>(
                      builder: (context, state) {
                        return SizedBox(
                          width: getScreenWidth(context: context),
                          height: getScreenHeight(context: context, percent: 0.9),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AvatarMapIcon(
                                size: 100,
                                image: state.profilePicture != null ? Image.memory(state.profilePicture!).image : null,
                              ),
                              const Text('Hello'),
                              OutlinedButton(
                                onPressed: () async {
                                  await context.read<MapCubit>().initialMarkerUpdate().then((value) async {
                                    final locations = context.read<LocationCubit>().state.locations.values.toList();
                                    await context.read<MapCubit>().updateUserMarkers(locations);
                                  }).then((value) => Navigator.pop(context));
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
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                return GoogleMap(
                  key: ValueKey<Object>(redrawKey),
                  onMapCreated: onMapCreated,
                  initialCameraPosition: MapCubit.initialCameraPosition,
                  onCameraMove: onCameraMove,
                  markers: state.markers,
                  myLocationButtonEnabled: true,
                  onTap: (_) {},
                  style: context.read<MapCubit>().mapStyle,
                );
              },
            ),
          ),
        ],
      ),
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
    final currentPosition = await context.read<LocationCubit>().getCurrentLocation();
    if (debounce?.isActive == true) debounce!.cancel();

    debounce = Timer(const Duration(milliseconds: 1000), () {
      final update = CameraUpdate.newCameraPosition(CameraPosition(target: currentPosition, zoom: 16));
      mapController.animateCamera(update);
    });
  }

  void onCameraMove(CameraPosition position) {
    final newCenter = LatLng(position.target.latitude, position.target.longitude);
    context.read<MapCubit>().updateCenter(newCenter);
  }
}
