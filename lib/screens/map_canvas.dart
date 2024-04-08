import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:xplore/core/navbar.dart';
import 'package:xplore/features/location/bloc/location_cubit.dart';
import 'package:xplore/features/map/bloc/map_cubit.dart';

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
    initMap();
  }

  Future<void> initMap() async {
    final currentPosition = await context.read<LocationCubit>().getCurrentLocation();
    if (debounce?.isActive == true) debounce!.cancel();

    debounce = Timer(const Duration(milliseconds: 1000), () {
      final update = CameraUpdate.newCameraPosition(CameraPosition(target: currentPosition, zoom: 16));
      mapController.animateCamera(update);
    });

    setState(() => redrawKey = Object());
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
          BlocBuilder<MapCubit, MapStates>(
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
                myLocationButtonEnabled: true, // TODO: false
                onTap: (_) {},
                style: context.read<MapCubit>().mapStyle,
              );
            },
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
  }

  void onCameraMove(CameraPosition position) {
    final newCenter = LatLng(position.target.latitude, position.target.longitude);
    context.read<MapCubit>().updateCenter(newCenter);
  }
}
